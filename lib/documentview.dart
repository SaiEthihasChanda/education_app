import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';


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
  late String documentUrl;

  @override
  void initState() {
    super.initState();
    retrieveDocumentUrl();
  }

  Future<void> retrieveDocumentUrl() async {
    try {
      final storage.Reference ref = storage.FirebaseStorage.instance.ref('uploads/${widget.id}');
      final String url = await ref.getDownloadURL();

      if (widget.id.toLowerCase().endsWith('.pdf')) {
        print("its a pdf");
        // Download the PDF file to a local cache
        final cacheDir = await getTemporaryDirectory();
        final file = File('${cacheDir.path}/document.pdf');
        print("downloading");
        await ref.writeToFile(file);
        print("download completed!");

        setState(() {
          documentUrl = file.path;
        });
      } else {
        print("its NOT A PDF!!!!!");
        setState(() {
          documentUrl = url;
        });
      }
    } catch (error) {
      print('Error getting document URL: $error');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${widget.title}',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Contributor: ${widget.contributor}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Category: ${widget.category}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Date: ${widget.date}',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            documentUrl != null
                ? Text(
              'Document URL: $documentUrl',
              style: TextStyle(fontSize: 16),
            )
                : CircularProgressIndicator(),
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
    if (documentUrl.toLowerCase().endsWith('.pdf')) {
      return PDFView(
        filePath: documentUrl,
      );
    } else{
      return Image.network(
        documentUrl,
        fit: BoxFit.contain,
      );
    }
  }
}

