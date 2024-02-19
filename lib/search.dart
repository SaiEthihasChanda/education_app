import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'documentview.dart';
import 'package:intl/intl.dart'; // Import the intl package to format dates

void main() {
  runApp(MaterialApp(
    home: SearchWidget(),
  ));
}

class SearchWidget extends StatefulWidget {
  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  String _username = '';
  String _profileImageUrl = '';
  String _type = '';
  String _documentid = '';
  String DocumentURL = '';

  final TextEditingController _searchController = TextEditingController();
  List<String> _tags = [];
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    _user = _auth.currentUser!;
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.email)
        .get();
    if (snapshot.exists) {
      setState(() {
        _username = snapshot['username'];
        _type = snapshot['type'];
        _documentid = snapshot['id'];
        storage.Reference ref =
        storage.FirebaseStorage.instance.ref('uploads/$_documentid');
        ref.getDownloadURL().then((url) {
          print(url);
          setState(() {
            DocumentURL = url;
          });
        }).catchError((error) {
          print('Error getting download URL: $error');
        });


        String _profileImage = snapshot['profilepic'];
        storage.Reference docref =
        storage.FirebaseStorage.instance.ref('pfps/$_profileImage');
        ref.getDownloadURL().then((url) {
          setState(() {
            _profileImageUrl = url;
          });
        }).catchError((error) {
          print('Error getting download URL: $error');
        });
      });
    }
  }

  Future<void> _search() async {
    String searchText = _searchController.text
        .toLowerCase(); // Convert search query to lowercase
    List<String> tags = searchText.split(" ");
    print(tags);

    try {
      QuerySnapshot querySnapshot =
      await FirebaseFirestore.instance.collection('docs').get();
      List<Map<String, dynamic>> matchingDocuments = [];
      for (QueryDocumentSnapshot documentSnapshot in querySnapshot.docs) {
        Map<String, dynamic> documentData =
        documentSnapshot.data() as Map<String, dynamic>; // Cast to Map<String, dynamic>
        List<String> documentTags =
        List<String>.from(documentData['tags'] ?? []);
        String title =
            documentData['title'] ?? ''; // Get the title from the document data with null check

        bool anyTagMatches = false;
        for (String tag in tags) {
          // Remove leading and trailing whitespace from document tags and convert to lowercase
          List<String> trimmedTags =
          documentTags.map((t) => t.trim().toLowerCase()).toList();
          if (trimmedTags.contains(tag)) {
            anyTagMatches = true;
            break;
          }
        }

        if (anyTagMatches && title.isNotEmpty) {
          matchingDocuments.add(documentData);
        }
      }

      print("Matching Documents: $matchingDocuments");
      setState(() {
        _searchResults = matchingDocuments;
      });
    } catch (error) {
      print("Failed to fetch documents: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      hintText: 'Enter search query',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _search,
                  child: Text('Search'),
                ),
              ],
            ),
            SizedBox(height: 20),
            Expanded(
              child: _searchResults.isNotEmpty
                  ? ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  Map<String, dynamic> documentData =
                  _searchResults[index];
                  String title = documentData['title'];
                  String contributor = documentData['contributor'] ?? 'Unknown';
                  String category = documentData['category'] ?? 'Unknown';
                  String date = documentData['date'] ?? '';
                  String docid = documentData['id'] ??'';

                  return GestureDetector(
                    onTap: () async {
                      String userEmail = _auth.currentUser!.email!;
                      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(userEmail);
                      DocumentSnapshot userDocSnapshot = await userDocRef.get();

                      // Check if the "recent10" attribute exists
                      if (!userDocSnapshot.exists || !(userDocSnapshot.data() as Map<String, dynamic>).containsKey('recent10')){
                        // If it doesn't exist, initialize it as an empty list
                        await userDocRef.set({'recent10': []}, SetOptions(merge: true));
                      }

                      // Retrieve the current "recent10" list from the document data
                      List<String> recent10 = List<String>.from(userDocSnapshot['recent10'] ?? []);

                      // Add the document ID to the "recent10" list
                      if (!recent10.contains(docid)) {
                        recent10.add(docid);

                        // Remove the oldest element if the list exceeds 10 elements
                        if (recent10.length > 10) {
                          recent10.removeAt(0);
                        }

                        // Update the document with the updated "recent10" list
                        await userDocRef.update({'recent10': recent10});
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DocumentView(
                              title: title,
                              contributor: contributor,
                              category: category,
                              date: date,
                              id: docid
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation:
                      3, // Adjust the elevation for the shadow effect
                      margin: EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines:
                                    2, // Limit the number of lines
                                  ),
                                ),

                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                    radius: 20,
                                    backgroundImage: _profileImageUrl.isNotEmpty
                                        ? NetworkImage(_profileImageUrl) as ImageProvider<Object>?
                                        : AssetImage('assets/placeholder.jpg') // Placeholder image
                                ),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    contributor,
                                    style: TextStyle(
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    'ABCDEF University',
                                    style: TextStyle(
                                      fontSize: 13,
                                      //color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  date,
                                  style: TextStyle(fontSize: 8),
                                ),
                              ],
                            ),

                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [

                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              )
                  : Center(
                child: Text('No results found'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}