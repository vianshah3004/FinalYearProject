import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/localized_text_widget.dart';
import 'profile_page.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          _firstNameController.text = userDoc['firstName'] ?? '';
          _lastNameController.text = userDoc['lastName'] ?? '';
          _phoneController.text = userDoc['phone'] ?? '';
        });
      }
    }
  }

  Future<void> _updateProfileData() async {
    if (_formKey.currentState!.validate()) {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );

        await Future.delayed(const Duration(seconds: 2));

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ProfileScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    }
  }

  String? _validatePhone(String? value) {
    final RegExp phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (value == null || value.isEmpty) {
      return "Phone number is required";
    } else if (!phoneRegex.hasMatch(value)) {
      return "Enter a valid 10-digit Indian phone number";
    }
    return null;
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
            Positioned(
              top: 40, // Adjust to control image position
              left: 1,
              right: 0,
              child: Center(
                child: Image.asset(
                  "assets/images/edit_profile.png",
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
                        text: "Edit Profile",
                        style: GoogleFonts.poppins(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 210),

                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header Above First Name
                        Center(
                          child: Column(
                            children: [
                              LocalizedText(
                                text: "Personal Information",
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 5),
                              LocalizedText(
                                text: "Review and update your personal details for accuracy and up to date.",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 60),

                        // First Name
                        TextFormField(
                          controller: _firstNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: "First Name",
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon:
                            const Icon(Icons.person, color: Colors.lightGreen),
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          validator: (value) =>
                          value!.isEmpty ? "Enter your first name" : null,
                        ),

                        const SizedBox(height: 25),

                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: "Last Name",
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon:
                            const Icon(Icons.person_outline, color: Colors.teal),
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          validator: (value) =>
                          value!.isEmpty ? "Enter your last name" : null,
                        ),

                        const SizedBox(height: 25),

                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Phone Number",
                            labelStyle: const TextStyle(color: Colors.black),
                            prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                            filled: true,
                            fillColor: Colors.grey[200],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          validator: _validatePhone,
                        ),

                        const SizedBox(height: 30),

                        // Save Button
                        Center(
                          child: ElevatedButton(
                            onPressed: _updateProfileData,
                            child: const LocalizedText(
                              text: "Save Changes"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
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
          ],
        ),
      ),
    );
  }
}
