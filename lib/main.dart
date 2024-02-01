import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: "AIzaSyB-nbsgPB9gWBSS6w8QIspXPYaONyoUy3Y",
        appId: "1:372358481738:android:b81694071e633af073e3b3",
        messagingSenderId: "372358481738",
        projectId: "educationapp-23878"),
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
class _LoginPageState extends State<LoginPage>{
  final TextEditingController user = TextEditingController();
  final TextEditingController pass = TextEditingController();
  bool _valid= false;

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
                    FirebaseAuth.instance.signInWithEmailAndPassword(email: mail, password: password).then(
                            (value) {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (context) => home()));

                    }).onError((error, stackTrace) {
                      setState(() {
                        print('KHATAM BYE BYE TATA GOODUBYE GAYA!');
                        _valid = true;
                      });

                    });
                    // Add your login logic here
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

class SignUpPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign Up'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: 350,
              child: TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: 350,
              child: TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String email = emailController.text;
                String username = usernameController.text;
                String password = passwordController.text;
                FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password).then((value){
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => home()));
                }
                );
              },
              child: Text('Create Account'),
            ),
          ],
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
    );

  }

}
