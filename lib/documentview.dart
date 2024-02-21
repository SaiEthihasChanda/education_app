import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final int votes;
  final String pfp;

  DocumentView({
    required this.title,
    required this.contributor,
    required this.category,
    required this.date,
    required this.id,
    required this.votes,
    required this.pfp
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
        final cacheDir = await getTemporaryDirectory();
        final file = File('${cacheDir.path}/${widget.id}');
        await ref.writeToFile(file);

        setState(() {
          documentUrl = file.path;
          isLoading = false;
        });
      } else {
        setState(() {
          documentUrl = url;
          isLoading = false;
        });
      }
    } catch (error) {
      print('Error getting document URL: $error');
    }
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
        if (widget.id.endsWith(".pdf")){
          Directory readItDir = Directory('${(await getApplicationDocumentsDirectory()).path}/ReadIt');
          if (!readItDir.existsSync()) {
            readItDir.createSync(recursive: true);
          }

          // Copy the file to the ReadIt directory
          await File(documentUrl!).copy('${readItDir.path}/${widget.id}');
          setState(() {
            isDownloaded = true;
          });

        }
        else{
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
        }


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




  Future<void> toggleLike(bool like) async {
    final userEmail = FirebaseAuth.instance.currentUser!.email!;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userEmail);
    final userDocSnapshot = await userDocRef.get();

    // Check if the "liked" attribute exists
    if (!userDocSnapshot.exists || !(userDocSnapshot.data() as Map<String, dynamic>).containsKey('liked')) {
      // If it doesn't exist, initialize it as an empty list
      await userDocRef.set({'liked': []}, SetOptions(merge: true));
    }

    // Retrieve the current "liked" list from the document data
    final List<String> likedDocuments = List<String>.from(userDocSnapshot.get('liked') ?? []);

    // Remove ".pdf" extension if the document ID ends with ".pdf"
    final documentId = widget.id.endsWith('.pdf') ? widget.id.substring(0, widget.id.length - 4) : widget.id;

    // Add or remove the document ID based on the 'like' parameter
    if (like) {
      if (!likedDocuments.contains(documentId)) {
        likedDocuments.add(documentId);
        // Increment the votes for the corresponding document ID
        await FirebaseFirestore.instance.collection('docs').doc(documentId).set({
          'votes': FieldValue.increment(1),
        }, SetOptions(merge: true)); // Create the 'votes' attribute if it doesn't exist
      }
    } else {
      likedDocuments.remove(documentId);
      // Decrement the votes for the corresponding document ID
      await FirebaseFirestore.instance.collection('docs').doc(documentId).set({
        'votes': FieldValue.increment(-1),
      }, SetOptions(merge: true)); // Create the 'votes' attribute if it doesn't exist
    }

    // Update the document with the updated "liked" list
    await userDocRef.update({'liked': likedDocuments});
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
                  widget.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Text(
                  widget.date,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uploaded by card
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 98,
                    child: Card(
                      color: Colors.white,

                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // Apply rounded corners
                        side: BorderSide(color: Colors.black, width: 1), // Add a black border
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(widget.pfp),
                            ),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uploaded by:',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(

                                  widget.contributor.length>15?widget.contributor.substring(0, 15)
                                  :widget.contributor,
                                  style: TextStyle(fontSize: 18),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Like count and like button
                Expanded(
                  flex: 1,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.email!).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final likedDocuments = List<String>.from(snapshot.data?.get('liked') ?? []);
                      final documentId = widget.id.endsWith('.pdf') ? widget.id.substring(0, widget.id.length - 4) : widget.id;
                      final isLiked = likedDocuments.contains(documentId);
                      return Card(
                        elevation: 2,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), // Apply rounded corners
                          side: BorderSide(color: Colors.black, width: 1), // Add a black border
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(
                                widget.votes.toString(),
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              ElevatedButton(

                                onPressed: () async {
                                  if (likedDocuments.contains(documentId)) {
                                    await toggleLike(false);
                                  } else {
                                    await toggleLike(true);
                                  }
                                },
                                child: isLiked ? Icon(Icons.thumb_up, color: Colors.black) : Icon(Icons.thumb_up_outlined, color: Colors.black),
                                style: ElevatedButton.styleFrom(

                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5.0),
                                      side: BorderSide(color: Colors.black, width: 1),

                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 10), // Reduced the height here
            // Download button
            ElevatedButton(
              onPressed: isDownloaded ? null : downloadFile,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Centering the contents horizontally
                children: [
                  isDownloaded
                      ? Icon(Icons.check, color: Colors.black)
                      : Icon(Icons.download, color: Colors.black),
                  SizedBox(width: 8),
                  Text(isDownloaded ? 'File saved' : 'Save File',
                      style: TextStyle(fontSize: 16)),
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
      return Center(
        child: PDFView(
          filePath: documentUrl!,
        ),
      );
    } else if (documentUrl != null) {
      return Center(
        child: Image.network(
          documentUrl!,
          fit: BoxFit.contain,
        ),
      );
    } else {
      return Center(
        child: Text('Document URL is null'),
      );
    }
  }

}
