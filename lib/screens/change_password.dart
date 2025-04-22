import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../localized_text_widget.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  bool _isLoading = false;

  final Map<String, bool> _isObscure = {
    "current": true,
    "new": true,
    "confirm": true,
  };

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePassword() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage("Passwords do not match!");
      return;
    }

    if (!(_isMinLength && _hasUpperCase && _hasLowerCase && _hasNumber && _hasSpecialChar)) {
      _showMessage("Password does not meet all requirements!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      FirebaseAuth auth = FirebaseAuth.instance;
      User? user = auth.currentUser;

      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_passwordController.text);

        _showMessage("Password changed successfully!");

        // Small delay before navigating back
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SingleChildScrollView(
        child: Stack(
          children: [
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
            Positioned(
              top: 40,
              left: 0,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 0),
                  LocalizedText(
                    text: "Change Password",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  "assets/images/change_password.png",
                  width: 300,
                  height: 280,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(top: 320),
              child: Column(
                children: [
                  LocalizedText(
                    text: "Keep Your Account Secure", // Bold heading
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 5),
                  LocalizedText(
                    text:  "Ensure your new password is strong and secure.", // Gray description
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      color: Colors.grey,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 29.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        _buildTextField(
                          _currentPasswordController,
                          "Current Password",
                          Icons.lock_outline,
                          "current",
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          _passwordController,
                          "New Password",
                          Icons.lock,
                          "new",
                          onChanged: _validatePassword,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          _confirmPasswordController,
                          "Confirm Password",
                          Icons.lock,
                          "confirm",
                        ),
                        _buildPasswordStrength(),
                        const SizedBox(height: 30),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 45.0, vertical: 17.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: LocalizedText(
                            text:
                            "Update Password",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hintText,
      IconData icon,
      String fieldKey,
      {Function(String)? onChanged}
      ) {
    return TextField(
      controller: controller,
      obscureText: _isObscure[fieldKey]!, // Use only this once
      obscuringCharacter: "●", // Larger custom dot
      onChanged: onChanged,
      style: TextStyle(fontSize: 18), // Bigger text size
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.black),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscure[fieldKey]! ? Icons.visibility_off : Icons.visibility,
            color: Colors.black,
          ),
          onPressed: () {
            setState(() {
              _isObscure[fieldKey] = !_isObscure[fieldKey]!;
            });
          },
        ),
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
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }


  Widget _buildPasswordStrength() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStrengthIndicator("At least 8 characters", _isMinLength),
                _buildStrengthIndicator("At least one uppercase letter", _hasUpperCase),
                _buildStrengthIndicator("At least one lowercase letter", _hasLowerCase),
                _buildStrengthIndicator("At least one number", _hasNumber),
                _buildStrengthIndicator("At least one special character", _hasSpecialChar),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator(String text, bool condition) {
    return Row(
      children: [
        Icon(
          condition ? Icons.check_circle : Icons.cancel,
          color: condition ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        LocalizedText(
          text: text,
          style: TextStyle(color: condition ? Colors.green : Colors.red),
        ),
      ],
    );
  }
}
