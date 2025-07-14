import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../../data/obd_data.dart';
import '../../../providers/wallet_provider.dart';
import '../../../widgets/localized_text_widget.dart';
import '../maps/RoadsideAssistance.dart';
import '../maps/map_google.dart';
import '../onboarding/how_it_works.dart';
import '../profile/profile_page.dart';
import '../settings/notifications/notification_panel.dart';
import '../toll/toll_screen.dart';
import '../violations/ViolationPage.dart';
import 'dashboard/wallet_screen.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String firstName = '';
  String lastName = '';
  String type = '';
  String brand = '';
  String color = '';
  String model = '';
  String vin = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  bool isDeviceConnected = false;
  bool wasDeviceConnected = false;
  bool showMessage = false;
  String messageText = '';
  Color messageColor = Colors.red;
  Timer? messageTimer;
  double progressValue = 0.0;
  bool _isFirstLoad = true;
  StreamSubscription<DocumentSnapshot>? _connectionListener;

  Map<String, dynamic> obdData = {
    "RPM": 0.0,
    "Speed": 0.0,
    "Engine Load": 0.0,
    "Coolant Temp": 0.0,
    "Intake Temp": 0.0,
    "Throttle Position": 0.0,
    "Battery Voltage": 0.0,
    "Fuel Pressure": 0.0,
    "Timing Advance": 0.0,
    "MAF Air Flow": 0.0,
    "DTCs": [],
    "VIN": "",
  };

  void _updateObdData(Map<String, dynamic> newData) {
    setState(() {
      obdData = newData;
    });
  }

  Future<String?> _fetchVINFromFirestore(String uid) async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (snapshot.exists) {
        var vehicleData = snapshot.data()?['vehicle'];
        return vehicleData?['vin'];
      }
      return null;
    } catch (e) {
      print("Error fetching VIN: $e");
      return null;
    }
  }

  void _onConnectionStatusChanged(bool isConnected, bool wasDisconnected) async {
    if (isConnected) {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      String? storedVIN = await _fetchVINFromFirestore(uid);
      String? obdVIN = obdData["VIN"];

      print("🔍 Stored VIN: '$storedVIN', OBD VIN: '$obdVIN'");

      storedVIN = storedVIN?.trim().toUpperCase();
      obdVIN = obdVIN?.trim().toUpperCase();

      if (storedVIN != null &&
          storedVIN.isNotEmpty &&
          obdVIN != null &&
          obdVIN.isNotEmpty &&
          storedVIN == obdVIN) {
        setState(() {
          isDeviceConnected = true;
          messageText = 'Device is connected successfully';
          messageColor = Colors.green;
          wasDeviceConnected = true;
          showMessage = true;
          messageTimer?.cancel();
        });
        print("✅ VIN matched. Device authorized.");
      } else {
        setState(() {
          isDeviceConnected = false;
          messageText = 'Unauthorized Device';
          messageColor = Colors.red;
          showMessage = true;
        });
        print("❌ VIN mismatch or invalid: Stored='$storedVIN', OBD='$obdVIN'");
      }
    } else if (wasDisconnected) {
      setState(() {
        isDeviceConnected = false;
        messageText = 'Device is removed';
        messageColor = Colors.red;
        showMessage = true;
        wasDeviceConnected = false;
      });
      print("🔌 Device disconnected.");
    } else {
      setState(() {
        isDeviceConnected = false;
        messageText = 'Please Insert Device';
        messageColor = Colors.red;
        showMessage = true;
      });
      print("🔌 No device connected.");
    }

    if (showMessage) {
      print("📢 Message shown at: ${DateTime.now()} - $messageText");
      _startProgressBar();
    }

    _updateConnectionStatusInFirestore(isDeviceConnected);
  }

  void _startProgressBar() {
    setState(() {
      progressValue = 1.0;
    });

    const duration = Duration(seconds: 5);
    const totalSteps = 100;
    final stepDurationInMs = duration.inMilliseconds ~/ totalSteps;
    final stepDuration = Duration(milliseconds: stepDurationInMs);

    Timer.periodic(stepDuration, (timer) {
      setState(() {
        progressValue -= 1 / totalSteps;
      });

      if (progressValue <= 0.0) {
        timer.cancel();
        setState(() {
          showMessage = false;
        });
        print("Message hidden at: ${DateTime.now()}");
      }
    });
  }

  void _toggleDrawer() {
    if (!_isDrawerOpen) {
      _animationController.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldKey.currentState?.openDrawer();
        setState(() {
          _isDrawerOpen = true;
        });
      });
    } else {
      _animationController.reverse().then((_) {
        _scaffoldKey.currentState?.closeDrawer();
        setState(() {
          _isDrawerOpen = false;
        });
      });
    }
  }

  Future<void> _generateDtcReport() async {
    final List<dynamic> dtcList = obdData["DTCs"] as List<dynamic>? ?? [];
    Map<String, String> testResults = {
      "Coolant Temp": () {
        final coolantTemp = obdData["Coolant Temp"]! as double;
        if (coolantTemp < 10) return "Fail (Too Low)";
        if (coolantTemp < 20) return "Fail (Low)";
        if (coolantTemp > 50) return "Fail (High)";
        if (coolantTemp > 70) return "Fail (Too High)";
        return "Pass";
      }(),
      "Battery Voltage": () {
        final batteryVoltage = obdData["Battery Voltage"]! as double;
        if (batteryVoltage < 10.0) return "Fail (Too Low)";
        if (batteryVoltage < 12.0) return "Fail (Low)";
        if (batteryVoltage > 15.0) return "Fail (High)";
        if (batteryVoltage < 17.0) return "Fail (Too High)";
        return "Pass";
      }(),
      "Engine Load": () {
        final engineLoad = obdData["Engine Load"]! as double;
        if (engineLoad < 5) return "Fail (Too Low)";
        if (engineLoad < 10) return "Fail (Low)";
        if (engineLoad > 50) return "Fail (High)";
        if (engineLoad > 70) return "Fail (Too High)";
        return "Pass";
      }(),
      "Intake Temp": () {
        final intakeTemp = obdData["Intake Temp"]! as double;
        if (intakeTemp < 10) return "Fail (Too Low)";
        if (intakeTemp < 20) return "Fail (Low)";
        if (intakeTemp > 50) return "Fail (High)";
        if (intakeTemp > 60) return "Fail (Too High)";
        return "Pass";
      }(),
      "DTCs": dtcList.isEmpty ? "Pass" : "Fail (Codes Present)",
    };

    bool isCarOk = testResults.values.every((result) => result == "Pass");

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Vehicle Diagnostic Report",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text("Date: ${DateTime.now().toString().substring(0, 19)}"),
            pw.Text("Vehicle: $type $brand $model ($color)"),
            pw.SizedBox(height: 20),
            pw.Text("OBD-II Data:",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text("RPM: ${obdData["RPM"]?.toStringAsFixed(0) ?? 'N/A'}"),
            pw.Text("Speed: ${obdData["Speed"]?.toStringAsFixed(0) ?? 'N/A'} km/h"),
            pw.Text("Engine Load: ${obdData["Engine Load"]?.toStringAsFixed(0) ?? 'N/A'}%"),
            pw.Text("Coolant Temp: ${obdData["Coolant Temp"]?.toStringAsFixed(0) ?? 'N/A'}°C"),
            pw.Text("Intake Temp: ${obdData["Intake Temp"]?.toStringAsFixed(0) ?? 'N/A'}°C"),
            pw.Text("Throttle Position: ${obdData["Throttle Position"]?.toStringAsFixed(0) ?? 'N/A'}%"),
            pw.Text("Battery Voltage: ${obdData["Battery Voltage"]?.toStringAsFixed(1) ?? 'N/A'}V"),
            pw.Text("Fuel Pressure: ${obdData["Fuel Pressure"]?.toStringAsFixed(0) ?? 'N/A'} kPa"),
            pw.Text("Timing Advance: ${obdData["Timing Advance"]?.toStringAsFixed(1) ?? 'N/A'}°"),
            pw.Text("MAF Air Flow: ${obdData["MAF Air Flow"]?.toStringAsFixed(2) ?? 'N/A'} g/s"),
            pw.Text("DTCs: ${dtcList.isEmpty ? "None" : dtcList.join(", ")}"),
            pw.SizedBox(height: 20),
            pw.Text("Test Results:",
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text("Coolant Temp: ${testResults["Coolant Temp"]}"),
            pw.Text("Battery Voltage: ${testResults["Battery Voltage"]}"),
            pw.Text("Engine Load: ${testResults["Engine Load"]}"),
            pw.Text("Intake Temp: ${testResults["Intake Temp"]}"),
            pw.Text("DTCs: ${testResults["DTCs"]}"),
            pw.SizedBox(height: 20),
            pw.Text("Overall Status: ${isCarOk ? "OK" : "Not OK"}",
                style: pw.TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );

    bool hasPermission = await _requestStoragePermission(context);
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Storage permission denied. Cannot save the PDF."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Directory? downloadsDir;
    try {
      downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception("Could not access Downloads directory");
      }
    } catch (e) {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final fileName = "dtc_report_${DateTime.now().millisecondsSinceEpoch}.pdf";
    final filePath = "${downloadsDir.path}/$fileName";
    final file = File(filePath);

    try {
      await file.writeAsBytes(await pdf.save());
      print("PDF saved to: $filePath");

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open the PDF: ${result.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("DTC Report saved to Downloads folder: $fileName"),
        ),
      );
    } catch (e) {
      print("Error saving or opening PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving PDF: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        return true;
      }

      var status = await Permission.storage.status;
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) {
          await _showPermissionDeniedDialog(context);
          return false;
        }
        status = await Permission.storage.request();
      }

      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Storage permission denied. Cannot save the PDF."),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      return true;
    }
    return true;
  }

  Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Storage Permission Required"),
        content: const Text(
          "This app needs storage permission to save the PDF to your Downloads folder. "
              "Please enable it in the app settings.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initializeConnectionStatus();
  }

  Future<void> _fetchUserData() async {
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        DocumentSnapshot userData = await userDocRef.get();

        setState(() {
          firstName = userData['firstName'] ?? 'Name';
          lastName = userData['lastName'] ?? 'Name';
          type = userData['vehicle']?['type'] ?? 'type';
          brand = userData['vehicle']?['brand'] ?? 'brand';
          model = userData['vehicle']?['model'] ?? 'model';
          color = userData['vehicle']?['color'] ?? 'color';
          vin = userData['vehicle']?['vin'] ?? 'vin';
        });

        await userDocRef.update({'sign_out_time': null});
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _initializeConnectionStatus() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentReference deviceStatusRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('device_status')
        .doc('connection');

    _connectionListener = deviceStatusRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        bool newConnectionStatus = data?['isDeviceConnected'] ?? false;
        bool wasDisconnected = wasDeviceConnected && !newConnectionStatus;

        setState(() {
          isDeviceConnected = newConnectionStatus;
          wasDeviceConnected = newConnectionStatus;
        });

        _onConnectionStatusChanged(newConnectionStatus, wasDisconnected);
      } else {
        deviceStatusRef.set({
          'isDeviceConnected': false,
          'lastUpdated': FieldValue.serverTimestamp(),
        }).then((_) {
          setState(() {
            isDeviceConnected = false;
            wasDeviceConnected = false;
          });
          _onConnectionStatusChanged(false, false);
        });
      }

      if (_isFirstLoad && !isDeviceConnected) {
        setState(() {
          messageText = "Please insert your device";
          messageColor = Colors.red;
          showMessage = true;
          _isFirstLoad = false;
        });
        print("Initial message shown at: ${DateTime.now()}");
        _startProgressBar();
      }
    }, onError: (error) {
      print("Error listening to connection status: $error");
      setState(() {
        messageText = "Error checking device connection";
        messageColor = Colors.red;
        showMessage = true;
      });
      _startProgressBar();
    });
  }

  bool lastStoredConnectionStatus = false;

  Future<void> _updateConnectionStatusInFirestore(bool isConnected) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (isConnected == lastStoredConnectionStatus) {
      print("No change in connection status. Skipping Firestore update.");
      return;
    }

    DocumentReference deviceStatusRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('device_status')
        .doc('connection');

    try {
      await deviceStatusRef.set({
        'isDeviceConnected': isConnected,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("Connection status updated in Firestore: $isConnected");
      lastStoredConnectionStatus = isConnected;
    } catch (e) {
      print("Error updating connection status in Firestore: $e");
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    messageTimer?.cancel();
    _connectionListener?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 2) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WalletTab(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    } else if (index == 3) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    } else if (index == 1) {
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MapScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enhanced MediaQuery handling
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isLargeScreen = screenWidth >= 900;

    // Responsive dimensions
    final headerHeight = isLargeScreen ? screenHeight * 0.35 : isTablet ? screenHeight * 0.32 : screenHeight * 0.3;
    final horizontalPadding = isLargeScreen ? screenWidth * 0.05 : isTablet ? screenWidth * 0.04 : screenWidth * 0.035;
    final verticalSpacing = isLargeScreen ? screenHeight * 0.03 : isTablet ? screenHeight * 0.025 : screenHeight * 0.02;
    final cardPadding = isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.035 : screenWidth * 0.03;

    // Responsive font sizes with minimum thresholds
    final welcomeFontSize = (isLargeScreen ? screenWidth * 0.05 : isTablet ? screenWidth * 0.055 : screenWidth * 0.06).clamp(20.0, 32.0);
    final nameFontSize = (isLargeScreen ? screenWidth * 0.05 : isTablet ? screenWidth * 0.055 : screenWidth * 0.06).clamp(20.0, 32.0);
    final titleFontSize = (isLargeScreen ? screenWidth * 0.03 : isTablet ? screenWidth * 0.035 : screenWidth * 0.04).clamp(18.0, 24.0);
    final subtitleFontSize = (isLargeScreen ? screenWidth * 0.025 : isTablet ? screenWidth * 0.03 : screenWidth * 0.035).clamp(16.0, 22.0);
    final valueFontSize = (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(20.0, 28.0);
    final statusFontSize = (isLargeScreen ? screenWidth * 0.022 : isTablet ? screenWidth * 0.025 : screenWidth * 0.03).clamp(14.0, 20.0);

    // Responsive image dimensions
    final imageWidth = screenWidth * (isLargeScreen ? 0.65 : isTablet ? 0.7 : 0.75);
    final imageHeight = isLargeScreen ? screenHeight * 0.32 : isTablet ? screenHeight * 0.3 : screenHeight * 0.28;

    // Responsive icon sizes
    final iconSize = isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.045 : screenWidth * 0.05;
    final smallIconSize = isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: Container(
        width: isLargeScreen ? screenWidth * 0.3 : isTablet ? screenWidth * 0.35 : screenWidth * 0.7,
        child: Drawer(
          backgroundColor: Colors.grey.shade900.withOpacity(0.97),
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                SizedBox(height: isLargeScreen ? screenHeight * 0.06 : isTablet ? screenHeight * 0.05 : screenHeight * 0.045),
                Text(
                  "Toll Seva",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: (isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.045 : screenWidth * 0.05).clamp(22.0, 30.0),
                      fontWeight: FontWeight.bold
                  ),
                ),
                SizedBox(height: verticalSpacing),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: isLargeScreen ? screenHeight * 0.05 : isTablet ? screenHeight * 0.045 : screenHeight * 0.04),
                        _buildDrawerItem(Icons.help, "How It Works", () {
                          _navigateWithFade(context, HowItWorksPage());
                        }),
                        _buildDrawerItem(Icons.warning, "Violation & Penalty Details", () {
                          _navigateWithFade(context, ViolationPenaltyPage());
                        }),
                        _buildDrawerItem(Icons.car_repair, "Roadside Assistance", () {
                          _navigateWithFade(context, RoadsideAssistancePage());
                        }),
                        _buildDrawerItem(Icons.calculate, "Toll Fare Calculator", () {
                          _navigateWithFade(context, TollCalculatorScreen());
                        }),
                        SizedBox(height: isLargeScreen ? screenHeight * 0.08 : isTablet ? screenHeight * 0.07 : screenHeight * 0.06),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Stack(
              children: [
              OBDData(
              onDataUpdated: _updateObdData,
              onConnectionStatusChanged: _onConnectionStatusChanged,
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: IconButton(
                      icon: Icon(Icons.menu, size: 28, color: Colors.white),
                      onPressed: _toggleDrawer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalizedText(
                          text: "Welcome Back,",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "$firstName $lastName",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  Consumer<WalletProvider>(
                    builder: (context, walletProvider, child) {
                      return Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              walletProvider.hasUnreadNotifications
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              size: 28,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => NotificationsPage1(
                                    previousPage: 'Home',
                                    currentIndex: _selectedIndex,
                                  ),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  transitionDuration: Duration(milliseconds: 400),
                                ),
                              ).then((_) {
                                walletProvider.markNotificationsAsRead();
                              });
                            },
                          ),
                          if (walletProvider.hasUnreadNotifications)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  walletProvider.unreadNotificationCount.toString(),
                                  style: TextStyle(fontSize: 12, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: Column(
                  children: [
                    Image.asset(
                      "assets/images/$type/$brand/$model/$color.png",
                      width: MediaQuery.of(context).size.width * 0.8,
                      height: 250,
                      fit: BoxFit.contain,
                    ).animate().slideX(
                      begin: 1.5,
                      end: 0,
                      duration: 1000.ms,
                      curve: Curves.easeOut,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),

                        padding: EdgeInsets.symmetric(
                            horizontal: cardPadding,
                            vertical: cardPadding
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.thermostat, color: Colors.blueAccent.shade400, size: iconSize),
                                SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                                LocalizedText(
                                  text: "Coolant Temperature",
                                  style: GoogleFonts.poppins(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isLargeScreen ? 14 : isTablet ? 12 : 10),
                            Text(
                              "${obdData["Coolant Temp"]!.toStringAsFixed(0)}°C | ${obdData["Coolant Temp"]! > 100 ? "High" : "Normal"}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: valueFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: verticalSpacing),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: isLargeScreen ? screenHeight * 0.25 : isTablet ? screenHeight * 0.24 : screenHeight * 0.23,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                                color: Colors.white.withOpacity(0.9),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: cardPadding * 0.55,
                                  vertical: cardPadding * 0.6
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Transform.translate(
                                        offset: Offset(isLargeScreen ? -14 : isTablet ? -12 : -10, 0),
                                        child: Icon(
                                          Icons.battery_charging_full,
                                          color: Colors.green,
                                          size: smallIconSize,
                                        ),
                                      ),
                                      const SizedBox(width: 0),
                                      LocalizedText(
                                        text: "Battery Voltage",
                                        style: GoogleFonts.poppins(
                                          fontSize: subtitleFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isLargeScreen ? screenHeight * 0.06 : isTablet ? screenHeight * 0.055 : screenHeight * 0.05),
                                  LocalizedText(
                                    text: "Current Voltage",
                                    style: GoogleFonts.poppins(
                                      fontSize: statusFontSize,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: isLargeScreen ? 18 : isTablet ? 16 : 14),
                                  Text(
                                    "${obdData["Battery Voltage"]!.toStringAsFixed(1)}V",
                                    style: GoogleFonts.poppins(
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: isLargeScreen ? 10 : isTablet ? 8 : 6),
                                  LocalizedText(
                                    text: obdData["Battery Voltage"]! > 13.0 ? "Stable" : "Low",
                                    style: GoogleFonts.poppins(
                                      fontSize: statusFontSize,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: isLargeScreen ? 14 : isTablet ? 12 : 10),
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: isLargeScreen ? screenHeight * 0.12 : isTablet ? screenHeight * 0.115 : screenHeight * 0.11,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Transform.translate(
                                        offset: Offset(isLargeScreen ? 8 : isTablet ? 6 : 5, isLargeScreen ? -34 : isTablet ? -30 : -28),
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return const LinearGradient(
                                              colors: [Colors.green, Colors.yellow, Colors.red],
                                              begin: Alignment.bottomLeft,
                                              end: Alignment.topRight,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.speed,
                                            size: smallIconSize,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isLargeScreen ? 14 : isTablet ? 12 : 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          LocalizedText(
                                            text: "  Engine Load",
                                            style: GoogleFonts.poppins(
                                              fontSize: subtitleFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: isLargeScreen ? 8 : isTablet ? 6 : 5),
                                          Text(
                                            "${obdData["Engine Load"]!.toStringAsFixed(0)}%",
                                            style: GoogleFonts.poppins(
                                              fontSize: (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(20.0, 26.0),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          LocalizedText(
                                            text: obdData["Engine Load"]! > 50 ? "High" : "Optimal",
                                            style: GoogleFonts.poppins(
                                              fontSize: statusFontSize,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isLargeScreen ? 14 : isTablet ? 12 : 10),
                                Container(
                                  height: isLargeScreen ? screenHeight * 0.12 : isTablet ? screenHeight * 0.115 : screenHeight * 0.11,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Transform.translate(
                                        offset: Offset(isLargeScreen ? 8 : isTablet ? 6 : 5, isLargeScreen ? -34 : isTablet ? -30 : -28),
                                        child: ShaderMask(
                                          shaderCallback: (Rect bounds) {
                                            return const LinearGradient(
                                              colors: [Colors.blue, Colors.white54],
                                              begin: Alignment.topRight,
                                              end: Alignment.bottomLeft,
                                            ).createShader(bounds);
                                          },
                                          child: Icon(
                                            Icons.ac_unit,
                                            size: smallIconSize,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isLargeScreen ? 14 : isTablet ? 12 : 10),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          LocalizedText(
                                            text: "    Air Intake",
                                            style: GoogleFonts.poppins(
                                              fontSize: subtitleFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          SizedBox(height: isLargeScreen ? 8 : isTablet ? 6 : 5),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                "  ${obdData["Intake Temp"]!.toStringAsFixed(0)}°C",
                                                style: GoogleFonts.poppins(
                                                  fontSize: (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(20.0, 26.0),
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              LocalizedText(
                                                text: "  ${obdData["Intake Temp"]! > 40 ? "Hot" : "Efficient"}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: statusFontSize,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? screenHeight * 0.06 : isTablet ? screenHeight * 0.055 : screenHeight * 0.05),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? screenWidth * 0.06 : isTablet ? screenWidth * 0.055 : screenWidth * 0.05,
                            vertical: cardPadding
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment,
                                  color: Colors.redAccent,
                                  size: smallIconSize,
                                ),
                                SizedBox(width: isLargeScreen ? 14 : isTablet ? 12 : 10),
                                LocalizedText(
                                  text: "View your DTC Report",
                                  style: GoogleFonts.poppins(
                                    fontSize: (isLargeScreen ? screenWidth * 0.035 : isTablet ? screenWidth * 0.04 : screenWidth * 0.045).clamp(20.0, 26.0),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isLargeScreen ? 14 : isTablet ? 12 : 10),
                            Center(
                              child: ElevatedButton(
                                onPressed: _generateDtcReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isLargeScreen ? screenWidth * 0.04 : isTablet ? screenWidth * 0.045 : screenWidth * 0.05,
                                      vertical: isLargeScreen ? 14 : isTablet ? 12 : 10
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download, color: Colors.white, size: isLargeScreen ? 26 : isTablet ? 24 : 22),
                                    SizedBox(width: isLargeScreen ? 12 : isTablet ? 10 : 8),
                                    LocalizedText(
                                      text: "Download Report",
                                      style: GoogleFonts.poppins(
                                        fontSize: subtitleFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 12 : isTablet ? 10 : 8),
                  ],
                ),
              ],
            ),
          ),
          if (showMessage)
            Positioned(
              top: isLargeScreen ? screenHeight * 0.18 : isTablet ? screenHeight * 0.17 : screenHeight * 0.16,
              left: 0,
              right: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * (isLargeScreen ? 0.55 : isTablet ? 0.6 : 0.75),
                  ),
                  child: AnimatedSlide(
                    offset: showMessage ? Offset(0, 0) : Offset(0, -1),
                    duration: Duration(milliseconds: 300),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          vertical: isLargeScreen ? 16 : isTablet ? 14 : 12,
                          horizontal: isLargeScreen ? 20 : isTablet ? 18 : 16
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            messageText,
                            style: GoogleFonts.poppins(
                              color: messageColor,
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isLargeScreen ? 8 : isTablet ? 6 : 5),
                          LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(messageColor),
                            minHeight: isLargeScreen ? 6 : isTablet ? 5 : 4,
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
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 25,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            showSelectedLabels: true,
            showUnselectedLabels: false,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
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
  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: LocalizedText(text: title, style: TextStyle(color: Colors.white, fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
  void _navigateWithFade(BuildContext context, Widget page) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ));
  }
  Widget _buildCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required String value,
    String? extra,
    Color iconColor = Colors.black,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-10, 0),
                child: Icon(
                  icon,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 0),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                extra,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  Color _getIconColor(IconData icon) {
    if (icon == Icons.battery_full) {
      return Colors.green;
    } else if (icon == Icons.cloud) {
      return Colors.lightBlueAccent;
    }
    return Colors.black54;
  }
  BottomNavigationBarItem _buildNavItem(
      IconData filledIcon, IconData outlinedIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: _selectedIndex == index
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        child: Icon(filledIcon, color: Colors.white),
      )
          : Icon(outlinedIcon, color: Colors.white),
      label: _selectedIndex == index ? label : "",
    );
  }
}