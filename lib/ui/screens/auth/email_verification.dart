import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../profile/user_details.dart';


class EmailVerificationScreen extends StatefulWidget {
  final User user;

  const EmailVerificationScreen({super.key, required this.user});

  @override
  _EmailVerificationScreenState createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late User user;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    checkEmailVerified();
  }

  Future<void> checkEmailVerified() async {
    int counter = 0;
    while (counter < 10) {
      await user.reload();
      user = FirebaseAuth.instance.currentUser!;
      if (user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => EmailVerifiedScreen(user: user)),
        );
        return;
      }
      await Future.delayed(const Duration(seconds: 3));
      counter++;
    }

    // If email not verified, still navigate to UserDetailsPage
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => UserDetailsPage(user: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please Verify Your Email',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'We have sent a verification link to your email.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.black),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerifiedScreen extends StatefulWidget {
  final User user;

  const EmailVerifiedScreen({super.key, required this.user});

  @override
  _EmailVerifiedScreenState createState() => _EmailVerifiedScreenState();
}

class _EmailVerifiedScreenState extends State<EmailVerifiedScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => UserDetailsPage(user: widget.user)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 100, color: Colors.green),
            const SizedBox(height: 20),
            Text(
              "Email Verified Successfully!",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Redirecting...",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
