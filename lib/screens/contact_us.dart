import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../localized_text_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ContactPage(),
    );
  }
}

class ContactPage extends StatelessWidget {
  // Function to open Google Maps
  Future<void> _launchGoogleMaps() async {
    final Uri url = Uri.parse("comgooglemaps://?q=19.10786,72.837244");

    bool canLaunch = await canLaunchUrl(url);
    print('Can launch URL: $canLaunch');

    if (canLaunch) {
      await launchUrl(url);
    } else {
      // Fallback to the web URL if the app cannot be launched
      final Uri fallbackUrl = Uri.parse("https://www.google.co.in/maps?q=19.10786,72.837244");
      await launchUrl(fallbackUrl);
    }
  }

  // Function to open phone dialer
  Future<void> _launchPhoneDialer(String phoneNumber) async {
    final Uri phoneUrl = Uri(scheme: 'tel', path: phoneNumber);

    bool canLaunch = await canLaunchUrl(phoneUrl);
    if (canLaunch) {
      await launchUrl(phoneUrl);
    } else {
      print('Could not launch phone dialer');
    }
  }

  Future<void> _launchEmail(String mailId) async {
    String subject = 'Inquiry to Support Team';
    String message = 'Hello, I would like to inquire about...';
    launchUrl(Uri.parse("mailto:${mailId}?subject=${subject}&body=${message}"));
  }

  Future<void> _launchEmail1(String mailId) async {
    String subject = 'Inquiry to CEO\'s Office';
    String message = 'Hello, I would like to inquire about...';
    launchUrl(Uri.parse("mailto:${mailId}?subject=${subject}&body=${message}"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
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
                    top: 40, // Adjust to control image position
                    left: 1,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        "assets/images/contact_us.png",
                        width: 350, // Adjust dynamically
                        height: 350,

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

                            LocalizedText(
                              text: "Help & Support",
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

                      // Curved section for contact details
                      ClipPath(
                        clipper: CustomShapeClipper(),
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 0),
                                    LocalizedText(
                                      text: "Contact Us",
                                      style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    LocalizedText(
                                      text: "Email or Call us to let us know your problem.",
                                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),


                            const SizedBox(height: 30),
                              GridView.count(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  GestureDetector(
                                    onTap: () => _launchEmail('shlokshetiya2111@gmail.com'), // Whole card is tappable
                                    child: ContactCard(
                                      icon: Icons.chat,
                                      title: "Chat with Us",
                                      description: "Speak to our Support team.",
                                      email: "shloka@gmail.com",
                                      cardColor: Colors.white70,
                                      iconColor: Colors.deepOrange.shade200,
                                    ),
                                  ),
                                  // Chat with CEO - Launch Email
                                  GestureDetector(
                                    onTap: () => _launchEmail1('shlokashetiya21@gmail.com'),
                                    child: ContactCard(
                                      icon: Icons.lock,
                                      title: "Mail Us",
                                      description: "We're here to help.",
                                      email: "\nshlok21@gmail.com",
                                      cardColor: Colors.white70,
                                      iconColor: Colors.green.shade300,
                                    ),
                                  ),

// Visit Us - Open Google Maps
                                  GestureDetector(
                                    onTap: _launchGoogleMaps, // Open Google Maps
                                    child: ContactCard(
                                      icon: Icons.location_on,
                                      title: "Visit us",
                                      description: "Visit our office HQ.",
                                      email: "\nView on Google Maps",
                                      cardColor: Colors.white70,
                                      iconColor: Colors.lightBlueAccent.shade100,
                                    ),
                                  ),

// Call Us - Open Phone Dialer
                                  GestureDetector(
                                    onTap: () => _launchPhoneDialer("+91 91525 55088"), // Open Phone Dialer
                                    child: ContactCard(
                                      icon: Icons.phone,
                                      title: "Call us",
                                      description: "Mon-Sun from 6am to 6pm.",
                                      email: "+91 91525 55088",
                                      cardColor: Colors.white70,
                                      iconColor: Colors.red.shade300,
                                    ),
                                  ),

                                ],
                              ),
                              const SizedBox(height: 50),
                              Column(
                                children: [
                                  const Divider(
                                    color: Colors.grey, // Line color
                                    thickness: 2.5,     // Line thickness
                                    indent: 15,         // Space from left
                                    endIndent: 15,      // Space from right
                                  ),
                                  const SizedBox(height: 10), // Space between line and text
                                  const Center(
                                    child: LocalizedText(
                                      text: "Frequently Asked Questions",
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              Column(
                                children: [
                                  FAQSection(
                                    question: "How does the GPS toll system work?",
                                    answer: "The GPS toll system uses GPS technology to track your vehicle’s location as it passes through toll zones. The system automatically deducts the toll charges from your wallet based on your vehicle's location.",
                                  ),
                                   // Horizontal line
                                  FAQSection(
                                    question: "Is the GPS toll system available in all regions?",
                                    answer: "The GPS toll system is available in select regions with toll zones supported by the service. Check the app or website for a list of supported regions and routes.",
                                  ),
                                 // Horizontal line
                                  FAQSection(
                                    question: "Do I need to manually pay the toll every time?",
                                    answer: "No, the GPS toll system automatically detects your vehicle and deducts the toll charges when you enter or exit a toll zone. There's no need for manual payment.",
                                  ),
                                   // Horizontal line
                                  FAQSection(
                                    question: "Can I use the GPS toll system on multiple vehicles?",
                                    answer: "No, the GPS toll system supports only one device per car. Each vehicle requires a separate device for tracking toll charges.",
                                  ),
                                   // Horizontal line
                                  FAQSection(
                                    question: "Will I be notified when my account balance is low?",
                                    answer: "Yes, the system will send you notifications when your balance falls below a pre-set threshold, reminding you to recharge before the next toll payment is due.",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ]
            )
        )
    );
  }
}

class CustomShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, 0);
    path.lineTo(0, size.height - 20);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, size.height - 20);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

class ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String email;
  final VoidCallback? onEmailTap; // Added callback for Google Maps action
  final Color cardColor;  // Color for the card
  final Color iconColor;  // Color for the icon

  const ContactCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.email,
    this.onEmailTap, // Accept callback here
    required this.cardColor, // Accept card color
    required this.iconColor, // Accept icon color
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,  // Set the card background color
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: iconColor), // Set the icon color
            const SizedBox(height: 10),
            LocalizedText(
              text: title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            LocalizedText(
              text: description,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onEmailTap, // Trigger callback when tapped
              child:LocalizedText(
                text: email,
                style: const TextStyle(fontSize: 14, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQSection extends StatefulWidget {
  final String question;
  final String answer;

  const FAQSection({super.key, required this.question, required this.answer});

  @override
  _FAQSectionState createState() => _FAQSectionState();
}

class _FAQSectionState extends State<FAQSection> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpansionTile(
          title: LocalizedText(
            text:  widget.question,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              isExpanded = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(widget.answer, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ),
          ],
        ),
        ],
    );
  }
}

