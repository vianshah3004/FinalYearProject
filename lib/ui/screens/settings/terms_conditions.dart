import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/localized_text_widget.dart';
import '../onboarding/introduction_1.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const TermsAndConditionsPage(),
    );
  }
}

class TermsAndConditionsPage extends StatefulWidget {
  const TermsAndConditionsPage({super.key});

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  bool isDarkMode = false;
  bool isChecked = false; // Checkbox state

  @override
  Widget build(BuildContext context) {
    isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:LocalizedText(
          text:  "    Terms & Conditions",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24,color: Colors.white),
        ),
        backgroundColor: Colors.transparent, // Set background to transparent
        elevation: 0, // Remove the shadow
        toolbarHeight: 50, // Adjust the toolbar height to reduce space
        titleSpacing: 0, // Remove spacing between title and back button
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Gradient Background
          Container(
            width: double.infinity,
            height: 300,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 0, 0, 0),Color.fromARGB(255, 0, 0, 0)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),

          // Positioned Image at the top, centered horizontally
          Positioned(
            top: 87, // Adjust top to position image correctly
            left: 20,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/terms.png', // Replace with your image path
                height: 200,
                width: 240,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Content Container under the gradient
          Padding(
            padding: const EdgeInsets.only(top: 280),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white : Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      LocalizedText(
                        text: "Before you create an account, please read and accept our Terms & Conditions",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 20),

                      LocalizedText(
                        text:  "📅 Last updated: 18 April 2025",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildSectionTitle("1. Introduction"),
                      _buildSectionContent(
                          "These Terms and Conditions govern the use of the Toll Seva . By using the App, users agree to comply with these terms."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("2. Conditions of use"),
                      _buildSectionContent(
                          "By using this app, you certify that you have read and reviewed this Agreement and that you agree to comply with its terms."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("3. User Eligibility"),
                      _buildSectionContent(
                          "The System is designed for registered vehicle owners with a valid account.Users must provide accurate vehicle and payment details."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("4. Privacy policy"),
                      _buildSectionContent(
                          "Before you continue using our app, we advise you to read our privacy policy regarding our user data collection."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("5. Intellectual property"),
                      _buildSectionContent(
                          "You agree that all materials, products, and services provided on this app are the property of Toll Seva."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("6. Toll Collection & Payment"),
                      _buildSectionContent(
                          "Tolls will be deducted automatically from the user’s linked digital wallet or bank account.Users must maintain a minimum balance of ₹2000 to avoid transaction failures.If the balance drops below ₹500, the user will receive a low-balance notification.Failure to maintain sufficient funds may result in penalties or legal action."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("7. Liability & Disclaimers"),
                      _buildSectionContent(
                          "The System relies on GPS accuracy and network connectivity; errors or delays in toll processing may occur.Users must ensure that their GPS device is functioning correctly to avoid incorrect toll charges.The System is not liable for incorrect deductions due to GPS errors, vehicle misclassification, or network failures."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("8. Account Suspension & Termination"),
                      _buildSectionContent(
                          "Accounts may be suspended for fraudulent activity, non-payment, or misuse of the System.Users may request account termination, but any pending tolls must be cleared."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("9. Modifications to Terms"),
                      _buildSectionContent(
                          "These Terms and Conditions may be updated periodically. Users will be notified of significant changes."),
                      const SizedBox(height: 15),
                      _buildSectionTitle("10. Contact Information"),
                      _buildSectionContent(
                          "For inquiries, disputes, or assistance, users can contact [shloka@gmail.com/tirrth@gmail.com]."),
                      const SizedBox(height: 20),

                      // Checkbox for Accepting Terms
                      Row(
                        children: [
                          Checkbox(
                            value: isChecked,
                            onChanged: (value) {
                              setState(() {
                                isChecked = value!;
                              });
                            },
                            fillColor: MaterialStateProperty.resolveWith<Color>(
                                  (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.black; // Background color when checked
                                }
                                return Colors.grey.shade100; // Background color when unchecked
                              },
                            ),
                            checkColor: Colors.white, // Tick mark color
                          ),
                          LocalizedText(
                            text: "I accept the Terms & Conditions",
                            style: GoogleFonts.poppins(color: Colors.black),

                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      // Accept Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildButton("Accept", isChecked ? Colors.black : Colors.grey, isChecked ? ()  {
                            // Navigate to HomePage when 'Accept' is clicked
                            Navigator.of(context).push(_createFadeRoute());
                          } : null),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return LocalizedText(
      text:
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return LocalizedText(
      text:
      content,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: Colors.black,
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(130, 45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Text(text, style: GoogleFonts.poppins()),
    );
  }

  Route _createFadeRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 200), // Adjust duration for smoothness
      pageBuilder: (context, animation, secondaryAnimation) => IntroductionPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
