import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as ml;
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:test_flutter_1/main.dart';

class Uploader extends StatefulWidget {
  @override
  _UploaderState createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> {
  PlatformFile? pickedFile;
  String scanned = "";
  List<String> tags = [];
  TextEditingController customTagController = TextEditingController();
  bool loading = false;
  FirebaseStorage storage =
      FirebaseStorage.instance; // Get Firebase Storage instance

  Future<List<String>> fetchkeys(String text) async {
    List<String> result = [];
    // Encode the text data as JSON
    String prompt = "UNDERSTAND the following text "
        "and give me a set of the top 10 most relevant keywords are related to the content"
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
        result = List<String>.from(keyList);
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
        tags.add(tag);
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
    setState(() {
      loading = true;
    });
    if (pickedFile != null) {
      try {
        // Create a reference to the upload location in Firebase Storage
        String fileName = pickedFile!.name;

        Reference ref = storage.ref('uploads/$fileName');
        List<String> keywords = await fetchkeys(scanned);
        SettableMetadata metadata = SettableMetadata(
          contentType: pickedFile!
              .extension, // You can set content type dynamically based on the file type
          customMetadata: {
            'uploaded-by': 'Flutter User',
            'file-name': pickedFile!.name ?? '',
            'tags': jsonEncode(tags),
          },
        );

        // Upload the file
        await ref.putFile(File(pickedFile!.path!), metadata);
        final doc = FirebaseFirestore.instance.collection('docs').doc(pickedFile!.name);
        final json ={
          "tag1":tags[0],
          "tag2":tags[1],
          "tag3":tags[2],
          "tag4":tags[3],
          "tag5":tags[4],
          "tag6":tags[5],
          "tag7":tags[6],
          "tag8":tags[7],
          "tag9":tags[8],
          "tag10":tags[9],


        };
        await doc.set(json);

        debugPrint('File uploaded successfully to: $ref.fullPath');
      } catch (error) {
        debugPrint('Error uploading file: $error');
        // Handle upload errors gracefully, provide user feedback
      } finally {
        setState(() {
          loading = false;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => home()),
          );

        });
      }
    } else {
      setState(() {
        loading = false;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => home()),
        );
      });
      debugPrint('Please select a file first.');
      // Inform the user to select a file
    }
  }

  Future<void> selectFile() async {
    setState(() {
      loading = true; // Start loading animation
    });

    // Request storage permission
    final status = await Permission.storage.request();

    if (status.isGranted) {
      // Permission granted, proceed with file selection
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          setState(() {
            pickedFile = result.files.first;
            scanned = ""; // Reset scanned text when new file selected
          });

          if (pickedFile!.extension == 'png' || pickedFile!.extension == 'jpg') {
            final file = File(pickedFile!.path!); // Create a File object
            final image = Image.file(file);
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
            //Load an existing PDF document.
            final PdfDocument document = PdfDocument(
                inputBytes: File(pickedFile!.path!).readAsBytesSync());
            for (int i = 0; i < document.pages.count; i++) {
              scanned +=
                  PdfTextExtractor(document).extractText(startPageIndex: i);
            }
            //Dispose the document.
            document.dispose();
          }

          // Fetch keywords/tags
          List<String> fetchedTags = await fetchkeys(scanned);
          setState(() {
            tags = fetchedTags;
          });
        }
      } catch (error) {
        // Handle potential errors with file selection
        debugPrint('Error selecting file: $error');
      } finally {
        // Stop loading animation
        setState(() {
          loading = false;
        });
      }
    } else {
      // Handle permission denial
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Storage Permission Required'),
          content: Text(
            'This app needs access to your storage to upload files. '
                'Please grant permission in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => openAppSettings(),
              child: Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      );
      // Stop loading animation
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Firebase.initializeApp().then((value) => debugPrint('Firebase initialized'));
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
