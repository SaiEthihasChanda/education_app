import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:path_provider/path_provider.dart';

import 'package:test_flutter_1/uploader.dart';
import 'main.dart';
import 'search.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  String _username = '';
  String _profileImageUrl = '';
  String _type = "";

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
      print("image url is $_profileImageUrl");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _user != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 80,
                backgroundImage: NetworkImage(_profileImageUrl),
              ),
              SizedBox(height: 20),
              Text(
                _username,
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              Text(
                "Email: ${_auth.currentUser!.email}",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 10),
              Text(
                "Account Type: $_type",
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await _auth.signOut();
                  final Directory directory =
                  await getApplicationDocumentsDirectory();
                  final file = File('${directory.path}/creds.txt');
                  file.delete();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                        (route) => false,
                  );
                },
                child: Text('Sign out'),
              ),
            ],
          ),
        ),
      )
          : Center(
        child: CircularProgressIndicator(),
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
            icon: Icon(Icons.search), // Icon for current page
            label: 'Search',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: 3, // Index of the current page (Profile)
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
            // Add logic to navigate to the storage page
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => Uploader()),
              );
              break;
            case 3:
              break;
            case 4:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SearchWidget()),
              );
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
            icon: Icon(Icons.search), // Icon for current page
            label: 'Search',
          ),
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: 3, // Index of the current page (Profile)
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
            // Add logic to navigate to the storage page
              break;
            case 2:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => UserProfilePage()),
              );
              break;
            case 3:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => SearchWidget()),
              );
              break;
          }
        },
      );
    }
  }
}

void main() {
  runApp(MaterialApp(
    home: UserProfilePage(),
  ));
}
