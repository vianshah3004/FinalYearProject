import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../../../widgets/localized_text_widget.dart';



class EnableBiometricPage extends StatefulWidget {
  @override
  _EnableBiometricPageState createState() => _EnableBiometricPageState();
}

class _EnableBiometricPageState extends State<EnableBiometricPage> {
  bool _isBiometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if the biometric preference exists
    if (!prefs.containsKey('biometric_enabled')) {
      await prefs.setBool('biometric_enabled', true); // Set it to true by default
    }

    setState(() {
      _isBiometricEnabled = prefs.getBool('biometric_enabled') ?? true; // Default to true
    });
  }


  Future<void> _toggleBiometric(bool value) async {
    bool isAuthenticated = await _authenticateUser();
    if (!isAuthenticated) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() {
      _isBiometricEnabled = value;
    });
  }

  Future<bool> _authenticateUser() async {
    try {
      return await _auth.authenticate(
        localizedReason: "Authenticate to enable biometrics",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: LocalizedText(
          text: "Enable Biometric",
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Soft Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFfdfbfb), Color(0xFFebedee)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6), // Glassmorphism Effect
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        _isBiometricEnabled ? Icons.fingerprint : Icons.lock_outline,
                        key: ValueKey<bool>(_isBiometricEnabled),
                        size: 90,
                        color: _isBiometricEnabled ? Colors.green : Colors.red.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    LocalizedText(
                      text: "Enable Biometric Authentication",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    LocalizedText(
                      text:  _isBiometricEnabled
                          ? "Your device will use biometric authentication for security."
                          : "Turn on biometric authentication for a faster and secure login.",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // Modern Green Toggle Button
                    GestureDetector(
                      onTap: () => _toggleBiometric(!_isBiometricEnabled),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 80,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: _isBiometricEnabled
                                ? [Colors.greenAccent, Colors.green.shade600]
                                : [Colors.red.shade100, Colors.red.shade400],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              alignment:
                              _isBiometricEnabled ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 35,
                                height: 35,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(scale: animation, child: child),
                                    child: Icon(
                                      _isBiometricEnabled ? Icons.check : Icons.cancel,
                                      key: ValueKey<bool>(_isBiometricEnabled),
                                      color: _isBiometricEnabled
                                          ? Colors.green.shade900
                                          : Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
