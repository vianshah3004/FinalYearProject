import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:new_ui/providers/language_provider.dart';
import 'package:new_ui/providers/wallet_provider.dart';
import 'package:new_ui/services/ml_translation_service.dart';
import 'package:new_ui/ui/screens/auth/login_page.dart';
import 'package:new_ui/ui/screens/auth/registration_page.dart';
import 'package:new_ui/ui/screens/home/home_screen.dart';
import 'package:new_ui/ui/screens/maps/map_google.dart';
import 'package:new_ui/ui/screens/profile/user_details.dart';

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:local_auth/local_auth.dart';
import 'dart:ui' as ui;

import 'core/firebase_options.dart'; // For blur effect


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
          ChangeNotifierProvider(create: (context) => WalletProvider()),
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
        child: AuthCheck(), // Handle redirection based on signOutTime
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
  bool _isAuthenticating = false; // Track authentication state for blur
  bool _isAuthenticated = false; // Prevent multiple calls
  final LocalAuthentication _auth = LocalAuthentication();

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
      _isAuthenticated = false; // Allow re-authentication
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    if (_isAuthenticated) return;
    _isAuthenticated = true;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isBiometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      await Future.delayed(const Duration(seconds: 1));

      var user = FirebaseAuth.instance.currentUser;
      print("🔍 Checking Auth Status...");
      print("👤 Current User: ${user?.uid}");

      if (user == null) {
        print("⚠️ No user found. Redirecting to Login Page.");
        _navigateTo(const LoginPage());
        return;
      }

      // Force a fresh fetch from Firestore to avoid caching issues
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(GetOptions(source: Source.server));

      print("📄 Firestore Document Exists: ${userDoc.exists}");
      if (userDoc.exists) {
        print("📄 Firestore Data: ${userDoc.data()}");
      }

      bool isAuthenticated = true;

      // Check if biometric is enabled before authenticating
      if (isBiometricEnabled) {
        setState(() {
          _isAuthenticating = true; // Show blur during authentication
        });
        isAuthenticated = await _authenticateUser();
        setState(() {
          _isAuthenticating = false; // Remove blur after authentication
        });
      }

      if (isAuthenticated) {
        // Check for user details if the document exists
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          // Check for required user details
          List<String> requiredFields = ['firstName', 'lastName', 'email', 'phone'];
          bool areDetailsMissing = false;

          for (String field in requiredFields) {
            bool isFieldMissing = !userData.containsKey(field) ||
                userData[field] == null ||
                (userData[field] is String && (userData[field] as String).trim().isEmpty);
            print("🔎 Checking field '$field': ${userData.containsKey(field) ? userData[field] : 'Not found'} - Missing: $isFieldMissing");
            if (isFieldMissing) {
              areDetailsMissing = true;
              break;
            }
          }

          if (areDetailsMissing) {
            print("⚠️ Required user details are missing. Redirecting to UserDetailsPage.");
            _navigateTo(UserDetailsPage(user: user));
            return;
          }

          // Check for vehicle details
          bool hasVehicleDetails = userData['vehicle']?['type'] == null || userData['vehicle']?['brand'] == null ||userData['vehicle']?['color'] == null ||userData['vehicle']?['model'] == null || userData['vehicle']?['numberPlate'] == null ||userData['vehicle']?['vin'] == null ;
          print("🚗 Vehicle Details Present: $hasVehicleDetails");

          if (hasVehicleDetails) {
            print("🚗 No vehicle details found. Redirecting to VehicleRegistrationPage.");
            _navigateTo(RegistrationPage());
            return;
          }

          // If both user and vehicle details are present, proceed to HomeScreen
          print("✅ Authentication successful! Navigating to HomeScreen.");
          _navigateTo(HomeScreen());
        } else {
          // If the document doesn't exist (new user), redirect to UserDetailsPage
          print("⚠️ User document does not exist. Redirecting to UserDetailsPage.");
          _navigateTo(UserDetailsPage(user: user));
        }
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
      setState(() {
        _isAuthenticating = false; // Remove blur on error
      });
      _navigateTo(const LoginPage());
    }
  }

  Future<bool> _authenticateUser() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isBiometricAvailable = await _auth.isDeviceSupported();

      return await _auth.authenticate(
        localizedReason: "Authenticate with your device PIN, password, or biometrics to access the app",
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow device PIN/password/pattern as fallback
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print("Authentication error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication failed')),
      );
      setState(() {
        _isAuthenticating = false; // Remove blur on error
      });
      return false;
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
      body: Stack(
        children: [
          // Main Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Center(
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

          // Blur Overlay during authentication
          if (_isAuthenticating)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.black.withOpacity(0.2), // Optional dark overlay
                ),
              ),
            ),
        ],
      ),
    );
  }
}
