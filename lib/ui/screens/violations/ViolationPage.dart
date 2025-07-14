import 'dart:ui'; // Required for blur effect
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/localized_text_widget.dart';


class ViolationPenaltyPage extends StatelessWidget {
  final List<Map<String, String>> violations = [
    {
      "title": "Overspeeding",
      "penalty": "₹1000",
      "description": "Driving above the speed limit is dangerous. It can lead to accidents and increased braking distance, putting other vehicles at risk."
    },
    {
      "title": "No Toll Payment",
      "penalty": "₹1500",
      "description": "Failure to pay the toll will result in a fine. Ensure you have a sufficient balance in your FASTag or digital toll account."
    },
    {
      "title": "Vehicle Not Linked to Toll Account",
      "penalty": "₹2000",
      "description": "Your vehicle must be registered and linked to a toll account to avoid unnecessary penalties. Update your details if needed."
    },
    {
      "title": "Unauthorized Vehicle Type on Restricted Road",
      "penalty": "₹3000",
      "description": "Certain roads have restrictions based on vehicle type. Using them without permission can result in penalties and legal actions."
    },
  ];

  // Function to Show Violation Details
  void _showViolationDetails(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      barrierDismissible: true, // Tap outside to close
      builder: (context) {
        return Stack(
          children: [
            // Blurred Background Effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3), // Semi-transparent overlay
              ),
            ),

            // Centered Popup Card
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.6), // 🔴 Red shadow for elevation
                        blurRadius: 20, // Increase for more effect
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Close Button (Top Right)
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Violation Title
                      LocalizedText(
                        text: title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Description
                      LocalizedText(
                        text: description,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  // Function to Call Toll Office
  void _callTollOffice() async {
    const String phoneNumber = "tel:+911204925505";
    if (await canLaunchUrl(Uri.parse(phoneNumber))) {
      await launchUrl(Uri.parse(phoneNumber));
    } else {
      print("Could not launch $phoneNumber");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: LocalizedText(
          text:  "Violations & Penalties",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              // Image
              Center(
                child: Container(
                  width: 210,
                  height: 160,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/violation.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Title
              LocalizedText(
                text: "Check Your Violation Penalties",
                style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 5),

              // Description
              LocalizedText(
                text: "Ensure you comply with traffic rules to avoid penalties. If you've received a penalty, review the charges below.",
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),

              // Violation List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: violations.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      String title = violations[index]["title"]!;
                      String description = violations[index]["description"] ?? "No details available.";
                      _showViolationDetails(context, title, description);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white54.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 35),
                        title: LocalizedText(
                          text:  violations[index]["title"]!,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        trailing:  LocalizedText(
                          text:  violations[index]["penalty"]!,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Contact Toll Office Button
              ElevatedButton.icon(
                onPressed: _callTollOffice,
                icon: const Icon(Icons.call, color: Colors.red),
                label:  LocalizedText(
                  text: "Contact Toll Office",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: Colors.redAccent, width: 0.5),
                  ),
                  elevation: 15,
                  shadowColor: Colors.black.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
