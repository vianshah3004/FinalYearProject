import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../../../widgets/localized_text_widget.dart';
import '../auth/local_auth_verify.dart';
// Import biometric authentication helper

class ChangeEmailPage extends StatefulWidget {
  @override
  _ChangeEmailPageState createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthHelper _localAuthHelper = LocalAuthHelper();

  bool _isUpdating = false;
  bool _showPasswordField = false;

  /// **Function to update email after authentication**
  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    User? user = _auth.currentUser;
    if (user == null) {
      _showError("User not found. Please sign in again.");
      setState(() => _isUpdating = false);
      return;
    }

    try {
      // **Step 1: Biometric Authentication**
      print("🔍 Starting biometric authentication...");
      bool isAuthenticated = await _localAuthHelper.authenticate2();
      print("✅ Biometric authentication: $isAuthenticated");
      if (!isAuthenticated) {
        _showError("Biometric authentication failed!");
        setState(() => _isUpdating = false);
        return;
      }

      // **Step 2: Re-authenticate User**
      print("🔍 Checking re-authentication method...");
      String email = user.email ?? "";
      if (_showPasswordField) {
        print("🔐 Re-authenticating with password...");
        String password = _passwordController.text.trim();
        AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(credential);
        print("✅ Re-authentication (Password) successful!");
      } else {
        print("🔐 Re-authenticating with Google...");
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        await user.reauthenticateWithProvider(googleProvider);
        print("✅ Re-authentication (Google) successful!");
      }

      // **Step 3: Update Email in Firebase**
      String newEmail = _emailController.text.trim();
      print("📧 Updating email in Firebase Auth to: $newEmail...");
      await user.updateEmail(newEmail);
      print("✅ Email updated in Firebase Auth!");

      // **Step 4: Update Email in Firestore**
      print("📁 Updating email in Firestore...");
      await _firestore.collection('users').doc(user.uid).update({
        'email': newEmail,
      });
      print("✅ Email updated in Firestore!");

      // **Step 5: Success Message & Redirect**
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText(
            text:"Email updated successfully!")),
      );

      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        setState(() {
          _showPasswordField = true;
        });
        _showError("Re-authentication required! Enter your password.");
      } else {
        _showError(e.message ?? "Email update failed!");
      }
    } catch (e) {
      print("❌ Error: $e");
      _showError("An error occurred. Please try again.");
    } finally {
      print("🔄 Resetting _isUpdating state...");
      setState(() => _isUpdating = false);
    }
  }

  /// **Function to show error messages**
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:LocalizedText(
          text:message, style: const TextStyle(color: Colors.red))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
            // **Header**
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 250,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40, // Adjust to control image position
              left: 1,
              right: 0,
              child: Center(
                child: Image.asset(
                  "assets/images/change_email.png",
                  width: 300, // Adjust dynamically
                  height: 300,
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 0),
                      LocalizedText(
                        text: "Change Email",
                        style: GoogleFonts.poppins(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 250),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // **Header with Icon**
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.email_outlined, size: 40, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            LocalizedText(
                              text: "Update Your Email",
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // **Description**
                        LocalizedText(
                          text: "Ensure your email is up-to-date so you don't miss any important notifications.",
                          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 25),

                        // **Email Field**
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: "New Email",
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon: const Icon(Icons.email, color: Colors.blue),
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Enter your new email";
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                                .hasMatch(value)) {
                              return "Enter a valid email address";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // **Password Field (for re-authentication)**
                        if (_showPasswordField)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: "Confirm Password",
                              labelStyle: const TextStyle(color: Colors.black),
                              prefixIcon: const Icon(Icons.lock, color: Colors.red),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password is required for re-authentication";
                              }
                              return null;
                            },
                          ),

                        const SizedBox(height: 30),

                        // **Save Button (Centered)**
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isUpdating ? null : _updateEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle, color: Colors.white),
                            label: _isUpdating
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const LocalizedText(
                                text:"Save Changes"),
                          ),
                        ),
                      ],
                    ),
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
