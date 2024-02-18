import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as ml;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class Uploader extends StatefulWidget {
  @override
  _UploaderState createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> {
  PlatformFile? pickedFile;
  String scanned = "";
  List<String> tags = [];
  TextEditingController customTagController = TextEditingController();
  TextEditingController titleController = TextEditingController();
  bool loading = false;
  String _type = "";
  String? selectedOption;
  List<String> documentTypes = [
    'Cheat Sheet',
    'Text Book',
    'Lecture Notes',
    'Diagram',
    'Test Paper',
    'Formula sheet'
    // Add more document types as needed
  ];
  String? selectedDocumentType;

  Future<List<String>> fetchkeys(String text) async {
    List<String> result = [];
    String prompt = "UNDERSTAND the following text "
        "and give me a set of the top 20 most relevant keywords are related to the content"
        "and best describe it ."
        "if required generate more keywords for accuracy but dont go overboard. "
        "the keywords must be unique as they would be used to search up this text. "
        "give me the comma seperated list of the keywords  and say nothing else but "
        "the list.. dont give me any other response. the text is as follows"
        "         \n\n\n" +
        text;
    String requestBody = jsonEncode({'content': prompt});
    try {
      var response = await http.post(
        Uri.parse('http://65.0.32.85:5000/key'),
        body: requestBody,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(const Duration(seconds: 15));
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> keyList = jsonDecode(response.body);
        for (String tag in keyList) {
          List<String> splitTags =
          tag.split(" ").where((t) => t.isNotEmpty).toList();
          result.addAll(splitTags);
        }
      } else {
        print('Failed to fetch keys. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error sending request: $error');
    }
    return result;
  }

  void addCustomTag(String tag) {
    if (tag.isNotEmpty) {
      setState(() {
        tags.addAll(tag.split(" "));
        customTagController.clear();
      });
    }
  }

  void deleteTag(String tag) {
    setState(() {
      tags.remove(tag);
    });
  }

  Future<void> uploadFile() async {
    // Check if required fields are not empty
    if (pickedFile == null || titleController.text.isEmpty || selectedDocumentType == null) {
      // Show error dialog if any required field is empty
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Missing Information"),
            content: Text("Please select a file, enter a title, choose a document type, and select a document category."),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // Sanitize file name and generate ID
      String fileName = sanitizeFileName(pickedFile!.name!);
      String id = generateId();

      // Get current user
      final FirebaseAuth _auth = FirebaseAuth.instance;
      User _user = _auth.currentUser!;
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.email)
          .get();
      if (snapshot.exists) {
        setState(() {
          _type = snapshot['type'];
        });
      }

      // Reference to the file in Firebase Storage
      Reference ref = FirebaseStorage.instance.ref('uploads/$id');


      // Fetch keywords from text
      List<String> keywords = await fetchkeys(scanned);

      // Set metadata for the file
      if(pickedFile!.extension == "pdf"){
        Reference ref = FirebaseStorage.instance.ref('uploads/$id'+".pdf");
        SettableMetadata metadata = SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'uploaded-by': snapshot['username'],
            'file-name': fileName,
            'tags': jsonEncode(tags),
            'title': titleController.text,


          },
        );
        await ref.putFile(File(pickedFile!.path!), metadata);
      }
      else{

        SettableMetadata metadata = SettableMetadata(
          contentType: pickedFile!.extension,
          customMetadata: {
            'uploaded-by': snapshot['username'],
            'file-name': fileName,
            'tags': jsonEncode(tags),
            'title': titleController.text,


          },
        );
        await ref.putFile(File(pickedFile!.path!), metadata);

      }


      // Upload file to Firebase Storage


      // Add document data to Firestore
      final doc = FirebaseFirestore.instance.collection('docs').doc(id);
      if(pickedFile!.extension == "pdf"){
        final json = {
          "tags": tags,
          "title": titleController.text,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'userpfp': snapshot['profilepic'],
          'category': selectedDocumentType!,
          'contributor': snapshot['username'],
          'id': id+".pdf"
        };
        await doc.set(json);


      }
      else{
        final json = {
          "tags": tags,
          "title": titleController.text,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'userpfp': snapshot['profilepic'],
          'category': selectedDocumentType!,
          'contributor': snapshot['username'],
          'id': id
        };
        await doc.set(json);

      }




      //debugPrint('File uploaded successfully to: $ref.fullPath');
    } catch (error) {
      debugPrint('Error uploading file: $error');
    } finally {
      setState(() {
        loading = false;
        Navigator.pop(context);
      });
    }
  }

  String sanitizeFileName(String fileName) {
    // Replace spaces and special characters with underscores
    return fileName.replaceAll(RegExp(r'[^\w\s]+'), '_');
  }

  String generateId() {
    // Generate a unique ID with letters and numbers only
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> selectFile() async {
    final status = await Permission.storage.request();

    if (status.isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          setState(() {
            pickedFile = result.files.first;
            scanned = "";
          });

          if (pickedFile!.extension == 'png' ||
              pickedFile!.extension == 'jpg' ||
              pickedFile!.extension == 'jepg'){
            final file = File(pickedFile!.path!);
            final inputimage =
            ml.InputImage.fromFilePath(pickedFile!.path!);
            final textDetector = ml.GoogleMlKit.vision.textRecognizer();
            ml.RecognizedText recognizedText =
            await textDetector.processImage(inputimage);
            await textDetector.close();
            for (ml.TextBlock block in recognizedText.blocks) {
              for (ml.TextLine lines in block.lines) {
                setState(() {
                  scanned += lines.text;
                });
              }
            }
          } else {
            final PdfDocument document = PdfDocument(
                inputBytes: File(pickedFile!.path!).readAsBytesSync());
            for (int i = 0; i < document.pages.count; i++) {
              scanned +=
                  PdfTextExtractor(document).extractText(startPageIndex: i);
            }
            document.dispose();
          }

          List<String> fetchedTags = await fetchkeys(scanned);
          setState(() {
            tags = fetchedTags;
          });
        }
      } catch (error) {
        debugPrint('Error selecting file: $error');
      }
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Storage Permission Required"),
            content: Text(
              'This app needs access to your storage to upload files. '
                  'Please grant permission in the app settings.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => openAppSettings(),
                child: Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ],
          );
        },
      );
    }
  }

  Widget buildOptionTile(String option) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(option),
        selected: true,
        onSelected: (selected) => handleChipSelection(selected, option),
      ),
    );
  }

  void handleChipSelection(bool selected, String option) {
    setState(() {
      selectedOption = selected ? option : null;
      print(selectedOption);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Uploader'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height / 2,
              child: Center(
                child: pickedFile != null
                    ? pickedFile!.extension == 'png' ||
                    pickedFile!.extension == 'jpg'
                    ? Image.file(
                  File(pickedFile!.path!),
                  fit: BoxFit.cover,
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.insert_drive_file),
                    SizedBox(height: 8),
                    Text(
                      pickedFile!.name!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                )
                    : Text('No file selected'),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: selectFile,
                  child: Text('Select File'),
                ),
                ElevatedButton(
                  onPressed: uploadFile,
                  child: Text('Upload!'),
                ),
              ],
            ),
            SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Enter Document Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedDocumentType,
              hint: Text('Select Document Type'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedDocumentType = newValue;
                });
              },
              items: documentTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            loading ? CircularProgressIndicator() : SizedBox(),
            SizedBox(height: 10),
            loading
                ? SizedBox()
                : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tags:',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: tags
                      .map(
                        (tag) => TagWidget(
                      tag: tag,
                      onDelete: () => deleteTag(tag),
                    ),
                  )
                      .toList(),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: customTagController,
                        decoration: InputDecoration(
                          hintText: 'Add Custom Tag',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () =>
                          addCustomTag(customTagController.text),
                      child: Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TagWidget extends StatelessWidget {
  final String tag;
  final VoidCallback onDelete;

  const TagWidget({
    required this.tag,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(tag),
      deleteIcon: Icon(Icons.clear),
      onDeleted: onDelete,
    );
  }
}
