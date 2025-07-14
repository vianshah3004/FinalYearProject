import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../widgets/localized_text_widget.dart';


class AboutUsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes back arrow
        title: LocalizedText(
          text: "About Us",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,

      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Section with Background Effect
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), // Adjust blur intensity
                      child: Image.asset(
                        "assets/images/toll.jpg",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().fadeIn(duration: 900.ms),

                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.deepPurple.withOpacity(0.7),
                      image: DecorationImage(
                        image: AssetImage("assets/images/main_logo.png"), // Main logo
                        fit: BoxFit.cover,
                      ),
                    ),
                  ).animate().scale(duration: 900.ms),
                ],
              ),

              const SizedBox(height: 20),

              // About Us Text
              LocalizedText(
                text:  "Toll Seva is a smart GPS-based toll collection system designed to provide seamless and automatic toll payments. Our mission is to make toll payments efficient, hassle-free, and secure for all users.",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 40),

              // Values Section
              LocalizedText(
                text:  "Values",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ValueCard(icon: Icons.eco, title: "Efficiency", color: Colors.lightGreenAccent),
                  ValueCard(icon: Icons.security, title: "Security", color: Colors.purpleAccent),
                  ValueCard(icon: FontAwesomeIcons.robot, title: "Automation", color: Colors.orangeAccent),
                  ValueCard(icon: Icons.emoji_objects, title: "Innovation", color: Colors.blueAccent),
                ],
              ).animate().slide(duration: 600.ms),
              const SizedBox(height: 40),

              // GPS Toll System Components Section
              LocalizedText(
                text:  "Components of GPS Toll System",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ComponentCard(
                      title: "Automated Vehicle Identification (AVI)",
                      description:
                      "AVI utilizes GPS and RFID to identify vehicles. GPS provides location data, while RFID enables real-time communication with toll systems, ensuring accurate identification at high speeds.",
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 20),

                    ComponentCard(
                      title: "Automated Vehicle Classification and Toll Calculation",
                      description:
                      "Differentiates vehicle types for appropriate toll rates. Uses inductive sensors and GPS data to classify vehicles dynamically, ensuring fair pricing.",
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 20),

                    ComponentCard(
                      title: "Transaction Processing",
                      description:
                      "Manages customer accounts and toll transactions in real-time. Supports prepaid and postpaid accounts, updating balances instantly for seamless transactions.",
                    ).animate().fadeIn(delay: 700.ms),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Divider(
                color: Colors.black,      // Line color
                thickness: 1,             // Line thickness
                indent: 20,               // Left spacing
                endIndent: 20,            // Right spacing
              ),

              // Team Members Section
              LocalizedText(
                text: "   Meet the Team",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ).animate().fadeIn(duration: 600.ms),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TeamMemberCard(name: "Shloka Shetiya", role: "CEO", image: "assets/images/shlok.jpg"),
                  TeamMemberCard(name: "Vian Shah", role: "COO", image: "assets/images/vian.jpg"),
                  TeamMemberCard(name: "Tirrth Mistry", role: "CTO", image: "assets/images/tirrth.jpg"),
                ],
              ).animate().slide(duration: 600.ms),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 20), // 👈 Shift to the right
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TeamMemberCard(
                      name: "Mrs. Sharyu Kadam",
                      role: "Mentor",
                      image: "assets/images/sharyu_maam.png",
                    ),
                  ],
                ).animate().slide(duration: 600.ms),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// Value Card Widget
class ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const ValueCard({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 5),
          LocalizedText(
            text: title,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// GPS System Component Card
class ComponentCard extends StatelessWidget {
  final String title;
  final String description;

  const ComponentCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            text: title,
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            text: description,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// Team Member Card
class TeamMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final String image;

  const TeamMemberCard({required this.name, required this.role, required this.image});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Image.asset(image, width: 80, height: 80, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        LocalizedText(
          text: name,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        LocalizedText(
          text: role,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
