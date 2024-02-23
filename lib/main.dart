import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

import 'User.dart';
import 'vault.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'documentview.dart';


import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as ml;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider package
import 'package:permission_handler/permission_handler.dart';

import 'search.dart';
import 'uploader.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyB-nbsgPB9gWBSS6w8QIspXPYaONyoUy3Y",
      appId: "1:372358481738:android:b81694071e633af073e3b3",
      messagingSenderId: "372358481738",
      projectId: "educationapp-23878",
      storageBucket: 'educationapp-23878.appspot.com',
    ),
  );


  runApp(MyApp());

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FirebaseAuth.instance.currentUser != null ? home() : LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController user = TextEditingController();
  final TextEditingController pass = TextEditingController();
  bool _valid = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  "ReadIt.",
                style: TextStyle(
                  fontSize: 90,
                  fontFamily: "LobsterTwo",
                ),

              ),
              SizedBox(height: 40),
              Container(
                width: 200,
                child: TextField(
                  controller: user,
                  decoration: InputDecoration(
                    labelText: 'email',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: 200,
                child: TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Container(
                width: 200,
                child: ElevatedButton(
                  onPressed: () async {
                    String mail = user.text;
                    String password = pass.text;
                    try {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: mail,
                        password: password,
                      );
                      _saveCredentials(mail, password); // Save credentials
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => home()),
                      );
                    } catch (error) {
                      setState(() {
                        print('Invalid Credentials!');
                        _valid = true;
                      });
                    }
                  },
                  child: Text('Submit'),
                ),
              ),
              SizedBox(height: 20),
              Visibility(
                visible: _valid,
                child: Text(
                  'Invalid Credentials',
                  style: TextStyle(
                    color: Colors.red,
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                  );
                },
                child: Text('Dont have an account? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String _profilePicName = '';
  String _documentFileName = '';
  PlatformFile? pickedFile;
  String _userType = 'student';
  bool loading = false;

  File? _profilePic;
  File? _idFile;

  void pfpSet() async {
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {

      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        setState(() {
          pickedFile = result.files.first;
          _profilePic = File(pickedFile!.path!);
          _profilePicName = pickedFile!.path!.split('/').last;
        });
      }

    }
    else{
      openAppSettings();
    }
  }

  Future<String> verify(String text) async {
    String prompt = "can you please fix the following text and tell me if the college name "
        "mentioned is an existing college... tell me yes or no"
        "\n\n\n"
        + text;
    String requestBody = jsonEncode({'content': prompt});
    try {
      var response = await http.post(
        Uri.parse('http://65.0.32.85:5000/verify'),
        body: requestBody,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
      ).timeout(const Duration(seconds: 15));
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        String R = jsonDecode(response.body);
        print("===============");
        print(R+"this is the part ur checking");
        if(R.toLowerCase().contains("yes")){
          return "yes";
        }

        print("===============");
      } else {
        print('Failed to verify. Status code: ${response.statusCode}');
        return "no";
      }
    } catch (error) {
      print('Error sending request: $error');
      return "no";
    }
    return "no";
  }

  void documentVerify() async {
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          pickedFile = result.files.first;
          _idFile = File(pickedFile!.path!);
          _documentFileName = pickedFile!.path!.split('/').last;
          setState(() {});
        }
      } catch (error) {
        print(error);
      }
    }
    else if(status.isPermanentlyDenied)
    {
      openAppSettings();
    }
  }

  Future<void> _createAccount() async {
    String email = emailController.text;
    String username = usernameController.text;
    String password = passwordController.text;




    String profilePicId = DateTime.now().millisecondsSinceEpoch.toString();

    String profilePicPath = 'pfps/$profilePicId';
    try{



      setState(() {
        loading = true;
      });
      if (_idFile != null && _userType == 'contributor') {
        String scanned = "";
        final inputimage = ml.InputImage.fromFilePath(pickedFile!.path!);
        final textDetector = ml.GoogleMlKit.vision.textRecognizer();
        ml.RecognizedText recognizedText = await textDetector.processImage(inputimage);
        await textDetector.close();
        for (ml.TextBlock block in recognizedText.blocks) {
          for (ml.TextLine lines in block.lines) {
            setState(() {
              scanned += lines.text;
            });
          }
        }
        print("========================");
        print(scanned);
        print("==========================");
        String verified = await verify(scanned);
        print(verified+" is it verified???");

        if (verified == "yes") {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          _saveCredentials(email, password);
          final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
          final userData = {
            'username': username,
            'profilepic': profilePicId ?? '',
            'type': _userType,




          };
          await userDoc.set(userData);
          SettableMetadata metadata = SettableMetadata(
            contentType: pickedFile!
                .extension, // You can set content type dynamically based on the file type
          );
          if(pickedFile != null){
            await FirebaseStorage.instance.ref(profilePicPath).putFile(_profilePic!, metadata);
          }


          await FirebaseStorage.instance.ref(profilePicPath).putFile(_profilePic!, metadata);
          setState(() {
            loading = false;
          });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => home()),
          );
        }
        else{
          setState(() {
            loading = false;
          });

          //dialogbox
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text("Verification Failed"),
                content: Text(
                    "ReadIt was unable to verify your provided document. please try another picture if you think we are wrong"),
                actions: <Widget>[
                  TextButton(
                    child: Text("OK"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        }
      }
      else if(_userType == 'student') {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        _saveCredentials(email, password);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => home()),
        );
        final userDoc = FirebaseFirestore.instance.collection('users').doc(
            email);
        final userData = {
          'username': username,
          'profilepic': profilePicId ?? '',
          'type': _userType,

        };
        await userDoc.set(userData);
        SettableMetadata metadata = SettableMetadata(
          contentType: pickedFile!
              .extension, // You can set content type dynamically based on the file type
        );
        await FirebaseStorage.instance.ref(profilePicPath).putFile(
            _profilePic!, metadata);
      }
      setState(() {
        loading = false;
      });


    }catch(e){
      setState(() {
        loading = false;
      });
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("ERROR"),
            content: Text(
                "An unexpected error has occured \n \n $e"),
            actions: <Widget>[
              TextButton(
                child: Text("OK"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(' Sign Up'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: pfpSet,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[200],
                  ),
                  child: _profilePic != null
                      ? ClipOval(
                    child: Image.file(_profilePic!, fit: BoxFit.cover),
                  )
                      : Icon(Icons.add_a_photo),
                ),
              ),
              SizedBox(height: 10),
              Text('Upload your profile picture'),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio(
                    value: 'student',
                    groupValue: _userType,
                    onChanged: (value) {
                      setState(() {
                        _userType = value.toString();
                      });
                    },
                  ),
                  Text('Student'),
                  Radio(
                    value: 'contributor',
                    groupValue: _userType,
                    onChanged: (value) {
                      setState(() {
                        _userType = value.toString();
                      });
                    },
                  ),
                  Text('Contributor'),
                ],
              ),
              if (_userType == 'contributor') ...[
                SizedBox(height: 20),
                Visibility(

                  child: Text(
                    _idFile==null?'Upload ID from your registered College/University'
                    :"selected file: "+_idFile.toString(),
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                SizedBox(height: 10),


                  ElevatedButton(
                    onPressed: documentVerify,
                    child: Text('Upload Document'),
                  ),

              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAccount,
                child: Text('Create Account'),
              ),
              SizedBox(height: 20),
              loading ? CircularProgressIndicator() : SizedBox(),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Text(
          'ReadIt.',
          style: TextStyle(
            fontSize: 50,
            fontFamily: 'LobsterTwo',

          ),


        ),
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<String>(
        future: _getUserInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // While waiting for the future to complete, show a loading indicator
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHomeContent(),
                SizedBox(height: 20),
                CircularProgressIndicator(),
              ],
            );
          } else if (snapshot.hasError) {
            // If an error occurs, display an error message
            return Text('Error: ${snapshot.error}');
          } else {
            // If the future completes successfully, build the UI based on the retrieved data
            final userType = snapshot.data ?? 'student'; // Default value if data is null
            if (userType == "contributor") {
              return Scaffold(
                body: _buildHomeContent(),
                bottomNavigationBar: BottomNavigationBar(
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
                  currentIndex: 0,
                  selectedItemColor: Colors.blue,
                  onTap: (int index) {
                    switch (index) {
                      case 0:
                      // Add logic to navigate to the home page
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
                      case 4: // Search button tapped
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => SearchWidget()),
                        );
                        break;
                    }
                  },
                ),
              );
            } else {
              // If the user is not a contributor, you can return a different UI here
              return Scaffold(
                body: _buildHomeContent(),
                bottomNavigationBar: BottomNavigationBar(
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
                  currentIndex: 0,
                  selectedItemColor: Colors.blue,
                  onTap: (int index) {
                    switch (index) {
                      case 0:
                      // Add logic to navigate to the home page
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
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => SearchWidget()),
                        );
                        break;
                    }
                  },
                ),
              );
            }
          }
        },
      ),
    );
  }






  Widget _buildHomeContent() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Recently Viewed',
                          textStyle: const TextStyle(
                              fontSize: 18.0,
                              fontFamily: 'roboto',
                              fontWeight: FontWeight.bold

                          ),
                          speed: const Duration(milliseconds: 200),
                        ),
                      ],

                      totalRepeatCount: 1,
                      pause: const Duration(milliseconds: 100),
                      displayFullTextOnTap: true,
                      stopPauseOnTap: true,
                    ),
                    SizedBox(width: 16),
                  ],
                ),
              ),
              SizedBox(width: 50),
              SizedBox(
                height: 180,
                child: FutureBuilder<List<String>>(
                  future: _getRecentFiles(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      List<String> recentFiles = snapshot.data ?? [];
                      return Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: Padding(
                          padding: EdgeInsets.only(left: 10.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentFiles.length,
                            itemBuilder: (context, index) {
                              return _buildDocumentCard(recentFiles[index]);
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child:AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'Popular',
                      textStyle: const TextStyle(
                          fontSize: 18.0,
                          fontFamily: 'roboto',
                          fontWeight: FontWeight.bold

                      ),
                      speed: const Duration(milliseconds: 500),
                    ),
                  ],

                  totalRepeatCount: 1,
                  pause: const Duration(milliseconds: 500),
                  displayFullTextOnTap: true,
                  stopPauseOnTap: true,
                ),
              ),
              SizedBox(
                height: 180,
                child: FutureBuilder<List<String>>(
                  future: _getPopularFiles(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      List<String> popularFiles = snapshot.data ?? [];
                      return Padding(
                        padding: EdgeInsets.only(top: 20.0),
                        child: Padding(
                          padding: EdgeInsets.only(left: 10.0),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: popularFiles.length,
                            itemBuilder: (context, index) {
                              return _buildDocumentCard(popularFiles[index]);
                            },
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(String fileId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('docs').doc(fileId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingCard();
          } else if (snapshot.hasError) {
            return _buildErrorCard(snapshot.error.toString());
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildDeletedCard();
          } else {
            String title = snapshot.data!.get('title') ?? 'Untitled';
            String category = snapshot.data!.get('category') ?? 'General';
            String date = snapshot.data!.get('date') ?? '';
            int votes = snapshot.data!.get('votes') ?? 0;
            String docid = snapshot.data!.get('id')??'';
            return GestureDetector(
              onTap: () {
                String contr = snapshot.data!.get('contributor') ?? '';
                String pfp = snapshot.data!.get('userpfp') ?? '';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentView(
                      title: title,
                      contributor: contr,
                      category: category,
                      date: date,
                      id: docid,
                      votes: votes,
                      pfp: pfp,
                    ),
                  ),
                );
                print('Popular card clicked: $title');
              },
              child: _buildCardWidget(
                title: title,
                category: category,
                date: date,
                votes: votes,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCardWidget({required String title, required String category, required String date, required int votes}) {

    return SizedBox(
      width: 200,
      child: Card(
        color: Colors.white, // Set the background color to white
        elevation: 2, // Add elevation for a shadow effect
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Apply rounded corners
          side: BorderSide(color: Colors.black, width: 1), // Add a black border
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: "roboto",
                      fontSize: 18
                    ),
                  ),
                  SizedBox(height: 8),
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        category.toUpperCase(),
                        textStyle: const TextStyle(
                            fontSize: 14.0,
                            fontFamily: 'roboto',
                            color: Colors.green

                        ),
                        speed: const Duration(milliseconds:10 ),
                      ),
                    ],

                    totalRepeatCount: 1,
                    pause: const Duration(milliseconds: 10),
                    displayFullTextOnTap: true,
                    stopPauseOnTap: true,
                  ),
                ],
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.thumb_up),
                        SizedBox(width: 4),
                        Text(
                          '$votes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Date: $date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildLoadingCard() {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Error: $errorMessage'),
        ),
      ),
    );
  }

  Widget _buildDeletedCard() {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'The requested file may have been deleted due to privacy and security reasons',
            style: TextStyle(
              color: Colors.red,
              fontFamily: 'roboto',
            ),
          ),
        ),
      ),
    );
  }








  Future<List<String>> _getRecentFiles() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final String userEmail = _auth.currentUser!.email!;

    try {
      DocumentSnapshot userDocSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userEmail)
          .get();

      // Check if the user document exists and contains the recent10 attribute
      if (!userDocSnapshot.exists || !(userDocSnapshot.data() as Map<String, dynamic>).containsKey('recent10')) {
        print('empty recents');
        return []; // Return an empty list if the recent10 attribute doesn't exist
      }

      List<dynamic> recentFiles = userDocSnapshot['recent10'];

      List<String> recentFileNames = recentFiles.map((fileName) {
        String name = fileName.toString();
        if (name.endsWith('.pdf')) {
          // Remove the ".pdf" extension
          name = name.substring(0, name.length - 4);
        }
        return name;
      }).toList();
      print("recent files are $recentFileNames");
      return recentFileNames;
    } catch (e) {
      print('Error getting recent files: $e');
      return []; // Return an empty list in case of an error
    }
  }


  Future<List<String>> _getPopularFiles() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('docs')
          .orderBy('votes', descending: true) // Sort documents by 'votes' field in descending order
          .limit(100) // Limit the results to 10 documents, adjust as needed
          .get();

      List<String> popularFileIds = snapshot.docs.map((doc) => doc.id).toList();
      return popularFileIds;
    } catch (e) {
      print('Error getting popular files: $e');
      return []; // Return an empty list in case of an error
    }
  }
}

