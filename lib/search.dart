import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;

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

  final TextEditingController _searchController = TextEditingController();
  List<String> _tags = [];
  List<String> _searchResults = [];

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
        String _profileImage = snapshot['profilepic'];
        storage.Reference ref =
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
    String searchText = _searchController.text;
    List<String> tags = searchText.split(" ");
    print(tags);

    Query query = FirebaseFirestore.instance.collection('docs');

    // Assuming each document has a field named 'tags' which is an array containing all the tags
    query = query.where('tags', arrayContainsAny: tags);

    try {
      QuerySnapshot querySnapshot = await query.get();
      List<String> matchingDocumentIds = [];
      for (QueryDocumentSnapshot documentSnapshot in querySnapshot.docs) {
        matchingDocumentIds.add(documentSnapshot.id);
      }
      print(matchingDocumentIds);
      setState(() {
        _searchResults = matchingDocumentIds;
      });
    } catch (error) {
      print("Failed to search: $error");
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
                  return ListTile(
                    title: Text(_searchResults[index]),
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

class WhereClause {
  final String field;
  final dynamic isEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;

  WhereClause(this.field,
      {this.isEqualTo,
        this.isLessThan,
        this.isLessThanOrEqualTo,
        this.isGreaterThan,
        this.isGreaterThanOrEqualTo});
}
