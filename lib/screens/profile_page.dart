import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_ui/screens/map_google.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'contact_us.dart';
import 'package:flutter/services.dart';
import 'license_agreement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'change_password.dart';
import 'change_user_details.dart';
import 'NotificationsPage.dart';
import 'EnableBiometricPage.dart';
import 'about_us.dart';
import 'package:flutter_emoji_feedback/flutter_emoji_feedback.dart';
import 'ChangeEmailPage.dart';
import 'MapPage.dart';
import 'package:new_ui/localized_text_widget.dart';
import 'language_selection_page.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedIconIndex = 3;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final String _imageKey = "profile_image";
  String firstName = '';
  String lastName = '';
  String? providerId;


  void _navigateToEditProfile() async {
    bool? updated = await Navigator.push<bool>(
      context,
      _fadeRoute(EditProfilePage()), // Using fade transition
    );

    if (updated == true) {
      _fetchUserData();
    }
  }


  void _onItemTapped(int index) {
    setState(() {
      _selectedIconIndex = index;
    });

    // Navigate to the appropriate page with fade transition
    if (index == 0) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    }
    else if (index == 1) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    }
    else if (index == 2) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WalletTab(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    }

  }

  @override
  void initState() {
    super.initState();
    _loadProfileImage(); // Load saved profile image on startup
    _fetchUserData();

  }

  /// Pick an image from the gallery
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      await _saveProfileImage(pickedFile.path);
    }
  }

  Future<void> _fetchUserData() async {
    try {
      // Assuming the user is logged in and you have the user UID
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        setState(() {
          firstName = userData['firstName'] ?? ' Name';
          lastName = userData['lastName'] ?? ' Name';
          providerId = user.providerData.isNotEmpty
              ? user.providerData[0].providerId
              : null;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _openGoogleSecurity() async {
    const url = "https://myaccount.google.com/security";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      print("Could not launch $url");
    }
  }


  void _signOutUser(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),
            Center(
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      "Please wait while we log you out...",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      try {
        // Store sign-out time in Firestore
        await FirebaseFirestore.instance.collection("users").doc(uid).update({
          "sign_out_time": FieldValue.serverTimestamp(),
        });

        // Sign out the user
        await FirebaseAuth.instance.signOut();

        // Wait for 3 seconds, then navigate to LoginScreen
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()), // Your login page
          );
        });
      } catch (e) {
        print("Error during sign out: $e");
      }
    }
  }


  /// Save profile image path
  Future<void> _saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_imageKey, path);
  }

  /// Load profile image path
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString(_imageKey);

    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Stack(
          children: [
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
            Column(
              children: [
                const SizedBox(height: 47),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: Row(
                    children: [
                      const SizedBox(width: 0),
                      LocalizedText(
                        text: "Settings",
                        style: GoogleFonts.poppins(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 37),

                // Profile Picture
                GestureDetector(
                  onTap: () {
                    if (_profileImage != null && _profileImage!.existsSync()) {
                      _showFullScreenImage(context, _profileImage!);
                    } else {
                      _showFullScreenImage(context, null); // Pass null and handle default image inside the function
                    }

                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.purpleAccent, Colors.blueAccent, Colors.cyanAccent],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                        padding: EdgeInsets.all(4), // Border thickness
                        child: CircleAvatar(
                          radius: 80,
                          backgroundColor: Colors.white, // Background color for inner circle
                          child: CircleAvatar(
                            radius: 76, // Slightly smaller to fit inside the border
                            backgroundImage: _profileImage != null && _profileImage!.existsSync()
                                ? FileImage(_profileImage!)
                                : const AssetImage("assets/images/blank.jpeg") as ImageProvider,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 5,
                        right: 5,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black, // Border color
                                width: 2.5, // Border width
                              ),
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 17,
                              child: Icon(Icons.edit, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  "$firstName $lastName",
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 46),

                // Cards
                _buildSection("General", [
                  _buildCard("Edit Profile", Icons.edit, Colors.lightBlueAccent.shade100, ()
                  {
                    Navigator.push(context, _fadeRoute(EditProfilePage()));
                  }),
                  _buildCard("Change Password", Icons.password, Colors.lightGreen.shade300, () {
                    if (providerId == 'google.com') {
                      _openGoogleSecurity();
                    } else {
                      Navigator.push(context, _fadeRoute(ChangePasswordScreen()));
                    }
                  }),
                  _buildCard("Change Email", Icons.email, Colors.orange.shade300, () {
                     Navigator.push(context, _fadeRoute(ChangeEmailPage()));
                  }),
                  const SizedBox(height: 10),
                ]),
                const SizedBox(height: 30),
                // Preferences Section
                _buildSection("Preferences", [
                  _buildCard("Enable Biometric", Icons.fingerprint, Colors.purple.shade300, () {
                    Navigator.push(context, _fadeRoute(EnableBiometricPage()));
                  }),
                  _buildCard("Notifications", Icons.notifications, Colors.red.shade300, () {
                    Navigator.push(context, _fadeRoute(NotificationsPage()));
                  }),
                  _buildCard("Change Language", Icons.language, Colors.purple.shade300, () {
                    Navigator.push(context, _fadeRoute(LanguageSelectionPage()));
                  }),
                  const SizedBox(height: 10),
                ]),
                const SizedBox(height: 30),
                // More Section
                _buildSection("More", [
                  _buildCard("About", Icons.info, Colors.blue.shade300, () {
                    Navigator.push(context, _fadeRoute(AboutUsPage()));
                  }),
                  _buildCard("Send Feedback", Icons.feedback, Colors.amber.shade300, () {
                    showDialog(context: context, builder: (_) => FeedbackPage());
                  }),
                  _buildCard("License & Agreement", Icons.description_outlined, Colors.indigo.shade500, () {
                    Navigator.push(context, _fadeRoute(LicenseAndAgreementPage()));
                  }),
                  _buildCard("Customer Support", Icons.support_agent, Colors.teal.shade300, () {
                    Navigator.push(context, _fadeRoute(ContactPage()));
                  }),

                  const SizedBox(height: 10),
                ]),
                const SizedBox(height: 50),

                // Sign Out
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 110, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                  color: Colors.grey[100],
                  child: ListTile(
                    leading: const Icon(Icons.exit_to_app, color: Colors.black54, size: 22),
                    title: LocalizedText(
                      text: 'Sign Out',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[400],
                      ),
                    ),
                    onTap: () => _signOutUser(context), // Calls the sign-out function
                  ),
                ),
              ],
            ),
          ],
        ),

      ),

      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black, // Background color of the bottom nav bar
          borderRadius: BorderRadius.circular(30), // Rounded edges
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent, // Prevents the unwanted white background
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed, // Ensures no shifting mode
            backgroundColor: Colors.transparent, // Prevents extra white box
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            showSelectedLabels: true,
            showUnselectedLabels: false,
            currentIndex: _selectedIconIndex,
            onTap: _onItemTapped,
            elevation: 0, // Removes extra shadows that may cause white areas
            items: [
              _buildNavItem(Icons.electric_car, Icons.electric_car_outlined, "Dashboard", 0),
              _buildNavItem(Icons.map, Icons.map_outlined, "Map", 1),
              _buildNavItem(Icons.account_balance_wallet, Icons.account_balance_wallet_outlined, "Wallet", 2),
              _buildNavItem(Icons.settings, Icons.settings_outlined, "Settings", 3),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData filledIcon,
      IconData outlinedIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: _selectedIconIndex == index
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        child: Icon(filledIcon, color: Colors.white),
      )
          : Icon(outlinedIcon,color: Colors.white),
      label: label,
    );
  }

  // Build Card for various options
  Widget _buildCard(String title, IconData icon, Color iconColor, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.grey[100],
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: LocalizedText(
            text:title, style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
        onTap: onTap, // Now accepts a function instead of a widget
      ),
    );
  }


  Widget _buildSection(String sectionTitle, List<Widget> options) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 12,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: LocalizedText(
                text:
                sectionTitle,
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            Column(children: options),
          ],
        ),
      ),
    );
  }

  // Fade Transition
  PageRouteBuilder<bool> _fadeRoute(Widget page) {
    return PageRouteBuilder<bool>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }


  void _showFullScreenImage(BuildContext context, File? profileImage) {
    if (_profileImage == null || !_profileImage!.existsSync()) {
      // If no profile image is available, show the default image
      _profileImage = File("assets/images/blank.jpeg");
    }

    showDialog(
      context: context,
      barrierDismissible: true, // Allows dismissal by tapping outside
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent, // Removes the dialog background
        child: FadeTransition(
          opacity: _fadeAnimation(context), // Apply the fade animation
          child: Stack(
            children: [
              // Background blur
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(); // Dismiss the dialog when tapping outside
                  },
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      color: Colors.black.withOpacity(0), // Transparent background
                    ),
                  ),
                ),
              ),
              // Fullscreen profile image
              Center(
                child: ClipOval(
                  child: Image.file(
                    _profileImage!,
                    width: 300, // Full width of the screen
                    height: 300, // Full height for a perfect circle
                    fit: BoxFit.cover, // Ensures the image fills the circle
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        "assets/images/blank.jpeg",
                        width: 300,
                        height: 300,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
             // print("HI"),
            ],
          ),
        ),
      ),
    );
  }


  // Fade animation controller
  Animation<double> _fadeAnimation(BuildContext context) {
    final animationController = AnimationController(
      duration: Duration(milliseconds: 0), // Transition duration
      vsync: Navigator.of(context),
    );

    final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(animationController);

    // Start the animation when the dialog is shown
    animationController.forward();

    return fadeAnimation;
  }

}

