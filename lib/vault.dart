import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as storage;
import 'package:path_provider/path_provider.dart';
import 'main.dart';
import 'User.dart';
import 'documentview.dart';
import 'search.dart';
import 'uploader.dart';

void main() {
  runApp(MaterialApp(
    home: VaultPage(),
  ));
}

class VaultPage extends StatefulWidget {
  @override
  _VaultPageState createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late User _user;
  late List<File> _files = [];

  @override
  void initState() {
    super.initState();
    _getUser();
    _loadFiles();
  }

  Future<void> _getUser() async {
    _user = _auth.currentUser!;
  }

  Future<void> _loadFiles() async {
    Directory newDir = await getApplicationDocumentsDirectory();
    Directory readItDir = Directory('${newDir.path}/ReadIt');
    List<FileSystemEntity> files = readItDir.listSync();
    setState(() {
      _files = files.whereType<File>().toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vault'),
      ),
      body: _buildFileCards(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildFileCards() {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        File file = _files[index];
        String fileName = file.path.split('/').last;

        // Check if the file name ends with ".pdf"
        if (fileName.endsWith('.pdf')) {
          // Remove the ".pdf" extension
          fileName = fileName.substring(0, fileName.length - 4);
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('docs').doc(fileName).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                title: Text('Loading...'),
              ); // Show loading indicator while fetching data
            } else if (snapshot.hasError) {
              return ListTile(
                title: Text('Error: ${snapshot.error}'),
              );
            } else if (!snapshot.hasData || snapshot.data!.data() == null) {
              // Delete the file if it is not found
              file.deleteSync();

              // Remove the file from the list of files
              setState(() {
                _files.removeAt(index);
              });

              return ListTile(
                title: Text('File not found: $fileName'),
              );
            } else {
              Map<String, dynamic> fileData = snapshot.data!.data() as Map<String, dynamic>;
              String title = fileData['title'] ?? 'Untitled';
              String contributor = fileData['contributor'] ?? 'Unknown';
              String date = fileData['date'] ?? '';
              String userpfp = fileData['userpfp'] ?? ''; // Assuming this is the profile picture URL
              int votes = fileData['votes'] ?? 0;
              String category = fileData['category'] ?? 'General';
              // Now, create the card with retrieved data
              return Card(
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Contributor: $contributor'),
                      Text('Date: $date'),
                      // Add more information here as needed
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(userpfp), // Assuming userpfp is the URL to the profile picture
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          // Delete the file
                          file.deleteSync();
                          // Remove the file from the list
                          setState(() {
                            _files.removeAt(index);
                          });
                        },
                      ),
                      Text('Votes: $votes'),
                    ],
                  ),
                  onTap: () {
                    // Handle tap on the file
                    // You can open the file or do other actions here
                  },
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return FutureBuilder<String>(
      future: _getUserInfo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // While waiting for the future to complete, return an empty container
          return Container();
        } else if (snapshot.hasError) {
          // If an error occurs, return an empty container
          return Container();
        } else {
          // If the future completes successfully, build the bottom navigation bar based on the retrieved data
          final userType = snapshot.data ?? 'student'; // Default value if data is null
          if (userType == "contributor") {
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
                  icon: Icon(Icons.search), // New search icon
                  label: 'Search',
                ),
              ],
              type: BottomNavigationBarType.fixed,
              currentIndex: 1, // Set the current index to 1 for the VaultPage
              selectedItemColor: Colors.blue,
              onTap: (int index) {
                // Handle navigation based on the tapped index
                switch (index) {
                  case 0:
                  // Add logic to navigate to the home page
                    break;
                  case 1:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => home()),
                    );
                    break;
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
                  case 4: // Search button tapped
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => SearchWidget()),
                    );
                    break;
                }
              },
            );
          } else {
            // If the user is not a contributor, you can return a different bottom navigation bar here
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
                  icon: Icon(Icons.search), // New search icon
                  label: 'Search',
                ),
              ],
              type: BottomNavigationBarType.fixed,
              currentIndex: 1, // Set the current index to 1 for the VaultPage
              selectedItemColor: Colors.blue,
              onTap: (int index) {
                // Handle navigation based on the tapped index
                switch (index) {
                  case 0:
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => home()),
                    );
                    break;
                  case 1:
                  // VaultPage is already selected
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
      },
    );
  }

  Future<String> _getUserInfo() async {
    // Add your logic to retrieve user information (e.g., user type)
    // For now, returning a default value
    return 'student';
  }
}