Future<String> _getUserInfo() async {
  try {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User _user = _auth.currentUser!;
    final DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.email)
        .get();

    if (snapshot.exists) {
      final userType = snapshot['type'].toString();

      // Check if the "liked" attribute exists, if not, create it
      if (!(snapshot.data() as Map<String, dynamic>).containsKey('liked')) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user.email)
            .set({'liked': []}, SetOptions(merge: true));
      }

      return userType;
    } else {
      // If user data doesn't exist, return 'student' and create the 'liked' attribute
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.email)
          .set({'liked': []}, SetOptions(merge: true));
      return 'student';
    }
  } catch (error) {
    print('Error getting user info: $error');
    return 'student'; // Default value if there's an error
  }
}

Future<void> _saveCredentials(String email, String password) async {
  // Get the directory for the app's local files.
  if (email != ''&& password!=''){
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory.path}/creds.txt');
    final String data = '$email|$password';
    await file.writeAsString(data);

  }

}



Future<List<String>?> _readCredentials() async {
  try {
    final file = File('creds.txt');
    if (await file.exists()) {
      final contents = await file.readAsString();
      if (contents.isNotEmpty) {
        return contents.split(',');
      }
    }
  } catch (e) {
    print('Error reading credentials: $e');
  }
  return null; // Return null if file doesn't exist or is empty
}

class AnimatedRecentlyViewedText extends StatefulWidget {
  final String text;

  const AnimatedRecentlyViewedText({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  _AnimatedRecentlyViewedTextState createState() => _AnimatedRecentlyViewedTextState();
}

class _AnimatedRecentlyViewedTextState extends State<AnimatedRecentlyViewedText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 500), // Adjust the duration as needed
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _animation.value,
      duration: Duration(milliseconds: 1000), // Adjust the duration as needed
      child: Text(
        widget.text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'roboto',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}