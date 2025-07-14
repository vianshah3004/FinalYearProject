import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../../../core/firebase_options.dart';
import '../home/home_screen.dart';
import 'signup_page.dart'; // Import the SignUpPage
//import 'registration_page.dart';

import 'forgot_password.dart'; // Ensure this file exists for Firebase configurations
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const LoginPage());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Firebase initialization failed: $e'),
        ),
      ),
    ));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Store user data in Firestore
  Future<void> _storeUserData(User user) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      await userRef.set({
        'email': user.email,
        'uid': user.uid,
        'phone_number': user.phoneNumber ?? 'Not provided',
        'last_sign_in': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge instead of overwriting
    } catch (e) {
      _showMessage('Failed to store user data: $e');
    }
  }


  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user == null) {
        _showMessage('No user found for that email or email/password is wrong.');
        return;
      }

      // Store user data in Firestore
      await _storeUserData(user);

      // Check if email is verified


      // Navigate to the RegistrationPage after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        _showMessage('Invalid email or password.');
      } else {
        _showMessage('Login failed: ${e.message}');
      }
    } catch (e) {
      _showMessage('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _onGoogleSignIn() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Ensure previous session is cleared to force account selection
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User canceled sign-in

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase using the Google credential
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // User exists, proceed to home screen
          await _storeUserData(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else {
          // User not found in Firestore, show message
          _showMessage('This email is not registered. Please sign up first.');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignUpPage()),
          );
        }
      }
    } catch (e) {
      _showMessage('Google Sign-In failed: $e');
    }
  }





  // Store visibility state for each password field
  Map<TextEditingController, bool> _obscureTextState = {};

  Widget _buildTextField(
      TextEditingController controller, String labelText, IconData icon,
      {bool isPassword = false, TextInputType keyboardType = TextInputType.text}) {
    // Initialize obscureText state if not already set
    _obscureTextState.putIfAbsent(controller, () => isPassword);

    return StatefulBuilder(
      builder: (context, setState) {
        return TextFormField(
          controller: controller,
          obscureText: _obscureTextState[controller] ?? false, // Get current state
          obscuringCharacter: '●', // Larger bullet
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: const TextStyle(color: Colors.black),
            prefixIcon: Icon(icon, color: Colors.black), // Teal-colored icons
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black26, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                _obscureTextState[controller]! ? Icons.visibility_off : Icons.visibility,
                color: Colors.black54,
              ),
              onPressed: () {
                setState(() {
                  _obscureTextState[controller] = !_obscureTextState[controller]!;
                });
              },
            )
                : null, // Show eye icon only for password fields
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        );
      },
    );
  }



  @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F2F2),

        body: SingleChildScrollView(
          child: Stack(
            children: [
            // Background container (black card)
            Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // Image placed in the center between the black and white cards
          Positioned(
            top: 10, // Adjust to control image position
            left: 1,
            right: 0,
            child: Center(
              child: Image.asset(
                "assets/images/login.png",
                width: 400, // Adjust dynamically
                height: 400,
              ),
            ),
          ),

        // Content below the image (white card with contact details)
        Column(
            children: [
            const SizedBox(height: 42),

        // Form contents (email, password, login, etc.)
              const SizedBox(height: 280),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0),
          child: Column(
            children: [
              Text(
                'Welcome Back!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Login to your account',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: const TextStyle(color: Colors.black),
                    prefixIcon: const Icon(Icons.email, color: Colors.black),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,

                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                      const BorderSide(color: Colors.black, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black26, width: 1),
                    )
                ),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              _buildTextField(_passwordController, 'Password', Icons.lock, isPassword: true),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ForgotPasswordPage()),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 85.0, vertical: 17.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.login, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Login',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

                const SizedBox(height: 20),
                Row(
                  children:  [
                    Expanded(
                      child: Divider(
                        color: Colors.black26,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'OR',
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.black26,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _onGoogleSignIn,
                  icon: Container(
                    padding: const EdgeInsets.all(2.0),
                    decoration: const BoxDecoration(
                      color: Colors.white, // Background color of the circle
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/icons/google_icon.png', // Path to Google logo
                      height: 24,
                      width: 24,
                    ),
                  ),
                  label: Text(
                    'Log in with Google',
                    style: GoogleFonts.poppins(color: Colors.black,fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white54, // Button color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 15.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text('Don\'t have an account? ',
                        style: GoogleFonts.poppins(color: Colors.black54)),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const SignUpPage(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              var opacityTween = Tween(begin: 0.0, end: 1.0);
                              var opacityAnimation = animation.drive(opacityTween);

                              return FadeTransition(opacity: opacityAnimation, child: child);
                            },
                          ),
                        );
                      },
                      child:  Text(
                        'Sign Up!',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
            ],
        ),
          ],
        ),
      ),
    );
  }
}
