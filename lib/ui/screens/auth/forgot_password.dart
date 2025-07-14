import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ForgotPasswordPageState createState() => ForgotPasswordPageState();
}

class ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email address!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Try sending the password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage('A password reset link has been sent to your inbox.');
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}'); // Debugging
      if (e.code == 'invalid-email') {
        _showMessage('Invalid email address.');
      } else if (e.code == 'user-not-found') {
        _showMessage('If the email exists, a password reset link has been sent.');
      } else {
        _showMessage('Error: ${e.message}');
      }
    } catch (e) {
      print('Unexpected Error: $e'); // Debugging
      _showMessage('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String hintText, IconData icon, {bool obscureText = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.black),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade500),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
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
              "assets/images/password.png",
              width: 400, // Adjust dynamically
              height: 400,
            ),
          ),
        ),

        // Content below the image (white card with contact details)
        Column(
            children: [
            const SizedBox(height: 42),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Align items to the extreme left
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),

                    Text(
                      "Back",
                      style: GoogleFonts.poppins(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

        // Form contents (email, password, login, etc.)
        const SizedBox(height: 280),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0),
          child: Column(
            children: [
              Text(
                'Reset Your Password!',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter Your Mail Id to Reset your Password',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              _buildTextField(_emailController, 'Email', Icons.email),

              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  :ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Prevents extra spacing
                  children: [
                    const Icon(Icons.lock_reset_rounded, color: Colors.white,size: 22,), // Reset Icon
                    const SizedBox(width: 10), // Spacing between icon and text
                    const Text(
                      'Reset Password',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
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
