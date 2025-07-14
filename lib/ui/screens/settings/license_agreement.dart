import 'package:flutter/material.dart';
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
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const LicenseAndAgreementPage(),
    );
  }
}

class LicenseAndAgreementPage extends StatefulWidget {
  const LicenseAndAgreementPage({super.key});

  @override
  State<LicenseAndAgreementPage> createState() => _LicenseAndAgreementPageState();
}

class _LicenseAndAgreementPageState extends State<LicenseAndAgreementPage> {
  bool isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,color: Colors.white,),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: LocalizedText(
          text:"License & Agreement",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24,color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 50,
        titleSpacing: 0,
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

          // Positioned Image
          Positioned(
            top: 60,
            left: 0,
            right: 5,
            child: Center(
              child: Image.asset(
                'assets/images/terms_and_conditions.png', // Update with actual image
                height: 250,
                width: 250,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Content Container
          Padding(
            padding: const EdgeInsets.only(top: 282),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(35),
                topRight: Radius.circular(35),
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black : Colors.white,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      _buildSectionTitle("License Grant"),
                      _buildSectionContent(
                          "Toll Seva grants you a non-exclusive, non-transferable license to use the Toll Seva for its intended purpose. This license is subject to the terms outlined in this Agreement."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("License Restrictions"),
                      _buildSectionContent(
                          "You agree not to:\n- Modify, distribute, or reverse-engineer the System.\n- Use the System in any manner that could harm or disrupt its functionality.\n- Attempt to gain unauthorized access to any part of the System or related systems."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("Ownership"),
                      _buildSectionContent(
                          "The System, including all intellectual property rights, remains the property of Toll Seva. This Agreement does not transfer ownership of the System or any related intellectual property to the user."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("User Responsibilities"),
                      _buildSectionContent(
                          "By using the System, you acknowledge and agree to the following responsibilities:\n- Provide accurate and up-to-date information during registration.\n- Maintain the confidentiality of your account and login details.\n- Notify Toll Seva of any unauthorized use of your account.\n- Ensure the proper functioning of your GPS device and payment methods."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("System Availability"),
                      _buildSectionContent(
                          "Toll Seva will make reasonable efforts to ensure the availability and performance of the System. However, we do not guarantee continuous access or error-free performance."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("Termination"),
                      _buildSectionContent(
                          "Toll Seva reserves the right to suspend or terminate your access to the System at its discretion, including but not limited to cases of breach of this Agreement or failure to comply with payment requirements."),
                      const SizedBox(height: 10),

                      _buildSectionTitle("Indemnity"),
                      _buildSectionContent(
                          "You agree to indemnify and hold harmless Toll Seva from any claims, damages, losses, or expenses arising from your use of the System or any violation of this Agreement."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("Changes to the License and Agreement"),
                      _buildSectionContent(
                          "Toll Seva reserves the right to modify or update this License and Agreement at any time. Continued use of the System after changes constitutes your acceptance of the revised terms."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("Governing Law and Jurisdiction"),
                      _buildSectionContent(
                          "This Agreement will be governed by and construed in accordance with the laws of India. Any disputes will be subject to the exclusive jurisdiction of the courts in [Your City]."),
                      const SizedBox(height: 10),
                      _buildSectionTitle("Contact Information"),
                      _buildSectionContent(
                          "For questions or concerns, please contact Toll Seva at [shlok@gmail.com/tirthh@gmail.com]."),
                      const SizedBox(height: 20),

                      // Close Button
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20), // Adjust the padding value here to shift the button to the right
                          child: SizedBox(
                            width: 100,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child:LocalizedText(
                                text: "Close",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: LocalizedText(
        text: title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSectionContent(String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child:LocalizedText(
        text: content,
        style: GoogleFonts.poppins(
          fontSize: 14,
        ),
      ),
    );
  }
}
