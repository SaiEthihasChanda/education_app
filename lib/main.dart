import 'dart:convert';
import 'dart:io';
import 'uploader.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart' as ml;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';

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
      home: LoginPage(),
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
      appBar: AppBar(
        title: Center(
          child: Text('Login'),
        ),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                  onPressed: () {
                    String mail = user.text;
                    String password = pass.text;
                    FirebaseAuth.instance
                        .signInWithEmailAndPassword(
                        email: mail, password: password)
                        .then((value) {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => home()));
                    }).onError((error, stackTrace) {
                      setState(() {
                        print('Invalid Credentials!');
                        _valid = true;
                      });
                    });
                  },
                  child: Text('Submit'),
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpPage()),
                  );
                },
                child: Text(
                  "Don't have an account? Sign up",
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
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

  File? _profilePic;
  File? _idFile;

  void pfpSet() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null) {
          setState(() {
            pickedFile = result.files.first;
            _profilePic = File(pickedFile!.path!);
            _profilePicName = pickedFile!.path!.split('/').last;
          });
        }
      } catch (error) {
        print(error);
      }
    }
  }

  Future<String> verify(String text) async {
    String prompt = "im going to give you some text, i want you to  check if the college name"
        "mentioned is a valid one or not... it may be not properly"
        "given so preprocess it a bit...if it is valid just say yes or no."
        " dont say anything else"+text;
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
        print(R);
        print("===============");
      } else {
        print('Failed to verify. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error sending request: $error');
    }
    return "";
  }

  void documentVerify() async {
    final status = await Permission.storage.request();
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
  }

  Future<void> _createAccount() async {
    String email = emailController.text;
    String username = usernameController.text;
    String password = passwordController.text;
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
      final userData = {
        'username': username,
        'profilepic': _profilePicName,
        'type': _userType,
      };
      await userDoc.set(userData);

      if (_idFile != null && _userType == 'contributor') {
        String scanned = "";
        final inputimage = ml.InputImage.fromFilePath(pickedFile!.path!);
        final textDetector = ml.GoogleMlKit.vision.textRecognizer();
        ml.RecognizedText recognizedText =
        await textDetector.processImage(inputimage);
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
        if (verified == "yes") {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          final userDoc = FirebaseFirestore.instance.collection('users').doc(email);
          final userData = {
            'username': username,
            'profilepic': _profilePicName,
            'type': _userType,
          };
          await userDoc.set(userData);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => home()),
          );
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => home()),
      );
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
        backgroundColor: Colors.blue,
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
                  visible: _idFile == null,
                  child: Text(
                    'Upload ID from your registered College/University',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                SizedBox(height: 10),
                Visibility(
                  visible: _idFile == null,
                  child: ElevatedButton(
                    onPressed: documentVerify,
                    child: Text('Upload Document'),
                  ),
                ),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAccount,
                child: Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class home extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text('App Home'),
        ),
      ),
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
        ],
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor: Colors.blue,
        onTap: (int index) {
          switch(index) {
            case 0:
            // Add logic to navigate to the home page
              break;
            case 1:
            // Add logic to navigate to the storage page
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Uploader()),
              );
              break;
            case 3:
            // Add logic to navigate to the profile page
              break;
          }
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return Center(
      child: Text(
        'Home Page Content',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}
