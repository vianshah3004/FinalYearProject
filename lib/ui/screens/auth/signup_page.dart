import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/firebase_options.dart';
import 'email_verification.dart';
import 'login_page.dart';
import '../profile/user_details.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool _isMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final RegExp regex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return regex.hasMatch(email);
  }

  Future<void> _createUserProfile(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
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
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();
        await _createUserProfile(user);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-up successful! Please verify your email.')),
      );

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
      } else if (e.code == 'weak-password') {
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

  Widget _buildTextField(
      TextEditingController controller,
      String hintText,
      IconData icon, {
        bool obscureText = false,
        TextInputType keyboardType = TextInputType.text,
        Function(String)? onChanged,
      }) {

    // Get screen size for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    bool isPasswordField = hintText.toLowerCase().contains("password");
    bool isEmailField = hintText.toLowerCase().contains("email");

    return TextFormField(
      controller: controller,
      obscureText: isPasswordField
          ? (hintText == 'Password' ? _obscurePassword : _obscureConfirmPassword)
          : false,
      obscuringCharacter: '●',
      keyboardType: isEmailField ? TextInputType.emailAddress : TextInputType.text,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: hintText,
        labelStyle: TextStyle(
          color: Colors.black,
          fontSize: isTablet ? 18 : 16,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.black,
          size: isTablet ? 28 : 24,
        ),
        filled: true,
        fillColor: Colors.white,
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
        contentPadding: EdgeInsets.symmetric(
          vertical: isTablet ? 20 : 15,
          horizontal: isTablet ? 25 : 20,
        ),
        suffixIcon: isPasswordField
            ? IconButton(
          icon: Icon(
            hintText == 'Password'
                ? (_obscurePassword ? Icons.visibility_off : Icons.visibility)
                : (_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
            color: Colors.black54,
            size: isTablet ? 28 : 24,
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
            : null,
      ),
      style: TextStyle(
        fontSize: isTablet ? 18 : 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPasswordStrength() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.width < 360;

    return Padding(
      padding: const EdgeInsets.only(top: 1.0),
      child: isSmallScreen
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStrengthIndicator("Min 8 Characters", _isMinLength),
          _buildStrengthIndicator("Min 1 Uppercase letter", _hasUpperCase),
          _buildStrengthIndicator("Min 1 Lowercase letter", _hasLowerCase),
          _buildStrengthIndicator("Min 1 Number", _hasNumber),
          _buildStrengthIndicator("Min 1 Special Symbol", _hasSpecialChar),
        ],
      )
          : Row(
        children: [
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
          SizedBox(width: isTablet ? 10 : 5),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -10),
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

  Widget _buildStrengthIndicator(String text, bool isValid) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.width < 360;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? Colors.green : Colors.red,
            size: isTablet ? 22 : (isSmallScreen ? 16 : 18),
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: isValid ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: isTablet ? 16 : (isSmallScreen ? 12 : 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;
    final isTablet = screenWidth > 600;
    final isSmallScreen = screenWidth < 360;

    // Responsive values
    final horizontalPadding = isTablet ? 60.0 : (isSmallScreen ? 20.0 : 29.0);
    final imageWidth = isTablet ? 400.0 : (isSmallScreen ? 280.0 : 350.0);
    final imageHeight = isTablet ? 380.0 : (isSmallScreen ? 280.0 : 340.0);
    final topContainerHeight = isTablet ? 320.0 : (isSmallScreen ? 240.0 : 280.0);
    final titleFontSize = isTablet ? 32.0 : (isSmallScreen ? 24.0 : 28.0);
    final subtitleFontSize = isTablet ? 18.0 : (isSmallScreen ? 14.0 : 16.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenHeight,
          ),
          child: Stack(
            children: [
              // Background container (black card)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: topContainerHeight,
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
                top: 0,
                left: 1,
                right: 0,
                child: Center(
                  child: Image.asset(
                    "assets/images/signup.png",
                    width: imageWidth,
                    height: imageHeight,
                  ),
                ),
              ),

              // Content below the image
              Column(
                children: [
                  SizedBox(height: isTablet ? 60 : 42),
                  SizedBox(height: isTablet ? 320 : (isSmallScreen ? 240 : 290)),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      children: [
                        Text(
                          'Create an Account',
                          style: GoogleFonts.poppins(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isTablet ? 15 : 10),
                        Text(
                          'Sign up to get started!',
                          style: GoogleFonts.poppins(
                            fontSize: subtitleFontSize,
                            color: Colors.black54,
                          ),
                        ),
                        SizedBox(height: isTablet ? 40 : 30),

                        _buildTextField(_emailController, 'Email', Icons.email),
                        SizedBox(height: isTablet ? 25 : 20),
                        _buildTextField(
                          _passwordController,
                          'Password',
                          Icons.lock,
                          onChanged: _validatePassword,
                          obscureText: true,
                        ),
                        SizedBox(height: isTablet ? 25 : 20),
                        _buildTextField(
                          _confirmPasswordController,
                          'Confirm Password',
                          Icons.lock,
                          obscureText: true,
                        ),
                        SizedBox(height: isTablet ? 35 : 30),
                        _buildPasswordStrength(),
                        SizedBox(height: isTablet ? 40 : 34),

                        _isLoading
                            ? CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: isTablet ? 4 : 2,
                        )
                            : SizedBox(
                          width: isTablet ? 300 : double.infinity,
                          child: ElevatedButton(
                            onPressed: _onSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 100.0 : 80.0,
                                vertical: isTablet ? 20.0 : 17.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_add_alt_outlined,
                                  color: Colors.white,
                                  size: isTablet ? 24 : 20,
                                ),
                                SizedBox(width: isTablet ? 12 : 8),
                                Text(
                                  'Sign Up',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: isTablet ? 18 : 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 30 : 20),

                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Colors.black26,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 12.0 : 8.0,
                              ),
                              child: Text(
                                'OR',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Colors.black26,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 30 : 20),

                        SizedBox(
                          width: isTablet ? 350 : double.infinity,
                          child: ElevatedButton(
                            onPressed: _onGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 40.0 : 30.0,
                                vertical: isTablet ? 18.0 : 15.0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/icons/google_icon.png',
                                  width: isTablet ? 28 : 24,
                                  height: isTablet ? 28 : 24,
                                ),
                                SizedBox(width: isTablet ? 15 : 10),
                                Text(
                                  'Sign Up with Google',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: isTablet ? 16 : 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 20 : 10),

                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 16 : 15,
                                color: Colors.black54,
                              ),
                            ),
                            SizedBox(width: isTablet ? 8 : 4),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      var opacityTween = Tween(begin: 0.0, end: 1.0).animate(animation);
                                      return FadeTransition(opacity: opacityTween, child: child);
                                    },
                                  ),
                                );
                              },
                              child: Text(
                                'Login',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 16 : 15,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isTablet ? 40 : 20),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}