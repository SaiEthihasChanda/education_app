import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Uploader extends StatefulWidget {
  @override
  _UploaderState createState() => _UploaderState();
}

class _UploaderState extends State<Uploader> {
  PlatformFile? pickedFile;
  String scanned = "";
  FirebaseStorage storage = FirebaseStorage.instance; // Get Firebase Storage instance

  Future<void> uploadFile() async {
    if (pickedFile != null) {
      try {
        // Create a reference to the upload location in Firebase Storage
        String fileName = '${DateTime.now().millisecondsSinceEpoch}${pickedFile!.name}';

        Reference ref = storage.ref('uploads/$fileName');
        if(pickedFile!.extension=='png' || pickedFile!.extension=='jpg' ){
          final file = File(pickedFile!.path!); // Create a File object
          final image = Image.file(file);
          final inputimage = InputImage.fromFilePath(pickedFile!.path!);
          final textDetector = GoogleMlKit.vision.textRecognizer();
          RecognizedText recognizedText = await textDetector.processImage(inputimage);
          await textDetector.close();
          scanned = "";
          for(TextBlock block in recognizedText.blocks){
            for(TextLine lines in block.lines){
              scanned = scanned + lines.text;
            }

          }


        }
        SettableMetadata metadata = SettableMetadata(
          contentType: pickedFile!.extension, // You can set content type dynamically based on the file type
          customMetadata: {
            'uploaded-by': 'Flutter User',
            'file-name': pickedFile!.name ?? '',
            'content': scanned
          },

        );

        // Upload the file
        await ref.putFile(File(pickedFile!.path!),metadata);

        debugPrint('File uploaded successfully to: $ref.fullPath');
      } catch (error) {
        debugPrint('Error uploading file: $error');
        // Handle upload errors gracefully, provide user feedback
      }
    } else {
      debugPrint('Please select a file first.');
      // Inform the user to select a file
    }
  }

  Future<void> selectFile() async {
    // Request storage permission
    final status = await Permission.storage.request();

    if (status.isGranted) {
      // Permission granted, proceed with file selection
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          setState(() {
            pickedFile = result.files.first;
          });
        }
      } catch (error) {
        // Handle potential errors with file selection
        debugPrint('Error selecting file: $error');
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: selectFile,
              child: Text('Select File'),
            ),
            ElevatedButton(
              onPressed: uploadFile,
              child: Text('Upload!'),
            ),
            if (pickedFile != null && pickedFile!.name != null)
              Text(
                'Selected File: ${pickedFile!.name}',
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
