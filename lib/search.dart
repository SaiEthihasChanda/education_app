import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:test_flutter_1/uploader.dart';
import 'package:intl/intl.dart';
import 'vault.dart';
import 'User.dart';
import 'documentview.dart';
import 'main.dart';

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
        //_documentid = snapshot['id'];
        print("image name are"+snapshot['profilepic']);
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
        print("url codes are"+_profileImage);
        ref =
        storage.FirebaseStorage.instance.ref('pfps/$_profileImage');
        ref.getDownloadURL().then((url) { // Changed ref to docref
          setState(() {
            _profileImageUrl = url; // Fixed typo here
            print("url is" + _profileImageUrl);
          });
        }).catchError((error) {
          print('Error getting download URL: $error');
        });
      });
    }
  }


  Future<void> _search() async {
    String searchText = _searchController.text.toLowerCase();
    List<String> tags = searchText.split(" ");
    print(tags);

    try {
      QuerySnapshot querySnapshot =
      await FirebaseFirestore.instance.collection('docs').get();
      List<Map<String, dynamic>> matchingDocuments = [];
      for (QueryDocumentSnapshot documentSnapshot in querySnapshot.docs) {
        Map<String, dynamic> documentData =
        documentSnapshot.data() as Map<String, dynamic>;
        List<String> documentTags =
        List<String>.from(documentData['tags'] ?? []);
        String title = documentData['title'] ?? '';

        bool anyTagMatches = false;
        for (String tag in tags) {
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

      // Sort the matching documents by descending order of votes
      matchingDocuments.sort((a, b) => (b['votes'] ?? 0).compareTo(a['votes'] ?? 0));

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
                  String contributor =
                      documentData['contributor'] ?? 'Unknown';
                  String category = documentData['category'] ?? 'Unknown';
                  String date = documentData['date'] ?? '';
                  String docid = documentData['id'] ?? '';
                  int votes = documentData['votes'] ?? 0;
                  String pfp = documentData['userpfp']??'';
                  print(pfp);

                  return GestureDetector(
                    onTap: () async {
                      String userEmail = _auth.currentUser!.email!;
                      DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(userEmail);
                      DocumentSnapshot userDocSnapshot = await userDocRef.get();

                      if (!userDocSnapshot.exists || !(userDocSnapshot.data() as Map<String, dynamic>).containsKey('recent10')) {
                        await userDocRef.set({'recent10': []}, SetOptions(merge: true));
                      }

                      List<String> recent10 = List<String>.from(userDocSnapshot['recent10'] ?? []);

                      if (!recent10.contains(docid)) {
                        recent10.add(docid);

                        if (recent10.length > 10) {
                          recent10.removeAt(0);
                        }

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
                            id: docid,
                            votes: votes,
                            pfp:pfp
                          ),
                        ),
                      );
                    },

                    child: Card(
                      elevation: 3,
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
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '$votes Likes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(pfp),
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    if (_type == "contributor") {
      return BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'Storage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: 4,
        selectedItemColor: Colors.blue,
        onTap: (int index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => home()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => VaultPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Uploader()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              );
              break;
            case 4:
            // Add logic if needed when the search page is tapped again
              break;
          }
        },
      );
    } else {
      return BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'Storage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: 3,
        selectedItemColor: Colors.blue,
        onTap: (int index) {
          switch (index) {
            case 0:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => home()),
              );
              break;
            case 1:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => VaultPage()),
              );
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              );
              break;
            case 3:
            // Add logic if needed when the search page is tapped again
              break;
          }
        },
      );
    }
  }
}
