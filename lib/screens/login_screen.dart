import 'package:chat_app/models/user_chat.dart';
import 'package:chat_app/screens/home_screen.dart';
import 'package:chat_app/widgets/loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';



class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  SharedPreferences? prefs;
  bool isLoading = false;
  bool isLoggedIn = false;
  User? currentUser;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }
  void isSignedIn() async
  {
    // CircularProgressIndicator will pop up
    isLoading = true;
    // initialize sharedPreferences
    prefs = await SharedPreferences.getInstance();
    // check if user already login
    isLoggedIn = await googleSignIn.isSignedIn();
    if (isLoggedIn && prefs?.getString('id') != null){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>HomeScreen(currentUserId: prefs?.getString('id'),)));
    }

    setState(() {
      isLoading = false;
    });


  }

  // handle signIn
  //then we’ll check if the user is new or not (by query to the server does this ID exist).
  // If they’re a new user, write it to the database.
  Future<Null> handleSignIn() async {
    prefs = await SharedPreferences.getInstance();
    this.setState(() {
      isLoading = true;
    });
    GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if(googleUser != null){
      GoogleSignInAuthentication? googleAUth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(accessToken: googleAUth.accessToken,idToken: googleAUth.idToken);
      User? firebaseUser = (await firebaseAuth.signInWithCredential(credential)).user;

      if(firebaseUser != null){
        // check if aleready sign up
        final QuerySnapshot result = await FirebaseFirestore.instance.collection('users').where('id',isEqualTo: firebaseUser.uid).get();
        final List<DocumentSnapshot> documents = result.docs;
        // it's mean user doesn't exist
        if(documents.length == 0) {
          FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
            'nickname':firebaseUser.displayName,
            'photoUrl':firebaseUser.photoURL,
            'id': firebaseUser.uid,
            'createAt': DateTime.now().millisecondsSinceEpoch.toString(),
            'chattingWith':null

          });
          // write data to local
          currentUser = firebaseUser;
          await prefs?.setString('id', currentUser!.uid);
          await prefs?.setString('nickname', currentUser!.displayName ?? "");
          await prefs?.setString('photoUrl', currentUser!.photoURL ?? "");

        }
        // user already exist in db
        else{
          DocumentSnapshot documentSnapshot = documents[0];
          UserChat userChat = UserChat.fromDocument(documentSnapshot);
          await prefs?.setString('id', userChat.id);
          await prefs?.setString('nickname', userChat.nickname);
          await prefs?.setString('photoUrl', userChat.photoUrl);
          await prefs?.setString('aboutMe', userChat.aboutMe);
          print('photoUrl ${userChat.photoUrl}');
          print('nickname ${userChat.nickname}');
          print('aboutMe ${userChat.aboutMe}');
        }
        Fluttertoast.showToast(msg: "Sign in success");
        this.setState(() {
          isLoading = false;
        });
        Navigator.push(context, MaterialPageRoute(builder: (context) => HomeScreen(currentUserId: firebaseUser.uid)));
      }
      else {
        Fluttertoast.showToast(msg: "Sign in fail");
        this.setState(() {
          isLoading = false;
        });
      }

    }
    else {
      Fluttertoast.showToast(msg: "Can not init google sign in");
      this.setState(() {
        isLoading = false;
      });
    }

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign In Screen"),
      ),
      body: Stack(
        children: [
          Center(
            child:TextButton(
              onPressed: () => handleSignIn().catchError((err) {
                Fluttertoast.showToast(msg: err.toString());
                this.setState(() {
                  isLoading = false;
                });
              }),
              child: Text(
                'SIGN IN WITH GOOGLE',
                style: TextStyle(fontSize: 16.0, color: Colors.white),
              ),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Color(0xffdd4b39)),
                  padding: MaterialStateProperty.all<EdgeInsets>(EdgeInsets.fromLTRB(30.0, 15.0, 30.0, 15.0))),
            ),
          ),
          Positioned(
            child: isLoading ? const Loading() : Container(),
          ),
        ],
      ),
    );
  }
}