// Feedback Dialog

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({Key? key}) : super(key: key);

  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with SingleTickerProviderStateMixin {
  int? selectedRating;
  final TextEditingController _feedbackController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;
  bool _showWarning = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
    ]).animate(_controller);
  }

  void _shakeCard() {
    setState(() {
      _showWarning = true;
    });
    _controller.forward(from: 0);
    HapticFeedback.vibrate();
  }

  void _validateAndSubmit() async {
    if (selectedRating == null || _feedbackController.text.trim().length < 3) {
      _shakeCard();
    } else {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('users').doc(uid);

          await userDocRef.set({
            'feedback': {
              'rating': selectedRating, // Now storing as a number (0 to 4)
              'feedbackText': _feedbackController.text.trim(),
              'timestamp': FieldValue.serverTimestamp(),
            }
          }, SetOptions(merge: true));

          setState(() {
            _submitted = true;
          });

          Future.delayed(Duration(seconds: 5), () {
            Navigator.pop(context);
          });
        } catch (e) {
          print("Error saving feedback: $e");
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Redirect only when clicking on the blurred background
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/profile');
      },
      child: Stack(
          children: [
      // Blurred Background (Tappable)
      BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(color: Colors.black.withOpacity(0.3)),
    ),

    // Feedback Card (Non-Tappable)
    Center(
      child: GestureDetector(
        onTap: () {
    // Do nothing when clicking on the card
        },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
        return Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      );
    },
    child: Dialog(
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(
      color: _showWarning ? Colors.red : Colors.transparent,
      width: 2,
      ),
    ),
    backgroundColor: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: _submitted
      ? Column(
      mainAxisSize: MainAxisSize.min,
      children: [
      Text("😊", style: TextStyle(fontSize: 80)),
      SizedBox(height: 10),
      Text(
        "Thank you for your feedback!",
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
        fontSize: 18, fontWeight: FontWeight.bold),
      ),
    SizedBox(height: 20),
    Text(
      "We really appreciate you helping to improve the Toll Seva experience.",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
      fontSize: 15, color: Colors.black54),
    ),
    SizedBox(height: 25),
    ElevatedButton(
      style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      padding: EdgeInsets.symmetric(
      vertical: 12, horizontal: 30),
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22)),
    ),
    onPressed: () {
      Navigator.pop(context);
    },
    child: Text("Close",
    style: GoogleFonts.poppins(
    fontSize: 16, color: Colors.white)),
      ),
      ],
    )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Give Feedback",
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.black54),
                            onPressed: () {
                              Navigator.pop(context);
                              Future.delayed(Duration(milliseconds: 0), () {
                                Navigator.pushReplacementNamed(context, '/profile');
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Text(
                        "How do you feel about the Toll Seva experience?",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black54),
                      ),
                      SizedBox(height: 12),

                      /// **🚀 Animated Emoji Feedback (NEW)**
                      EmojiFeedback(
                        elementSize: 53,
                        onChanged: (value) {
                          setState(() {
                            selectedRating = value;
                            _showWarning = false;
                          });
                        },
                      ),


                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "What are the reasons for your rating?",
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SizedBox(height: 7),
                      TextField(
                        controller: _feedbackController,
                        maxLines: 2,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        cursorColor: Colors.black, // Black cursor
                        onChanged: (value) {
                          setState(() {
                            _showWarning = false;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: "Reason for your rating",
                          hintStyle: TextStyle(fontSize: 15, color: Colors.grey[700]),
                          prefixIcon: Icon(Icons.comment, color: Colors.grey, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.black), // Black border when focused
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                      ),
                      if (_showWarning)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red, size: 15),
                              SizedBox(width: 9),
                              Text(
                                "Please select a rating and provide feedback!",
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: _validateAndSubmit,
                        child: Text("Submit", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ),
        ],
      ),
    );
  }
}
