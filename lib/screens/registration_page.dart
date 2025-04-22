import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:new_ui/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:new_ui/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_ui/screens/terms_conditions.dart';
import 'obd_port_locator_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _numberPlateController = TextEditingController();
  String? _rcBookFile;
  String? _selectedVehicleType;
  String? _selectedBrand;
  String? _selectedModel;
  String? _selectedColor;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
//  TextEditingController _vehicleNumberController = TextEditingController(); // Add this
  final TextEditingController _vinController = TextEditingController();
  String? extractedVehicleNumber; // Add this
  final List<String> _vehicleTypes = ['Car', 'LCV', 'HCV'];

  final Map<String, Map<String, Map<String, List<String>>>> _vehicleData = {
    'Car': {
      'Maruti-Suzuki': {
        'Brezza': ['Red', 'White'],
        'Wagon-R': ['Blue', 'Orange','Red'],
        'Dzire': ['Blue', 'Brown','White'],
      },
      'Tata': {
        'Nexon': ['Blue', 'Purple','White'],
        'Harrier': ['White', 'Yellow'],
        'Punch': ['Blue', 'Brown'],
      },
      'Hyundai': {
        'Creta': ['Black', 'White','Red'],
        'Venue': ['Blue', 'Red','White'],
      },
      'Honda': {
        'Amaze': ['Black', 'White','Red'],
        'City': ['Blue', 'Red','Grey'],
        'Elevate': ['White', 'Blue','Orange'],
      },
      'Mahindra': {
        'Scorpio': ['Black', 'White'],
        'XUV-700': ['Black', 'Red','Silver'],
      },
      'MG': {
        'Gloster': ['Black', 'White'],
        'Hector': ['Black','White' , 'Red'],
        'Zs-Ev': ['White', 'Black'],
      },
      'Mercedes-Benz': {
        'C-Class': ['Brown','Red','White'],
        'Velar': [ 'White','Brown','Green'],
        'S-Class': ['Blue','Grey','White'],
      },
      'Skoda': {
        'Kodiaq': ['Blue', 'Green','Red'],
        'Kushaq': ['Orange', 'Red', 'White'],
        'Slavia' : ['Black', 'Red', 'Blue'],
      },
      'Toyota': {
        'Fortuner': ['Black', 'White'],
        'Innova': ['Black', 'White'],
      },
      'Volkswagen': {
        'Taigun': ['Black', 'White'],
        'Tiguan': ['Black', 'White'],
        'Virtus': ['White','Yellow'],
      },
    },
    'Lcv': {
      'Ashok-Leyland': {
        '8X2-Tractor': ['White', 'Blue'],
        'Transit-Mixer': ['White', 'Yellow'],
      },
      'Eicher': {
        'PRO-2110XP': ['Blue','Brown', 'White'],
      },
      'Mahindra': {
        'Blazo-X42': ['Green', 'White'],
      },
    },
    'Hcv': {
      'Ashok-Leyland': {
        '4225': ['White', 'Silver'],
      },
      'Eicher': {
        'PRO-5052T': ['Yellow', 'White'],
      },
      'Mahindra': {
        'Blazo-X35': ['White', 'Yellow'],
        'Blazo-X40': ['White-Black', 'White-Blue'],
      },
    },
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  String _uploadStatus = "No file uploaded"; // Default state

  bool _isFileUploaded = false; // Track file upload success

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) {
      setState(() {
        _uploadStatus = "No file selected";
        _isFileUploaded = false; // ❌ Keep Submit Button Disabled
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No file selected. Please select an image.")),
      );
      return;
    }

    File imageFile = File(result.files.single.path!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        setState(() {
          _uploadStatus = "No text recognized in the image";
          _isFileUploaded = false; // ❌ Keep Submit Button Disabled
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ No text recognized in the image.")),
        );
        return;
      }

      String extractedText = recognizedText.text;

      // Extract vehicle number
      String? vehicleNumber = _extractVehicleNumber(extractedText);
      // Extract VIN
      String? vin = _extractVIN(extractedText);

      setState(() {
        extractedVehicleNumber = vehicleNumber;
      });

      if (vehicleNumber == null) {
        setState(() {
          _uploadStatus = "No valid vehicle number found in the image";
          _isFileUploaded = false; // ❌ Keep Submit Button Disabled
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ No valid vehicle number found in the image.")),
        );
        return;
      }

      if (vin == null) {
        setState(() {
          _uploadStatus = "No valid VIN found in the image";
          _isFileUploaded = false; // ❌ Keep Submit Button Disabled
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Warning: VIN number could not be extracted. Please upload an image containing a valid VIN."),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // If both vehicle number and VIN are extracted, proceed with validation
      String cleanedExtractedVehicleNumber = vehicleNumber.replaceAll(RegExp(r'\s+|-'), "").toUpperCase();
      String cleanedUserInputVehicleNumber = _numberPlateController.text.replaceAll(RegExp(r'\s+|-'), "").toUpperCase();

      // Compare the VIN if user provided one
      bool vinMatches = true; // Default to true if VIN comparison is not required
      String cleanedExtractedVIN = vin.replaceAll(RegExp(r'\s+|-'), "").toUpperCase();
      if (_vinController.text.isNotEmpty) {
        String cleanedUserInputVIN = _vinController.text.replaceAll(RegExp(r'\s+|-'), "").toUpperCase();
        vinMatches = cleanedExtractedVIN == cleanedUserInputVIN;
      }

      if (cleanedExtractedVehicleNumber == cleanedUserInputVehicleNumber && vinMatches) {
        setState(() {
          _uploadStatus = "File uploaded successfully!";
          _isFileUploaded = true; // ✅ Enable Submit Button
        });

        // Update the controllers with the extracted values
        _numberPlateController.text = cleanedExtractedVehicleNumber;
        _vinController.text = cleanedExtractedVIN;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Vehicle number matched: $cleanedExtractedVehicleNumber\nVIN extracted: $cleanedExtractedVIN",
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        setState(() {
          _uploadStatus = "Data does not match";
          _isFileUploaded = false; // ❌ Keep Submit Button Disabled
        });

        String errorMessage = "❌ Vehicle number does not match.\nExtracted: $cleanedExtractedVehicleNumber\nInput: $cleanedUserInputVehicleNumber";
        if (!vinMatches) {
          errorMessage += "\nVIN does not match.\nExtracted: $cleanedExtractedVIN\nInput: ${_vinController.text}";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _uploadStatus = "Error processing image";
        _isFileUploaded = false; // ❌ Keep Submit Button Disabled
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error processing image: $e")),
      );
    } finally {
      textRecognizer.close(); // Ensure the TextRecognizer is always closed
    }
  }


  // Function to extract vehicle number using regex
  String? _extractVehicleNumber(String text) {
    // Modify regex based on your country’s vehicle number format
    String pattern = r"[A-Z]{2}\s?\d{1,2}\s?[A-Z]{1,2}\s?\d{4}";
    RegExp regex = RegExp(pattern);

    // Debugging: Print regex being used
    print("📝 Using Regex Pattern: $pattern");

    Match? match = regex.firstMatch(text);

    if (match != null) {
      print("✅ Matched Vehicle Number: '${match.group(0)}'"); // Print matched number
    } else {
      print("❌ No Vehicle Number Found!");
    }

    return match?.group(0);
  }

  String? _extractVIN(String text) {
    // Regex for VIN: 17 characters, only A-Z (excluding I, O, Q) and 0-9
    final vinRegex = RegExp(r'\b[A-HJ-NPR-Z0-9]{17}\b', caseSensitive: false);

    // Find all matches in the text
    final matches = vinRegex.allMatches(text);

    // If a match is found, return the first valid VIN
    for (var match in matches) {
      String vin = match.group(0)!.toUpperCase();
      // Additional validation: ensure no I, O, Q are present
      if (!vin.contains(RegExp(r'[IOQ]'))) {
        return vin;
      }
    }

    // Return null if no valid VIN is found
    return null;
  }

  Future<void> _storeVehicleData(String? vin) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
        return;
      }

      String uid = user.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'vehicle': {
          'numberPlate': _numberPlateController.text,
          'rcBookFile': _rcBookFile ?? '',
          'type': _selectedVehicleType ?? '',
          'brand': _selectedBrand ?? '',
          'model': _selectedModel ?? '',
          'color': _selectedColor ?? '',
          'vin': vin ?? _vinController.text,
        }
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle registered successfully!')),
      );

      // Navigate to HomeScreen after successful registration
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ObdPortLocatorPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error storing data: $e')),
      );
    }
  }


  bool _isValidNumberPlate(String numberPlate) {
    final regex = RegExp(r'^[A-Z]{2}\d{2}[A-Z]{1,2}\d{4}$');
    return regex.hasMatch(numberPlate);
  }

  void _onSubmit() {
    final numberPlate = _numberPlateController.text;

    if (numberPlate.isEmpty ||
        !_isValidNumberPlate(numberPlate) ||
        !_isFileUploaded ||  // ❌ Ensure file is uploaded
        _selectedVehicleType == null ||
        _selectedBrand == null ||
        _selectedModel == null ||
        _selectedColor == null) {

      String missing = '';
      if (numberPlate.isEmpty || !_isValidNumberPlate(numberPlate)) {
        missing += 'Valid Vehicle Number Plate (alphanumeric)';
      }
      if (!_isFileUploaded) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'RC Book Upload';
      }
      if (_selectedVehicleType == null) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'Vehicle Type';
      }
      if (_selectedBrand == null) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'Car Brand';
      }
      if (_selectedModel == null) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'Car Model';
      }
      if (_selectedColor == null) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'Car Color';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide the following: $missing')),
      );
    } else {
      // ✅ Final check for matching number plates
      String cleanedEntered = numberPlate.replaceAll(RegExp(r'\s+|-'), "").toUpperCase();
      String cleanedExtracted = extractedVehicleNumber?.replaceAll(RegExp(r'\s+|-'), "").toUpperCase() ?? "";

      if (cleanedEntered != cleanedExtracted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Enter a valid number plate.")),
        );
        return; // Stop further execution if the number doesn't match
      }

      // ✅ Proceed to next page if everything is correct
      _storeVehicleData(_vinController.text.isNotEmpty ? _vinController.text : null);

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ObdPortLocatorPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var opacityTween = Tween(begin: 0.0, end: 1.0);
            var opacityAnimation = animation.drive(opacityTween);

            return FadeTransition(opacity: opacityAnimation, child: child);
          },
        ),
      );
    }
  }



  @override
  void dispose() {
    _numberPlateController.dispose();
    _vinController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),

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
          top: 10, // Adjust to control image position
          left: 17,
          right: 0,
          child: Center(
            child: Image.asset(
              "assets/images/car_details.png",
              width: 370, // Adjust dynamically
              height: 370,
            ),
          ),
        ),

        // Content below the image (white card with contact details)
        Column(
            children: [
            const SizedBox(height: 42),

        // Form contents (email, password, login, etc.)
        const SizedBox(height: 280),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 29.0),
          child: Column(
            children: [
              Text(
                'Vehicle Registration',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
                    const SizedBox(height: 10),
                    const Text(
                      'Register your vehicle details!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: DropdownButtonFormField<String>(
                        value: _selectedVehicleType,
                        hint: const Text('Select vehicle type'),
                        items: _vehicleTypes
                            .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(
                            type,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicleType = value;
                            _selectedBrand = null;
                            _selectedModel = null;
                            _selectedColor = null;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black26, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ),
                    if (_selectedVehicleType != null) ...[
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: DropdownButtonFormField<String>(
                          value: _selectedBrand,
                          hint: Text(
                              "Select your ${_selectedVehicleType == 'Car' ? 'car' : 'vehicle'}'s brand"),
                          items: _vehicleData[_selectedVehicleType!]!
                              .keys
                              .map((brand) => DropdownMenuItem(
                            value: brand,
                            child: Text(
                              brand,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedBrand = value;
                              _selectedModel = null;
                              _selectedColor = null;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              const BorderSide(color: Colors.black26, width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                              const BorderSide(color: Colors.black, width: 2),
                            ),
                          ),
                          dropdownColor: Colors.white,
                        ),
                      ),
                    ],
                    if (_selectedBrand != null) ...[
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedModel,
                        hint: Text(
                            "Select your ${_selectedVehicleType == 'Car' ? 'car' : 'vehicle'}'s model"),
                        items:
                        _vehicleData[_selectedVehicleType!]![_selectedBrand!]!
                            .keys
                            .map((model) => DropdownMenuItem(
                          value: model,
                          child: Text(
                            model,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedModel = value;
                            _selectedColor = null;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black26, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ],
                    if (_selectedModel != null) ...[
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedColor,
                        hint: Text(
                            "Select your ${_selectedVehicleType == 'Car' ? 'car' : 'vehicle'}'s color"),
                        items: _vehicleData[_selectedVehicleType!]![
                        _selectedBrand!]![_selectedModel!]!
                            .map((color) => DropdownMenuItem(
                          value: color,
                          child: Text(
                            color,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedColor = value;
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black26, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                            const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        dropdownColor: Colors.white,
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _numberPlateController,
                      decoration: InputDecoration(
                        hintText: 'Vehicle Number Plate (e.g., ABC-1234)',
                        hintStyle: const TextStyle(color: Colors.black54),
                        prefixIcon:
                        const Icon(Icons.directions_car, color: Colors.black),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Colors.black, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          const BorderSide(color: Colors.black26, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
              Card(
                color: Colors.white,
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.black26, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RC Book',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _uploadStatus,  // ✅ Updated to show dynamic text
                              style: TextStyle(
                                fontSize: 14,
                                color: _uploadStatus == "File uploaded successfully!"
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Upload',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isFileUploaded ? _onSubmit : null, // ✅ Disable until file is uploaded
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFileUploaded ? Colors.black : Colors.grey, // Gray when disabled
                  padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),

              const SizedBox(height: 20),
            ],
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
