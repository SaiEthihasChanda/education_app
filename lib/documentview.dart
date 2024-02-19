import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class DocumentView extends StatefulWidget {
  final String title;
  final String contributor;
  final String category;
  final String date;
  final String id;

  DocumentView({
    required this.title,
    required this.contributor,
    required this.category,
    required this.date,
    required this.id,
  });

  @override
  _DocumentViewState createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  String? documentUrl;
  bool isLoading = true;
  bool isDownloaded = false;

  @override
  void initState() {
    super.initState();
    retrieveDocumentUrl();
    checkIfDownloaded();
  }

  Future<void> retrieveDocumentUrl() async {
    try {
      final storage.Reference ref = storage.FirebaseStorage.instance.ref('uploads/${widget.id}');
      final String url = await ref.getDownloadURL();

      if (widget.id.toLowerCase().endsWith('.pdf')) {
        print("its a pdf");
        // Download the PDF file to a local cache
        final cacheDir = await getTemporaryDirectory();
        final file = File('${cacheDir.path}/${widget.id}');
        print("downloading");
        await ref.writeToFile(file);
        print("download completed!");

        setState(() {
          documentUrl = file.path;
          isLoading = false;
        });
      } else {
        print("its NOT A PDF!!!!!");
        setState(() {
          documentUrl = url;
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error getting document URL: $error');
    }
    print(documentUrl);
  }

  Future<void> checkIfDownloaded() async {
    final newDir = await getApplicationDocumentsDirectory();
    final newFile = File('${newDir.path}/ReadIt/${widget.id}');
    setState(() {
      isDownloaded = newFile.existsSync();
    });
  }

  Future<void> downloadFile() async {
    if (documentUrl != null) {
      try {
        final response = await http.get(Uri.parse(documentUrl!));
        final newDir = await getApplicationDocumentsDirectory();
        final newFolder = Directory('${newDir.path}/ReadIt');
        if (!newFolder.existsSync()) {
          newFolder.createSync(recursive: true);
        }
        final newFile = File('${newDir.path}/ReadIt/${widget.id}');
        await newFile.writeAsBytes(response.bodyBytes);

        setState(() {
          isDownloaded = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded successfully'),
          ),
        );
      } catch (error) {
        print('Error downloading file: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Back"),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.category,
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  widget.date,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      //backgroundImage: AssetImage('assets/profile_pic.png'), // Placeholder image
                    ),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploaded by:',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.contributor,
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isDownloaded ? null : downloadFile,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isDownloaded
                      ? Row(
                    children: [
                      Icon(Icons.check, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Downloaded', style: TextStyle(fontSize: 16)),
                    ],
                  )
                      : Row(
                    children: [
                      Icon(Icons.download, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Download', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _buildDocumentWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentWidget() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    } else if (documentUrl != null && documentUrl!.toLowerCase().endsWith('.pdf')) {
      return PDFView(
        filePath: documentUrl!,
      );
    } else if (documentUrl != null) {
      return Image.network(
        documentUrl!,
        fit: BoxFit.contain,
      );
    } else {
      return Text('Document URL is null');
    }
  }
}