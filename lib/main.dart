import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:flutter_animate/flutter_animate.dart';
// import 'screens/notification_panel.dart';
// import 'screens/profile_page.dart';
// import 'screens/wallet_screen.dart';
import 'screens/home_screen.dart';
//import 'screens/terms_conditions.dart';
import 'screens/login_page.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'screens/razor_payment.dart';
import 'screens/local_auth_verify.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'screens/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/backup_splash.dart';
import 'screens/map_google.dart';
import 'language_provider.dart';
import 'ml_translation_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final translationService = MLTranslationService();
    await translationService.initialize();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => WalletProvider()), // ✅ Add WalletProvider here
          ChangeNotifierProvider(create: (context) => NavigationProvider()),
          ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ],
        child: const EVTrackingApp(),
      ),
    );
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

class EVTrackingApp extends StatelessWidget {
  const EVTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AnimatedSwitcher(
        duration: Duration(milliseconds: 800), // Smooth fade duration
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child:AuthCheck(), // Handle redirection based on signOutTime
      ),
    );
  }
}

  class AuthCheck extends StatefulWidget {
  @override
  _AuthCheckState createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> with WidgetsBindingObserver {

  bool _authChecked = false;
  bool _isAuthenticating = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthStatus();
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _authChecked = false; // Reset so biometric runs when reopening
      _checkAuthStatus();
    }
  }

   // Prevent multiple calls

  bool _isAuthenticated = false; // Add this flag

  Future<void> _checkAuthStatus() async {
    if (_isAuthenticated) return;
    _isAuthenticated = true;

    try {
      LocalAuthHelper authHelper = LocalAuthHelper();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      await Future.delayed(const Duration(seconds: 1));

      var user = FirebaseAuth.instance.currentUser;
      print("🔍 Checking Auth Status...");
      print("👤 Current User: ${user?.uid}");

      if (user == null) {
        print("⚠️ No user found. Redirecting to Login Page.");
        _navigateTo(LoginPage());
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      print("📄 Firestore Document: ${userDoc.exists}");

      bool isAuthenticated = true;

      // Check if biometric is enabled before authenticating
      if (isBiometricEnabled) {
        isAuthenticated = await authHelper.authenticate();
      }

      if (isAuthenticated) {
        print("✅ Authentication successful! Navigating to HomeScreen.");
        _navigateTo(HomeScreen());
      } else {
        print("❌ Authentication failed. Exiting App...");
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Platform.isAndroid) {
            SystemNavigator.pop();
          } else if (Platform.isIOS) {
            exit(0);
          }
        });
      }
    } catch (e) {
      print("❌ Error in _checkAuthStatus: $e");
      _navigateTo(LoginPage());
    }
  }



  void _navigateTo(Widget page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Please Wait...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}