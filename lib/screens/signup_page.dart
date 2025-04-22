import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_ui/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:google_sign_in/google_sign_in.dart'; // Import Google Sign-In
import 'email_verification.dart'; // Import EmailVerificationScreen
import 'user_details.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const SignUpPage());
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

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  //final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  //final TextEditingController _mobileController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Firestore instance

  bool _isLoading = false;

  bool _isMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  void _validatePassword(String password) {
    setState(() {
      _isMinLength = password.length >= 7;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  @override
  void dispose() {
   // _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    //_mobileController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final RegExp regex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return regex.hasMatch(email);
  }

  Future<void> _createUserProfile(User user) async {
    try {
      // Create a new user document in Firestore
      await _firestore.collection('users').doc(user.uid).set({
        //'name': _nameController.text.trim(),
        'email': user.email,
        //'mobile': _mobileController.text.trim(),
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to store user data: $e')),
      );
    }
  }

  Future<void> _onSignUp() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the fields!')),
      );
      return;
    }

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email format!')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!')),
      );
      return;
    }



    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();

        // Store user data in Firestore
        await _createUserProfile(user);
      }


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up successful! Please verify your email.')),
      );

      // Redirect to EmailVerificationPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(user: user!),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred. Please try again!';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use!';

      }

      else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
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

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in canceled')),
        );
        return;
      }

      // Obtain the Google authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential using the obtained Google token
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with the credentials
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        if (!user.emailVerified) {
          // Optionally, send email verification if needed
          await user.sendEmailVerification();
        }

        // Store user data in Firestore
        await _createUserProfile(user);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-in successful!')),
        );

        // Navigate to another page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(user: user),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred. Please try again!';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'This Google account is linked to another provider!';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }


  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Widget _buildTextField(
      TextEditingController controller,
      String hintText,
      IconData icon, {
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        Function(String)? onChanged,
      }) {
    bool isPasswordField = hintText.toLowerCase().contains("password");
    bool isEmailField = hintText.toLowerCase().contains("email");

    return TextFormField(
      controller: controller,
      obscureText: isPasswordField
          ? (hintText == 'Password' ? _obscurePassword : _obscureConfirmPassword)
          : false,
      obscuringCharacter: '●', // Larger bullet size
      keyboardType: isEmailField ? TextInputType.emailAddress : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hintText, // Matches Last Name styling
        labelStyle: const TextStyle(color: Colors.black),
        prefixIcon: Icon(icon, color: Colors.black), // Teal icon like Last Name field
        filled: true,
        fillColor: Colors.white, // White background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black26, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        suffixIcon: isPasswordField
            ? IconButton(
          icon: Icon(
            hintText == 'Password'
                ? (_obscurePassword ? Icons.visibility_off : Icons.visibility)
                : (_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
            color: Colors.black54,
          ),
          onPressed: () {
            setState(() {
              if (hintText == 'Password') {
                _obscurePassword = !_obscurePassword;
              } else {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              }
            });
          },
        )
            : null, // Show eye icon only for password fields
      ),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }



// ✅ Password Strength UI with 3 conditions on left & 2 on right
  Widget _buildPasswordStrength() {
    return Padding(
      padding: const EdgeInsets.only(top: 1.0),
      child: Row(
        children: [
          // Left Side (First 3 conditions)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStrengthIndicator("Min 8 Characters", _isMinLength),
                _buildStrengthIndicator("Min 1 Uppercase letter", _hasUpperCase),
                _buildStrengthIndicator("Min 1 Lowercase letter", _hasLowerCase),
              ],
            ),
          ),
          const SizedBox(width: 5), // Spacing between columns
          // Right Side (Last 2 conditions)
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10), // Move it up slightly
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStrengthIndicator("Min 1 Number", _hasNumber),
                  _buildStrengthIndicator("Min 1 Special Symbol", _hasSpecialChar),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

// ✅ Strength Indicator Function
  Widget _buildStrengthIndicator(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.cancel,
          color: isValid ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: isValid ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
          top: 0, // Adjust to control image position
          left: 1,
          right: 0,
          child: Center(
            child: Image.asset(
              "assets/images/signup.png",
              width: 350, // Adjust dynamically
              height: 340,
            ),
          ),
        ),

        // Content below the image (white card with contact details)
        Column(
            children: [
            const SizedBox(height: 42),

        // Form contents (email, password, login, etc.)
        const SizedBox(height: 290),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0),
          child: Column(
            children: [
                Text(
                  'Create an Account',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Sign up to get started!',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 30),

                _buildTextField(_emailController, 'Email', Icons.email),
                const SizedBox(height: 20),
                _buildTextField(_passwordController, 'Password', Icons.lock, onChanged: _validatePassword,
                    obscureText: true),
                const SizedBox(height: 20),
                _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock,
                    obscureText: true), // Confirm Password Field
                const SizedBox(height: 30),
                _buildPasswordStrength(),
                const SizedBox(height: 34),
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : ElevatedButton(
                  onPressed: _onSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 80.0, vertical: 17.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Ensures the Row only takes up as much space as needed
                    children: [
                      Icon(
                        Icons.person_add_alt_outlined, // You can change the icon to something else if needed
                        color: Colors.white,
                      ),
                      SizedBox(width: 8), // Adds some space between the icon and the text
                      Text(
                        'Sign Up',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
                ElevatedButton(
                  onPressed: _onGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade300,

                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 15.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icons/google_icon.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 10),
                       Text(
                        'Sign Up with Google',
                        style: GoogleFonts.poppins(

                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 0),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Text(
                      'Already have an account?',
                      style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to Login Page
                      },
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>  LoginPage(),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                // Fade transition
                                var opacityTween = Tween(begin: 0.0, end: 1.0).animate(animation);
                                return FadeTransition(opacity: opacityTween, child: child);
                              },
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Adjust to your desired style
                          shadowColor: Colors.transparent, // Remove shadow if you don't want it
                          padding: EdgeInsets.zero, // Adjust padding if needed
                        ),
                        child: Text(
                          'Login',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
