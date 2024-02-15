import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  String _username = '';
  String _profileImageUrl = '';

  @override
  Future<void> initState() async {
    super.initState();
    _getUserInfo();

  }

  void _getUserInfo() async {
    _user = _auth.currentUser!;
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.email)
        .get();
    if (snapshot.exists) {
      setState(() {
        _username = snapshot['username']; // Retrieve username from Firestore

        _profileImageUrl = snapshot['profilepic'];

      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
      ),
      body: _user != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.1,
            ), // Center top position
            CircleAvatar(
              radius: 80, // Increase the size of the profile picture

              backgroundImage:  NetworkImage(_profileImageUrl) // Use profile image from URL if available

            ),
            SizedBox(height: 20),
            Text(
              _username,
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      )
          : Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: UserProfilePage(),
  ));
}
