import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'home_page.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController _numberPlateController = TextEditingController();
  String? _rcBookFile;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _rcBookFile = result.files.single.path!;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RC Book uploaded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error picking the file.')),
      );
    }
  }

  bool _isValidNumberPlate(String numberPlate) {
    final regex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]+$');
    return regex.hasMatch(numberPlate);
  }

  void _onSubmit() {
    final numberPlate = _numberPlateController.text;

    if (numberPlate.isEmpty || !_isValidNumberPlate(numberPlate) || _rcBookFile == null) {
      String missing = '';
      if (numberPlate.isEmpty || !_isValidNumberPlate(numberPlate)) {
        missing += 'Valid Vehicle Number Plate (alphanumeric)';
      }
      if (_rcBookFile == null) {
        if (missing.isNotEmpty) missing += ', ';
        missing += 'RC Book';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please provide the following: $missing')),
      );
    } else {
      // Navigate with opacity transition
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBackgroundColor = Colors.blue[50];

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vehicle Registration',
                style: TextStyle(
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
              TextFormField(
                controller: _numberPlateController,
                decoration: const InputDecoration(
                  hintText: 'Vehicle Number Plate (e.g., ABC-1234)',
                  prefixIcon: Icon(Icons.directions_car, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: cardBackgroundColor,
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 12.0),
                  child: Row(
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
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _rcBookFile == null
                                  ? 'No file uploaded'
                                  : 'File uploaded successfully!',
                              style: TextStyle(
                                fontSize: 14,
                                color: _rcBookFile == null ? Colors.grey : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
                onPressed: _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 100.0, vertical: 15.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}