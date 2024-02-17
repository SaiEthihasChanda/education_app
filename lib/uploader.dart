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
import 'main.dart';

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

  Future<List<String>> fetchkeys(String text) async {
    List<String> result = [];
    String prompt = "UNDERSTAND the following text "
        "and give me a set of the top 20 most relevant keywords are related to the content"
        "and best describe it ."
        "if required generate more keywords for accuracy but dont go overboard. "
        "the keywords must be unique as they would be used to search up this text. "
        "give me the comma seperated list of the keywords  and say nothing else but "
        "the list.. dont give me any other response. the text is as follows"
        "         \n\n\n"+text;
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
        // Decode JSON response body into a list
        List<dynamic> keyList = jsonDecode(response.body);
        for (String tag in keyList) {
          // Split tags containing multiple words into individual tags
          List<String> splitTags = tag.split(" ").where((t) => t.isNotEmpty).toList();
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
    if (pickedFile == null || titleController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Missing Information"),
            content: Text("Please select a file and enter a title."),
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
      String fileName = pickedFile!.name;
      final FirebaseAuth _auth = FirebaseAuth.instance;
      User _user = _auth.currentUser!;
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.email)
          .get();
      if (snapshot.exists){
        setState(() {
          _type = snapshot['type'];
        });
      }

      Reference ref = FirebaseStorage.instance.ref('uploads/$fileName');
      List<String> keywords = await fetchkeys(scanned);
      DateTime today = DateTime.now();
      print("todays date is: $today");
      SettableMetadata metadata = SettableMetadata(
        contentType: pickedFile!.extension,
        customMetadata: {
          'uploaded-by': snapshot['username'],
          'file-name': pickedFile!.name ?? '',
          'tags': jsonEncode(tags),
          'title': titleController.text,
          'date':''
        },
      );


      await ref.putFile(File(pickedFile!.path!), metadata);
      final doc = FirebaseFirestore.instance.collection('docs').doc(pickedFile!.name);
      final json = {
        "tags": tags,
        "title": titleController.text,
      };

      await doc.set(json);

      debugPrint('File uploaded successfully to: $ref.fullPath');
    } catch (error) {
      debugPrint('Error uploading file: $error');
    } finally {
      setState(() {
        loading = false;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => home()),
        );
      });
    }
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

          if (pickedFile!.extension == 'png' || pickedFile!.extension == 'jpg') {
            final file = File(pickedFile!.path!);
            final inputimage = ml.InputImage.fromFilePath(pickedFile!.path!);
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
                    ? pickedFile!.extension == 'png' || pickedFile!.extension == 'jpg'
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
            loading ? CircularProgressIndicator() : SizedBox(),
            SizedBox(height: 10),
            loading ? SizedBox() : Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tags:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      onPressed: () => addCustomTag(customTagController.text),
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