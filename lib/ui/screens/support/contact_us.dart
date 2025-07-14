import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/localized_text_widget.dart';


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
    launchUrl(Uri.parse("mailto:$mailId?subject=$subject&body=$message"));
  }

  Future<void> _launchEmail1(String mailId) async {
    String subject = 'Inquiry to CEO\'s Office';
    String message = 'Hello, I would like to inquire about...';
    launchUrl(Uri.parse("mailto:$mailId?subject=$subject&body=$message"));
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isLargeScreen = screenWidth >= 900;

    // Responsive dimensions using MediaQuery
    final headerHeight = isLargeScreen ? screenHeight * 0.35 : isTablet ? screenHeight * 0.30 : screenHeight * 0.27;
    final horizontalPadding = isLargeScreen ? screenWidth * 0.05 : isTablet ? screenWidth * 0.04 : screenWidth * 0.035;
    final verticalSpacing = isLargeScreen ? screenHeight * 0.02 : isTablet ? screenHeight * 0.023 : screenHeight * 0.02;
    final cardPadding = isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.035 : screenWidth * 0.03;
    final titleFontSize = (isLargeScreen ? screenWidth * 0.06 : isTablet ? screenWidth * 0.065 : screenWidth * 0.07).clamp(24.0, 36.0);
    final subtitleFontSize = (isLargeScreen ? screenWidth * 0.03 : isTablet ? screenWidth * 0.035 : screenWidth * 0.04).clamp(18.0, 24.0);
    final bodyFontSize = (isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035).clamp(16.0, 22.0);
    final cardTitleFontSize = (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(14.0, 18.0); // Tighter clamp
    final cardBodyFontSize = (isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035).clamp(10.0, 14.0); // Tighter clamp
    final iconSize = (isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.045 : screenWidth * 0.05).clamp(20.0, 24.0); // Smaller icons
    final imageWidth = screenWidth * (isLargeScreen ? 0.65 : isTablet ? 0.7 : 0.75);
    final imageHeight = isLargeScreen ? screenHeight * 0.32 : isTablet ? screenHeight * 0.3 : screenHeight * 0.28;

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
                height: headerHeight,
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
              top: isLargeScreen ? screenHeight * 0.05 : isTablet ? screenHeight * 0.06 : screenHeight * 0.07,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  "assets/images/contact_us.png",
                  width: imageWidth,
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: isLargeScreen ? screenHeight * 0.06 : isTablet ? screenHeight * 0.05 : screenHeight * 0.045),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      LocalizedText(
                        text: "Help & Support",
                        style: GoogleFonts.poppins(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: imageHeight + verticalSpacing),
                ClipPath(
                  clipper: CustomShapeClipper(),
                  child: Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: cardPadding),
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        Center(
                          child: Column(
                            children: [
                              LocalizedText(
                                text: "Contact Us",
                                style: GoogleFonts.poppins(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: verticalSpacing * 0.5),
                              LocalizedText(
                                text: "Email or Call us to let us know your problem.",
                                style: GoogleFonts.poppins(
                                  fontSize: bodyFontSize,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: verticalSpacing),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: isLargeScreen ? 12 : isTablet ? 10 : 8, // Moderate spacing
                          mainAxisSpacing: isLargeScreen ? 12 : isTablet ? 10 : 8, // Moderate spacing
                          childAspectRatio: isLargeScreen ? 1.0 : isTablet ? 0.95 : 0.9, // Smaller cards
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            GestureDetector(
                              onTap: () => _launchEmail('shlokshetiya2111@gmail.com'),
                              child: ContactCard(
                                icon: Icons.chat,
                                title: "Chat with Us",
                                description: "Speak to our Support team.",
                                email: "shloka@gmail.com",
                                cardColor: Colors.white70,
                                iconColor: Colors.deepOrange.shade200,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _launchEmail1('shlokashetiya21@gmail.com'),
                              child: ContactCard(
                                icon: Icons.lock,
                                title: "Mail Us",
                                description: "We're here to help.",
                                email: "shlok21@gmail.com", // Removed \n
                                cardColor: Colors.white70,
                                iconColor: Colors.green.shade300,
                              ),
                            ),
                            GestureDetector(
                              onTap: _launchGoogleMaps,
                              child: ContactCard(
                                icon: Icons.location_on,
                                title: "Visit us",
                                description: "Visit our office HQ.",
                                email: "View on Google Maps", // Removed \n
                                cardColor: Colors.white70,
                                iconColor: Colors.lightBlueAccent.shade100,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _launchPhoneDialer("+91 91525 55088"),
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
                        SizedBox(height: verticalSpacing * 2),
                        Column(
                          children: [
                            Divider(
                              color: Colors.grey,
                              thickness: 2.5,
                              indent: horizontalPadding,
                              endIndent: horizontalPadding,
                            ),
                            SizedBox(height: verticalSpacing * 0.5),
                            Center(
                              child: LocalizedText(
                                text: "Frequently Asked Questions",
                                style: GoogleFonts.poppins(
                                  fontSize: cardTitleFontSize,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: verticalSpacing),
                        Column(
                          children: [
                            FAQSection(
                              question: "How does the GPS toll system work?",
                              answer: "The GPS toll system uses GPS technology to track your vehicle’s location as it passes through toll zones. The system automatically deducts the toll charges from...",
                            ),
                            FAQSection(
                              question: "Is the GPS toll system available in all regions?",
                              answer: "The GPS toll system is available in select regions with toll zones supported by the service. Check the app or website for a list of supported regions and routes.",
                            ),
                            FAQSection(
                              question: "Do I need to manually pay the toll every time?",
                              answer: "No, the GPS toll system automatically detects your vehicle and deducts the toll charges when you enter or exit a toll zone. There's no need for manual payment.",
                            ),
                            FAQSection(
                              question: "Can I use the GPS toll system on multiple vehicles?",
                              answer: "No, the GPS toll system supports only one device per car. Each vehicle requires a separate device for tracking toll charges.",
                            ),
                            FAQSection(
                              question: "Will I be notified when my account balance is low?",
                              answer: "Yes, the system will send you notifications when your balance falls below a pre-set threshold, reminding you to recharge before the next toll payment is due.",
                            ),
                          ],
                        ),
                        SizedBox(height: verticalSpacing),
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
  final Color cardColor;
  final Color iconColor;

  const ContactCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.email,
    required this.cardColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    // MediaQuery for card-specific sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    final cardTitleFontSize = (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(14.0, 18.0); // Tighter clamp
    final cardBodyFontSize = (isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035).clamp(10.0, 14.0); // Tighter clamp
    final iconSize = (isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.045 : screenWidth * 0.05).clamp(20.0, 24.0); // Smaller icons
    final cardPadding = isLargeScreen ? screenWidth * 0.015 : isTablet ? screenWidth * 0.017 : screenWidth * 0.02; // Tighter padding

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Allow card to size based on content
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            SizedBox(height: isLargeScreen ? 5 : isTablet ? 4 : 3), // Tighter spacing
            LocalizedText(
              text: title,
              style: GoogleFonts.poppins(
                fontSize: cardTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isLargeScreen ? 4 : isTablet ? 3 : 2), // Tighter spacing
            LocalizedText(
              text: description,
              style: GoogleFonts.poppins(
                fontSize: cardBodyFontSize,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isLargeScreen ? 4 : isTablet ? 3 : 2), // Tighter spacing
            LocalizedText(
              text: email,
              style: GoogleFonts.poppins(
                fontSize: cardBodyFontSize,
                color: Colors.blue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    // MediaQuery for FAQ section
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    final questionFontSize = (isLargeScreen ? screenWidth * 0.03 : isTablet ? screenWidth * 0.035 : screenWidth * 0.04).clamp(18.0, 24.0);
    final answerFontSize = (isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035).clamp(16.0, 20.0);

    return Column(
      children: [
        ExpansionTile(
          title: LocalizedText(
            text: widget.question,
            style: GoogleFonts.poppins(
              fontSize: questionFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              isExpanded = expanded;
            });
          },
          children: [
            Padding(
              padding: EdgeInsets.all(isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035),
              child: Text(
                widget.answer,
                style: GoogleFonts.poppins(
                  fontSize: answerFontSize,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}