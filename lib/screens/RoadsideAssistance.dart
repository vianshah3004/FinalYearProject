import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../localized_text_widget.dart';

class RoadsideAssistancePage extends StatefulWidget {
  @override
  _RoadsideAssistancePageState createState() => _RoadsideAssistancePageState();
}

class _RoadsideAssistancePageState extends State<RoadsideAssistancePage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _locationFetched = false;
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _getCurrentLocation();
  }

  Future<void> _loadCarIcon() async {
    final iconData = Icons.directions_car;
    _carIcon = await _bitmapDescriptorFromIcon(iconData, Colors.red, 100);
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIcon(
      IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.redAccent,
      ),
    );

    textPainter.layout();
    textPainter.paint(
        canvas, Offset(size / 2 - textPainter.width / 2, size / 2 - textPainter.height / 2));

    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<void> _getCurrentLocation() async {
    Position? position = await _fetchLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationFetched = true;
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));
    }
  }

  Future<void> _requestHelpViaSMS() async {
    if (_currentLocation == null) return;

    String locationUrl =
        "https://www.google.com/maps/search/?api=1&query=${_currentLocation!.latitude},${_currentLocation!.longitude}";
    String message = "I need roadside assistance! My location: $locationUrl";

    Uri smsUri = Uri.parse("sms:18001234567?body=$message");

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<Position?> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // if (!serviceEnabled) {
    //   // Open system location settings (shows the default system prompt)
    //   Geolocator.openLocationSettings();
    //   return null;
    // }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      while (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission(); // Exit if permission is denied again
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Open app settings so the user can manually enable location access
      Geolocator.openAppSettings();
      return null;
    }

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }


  void _makeCall(String number) async {
    final Uri phoneUri = Uri.parse("tel:$number");
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print("Could not launch $number");
    }
  }

  Future<void> _shareLocationViaWhatsApp() async {
    if (_currentLocation == null) return;

    String locationUrl =
        "https://www.google.com/maps/search/?api=1&query=${_currentLocation!.latitude},${_currentLocation!.longitude}";
    String message = "I need roadside assistance! My location: $locationUrl";

    Uri whatsappUri = Uri.parse("https://wa.me/?text=$message");

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri);
    } else {
      print("Could not open WhatsApp");
    }
  }

  Widget _buildEmergencyCard(String title, String number, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(width: 15),
          Expanded(
            child:LocalizedText(
              text: title,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => _makeCall(number),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Icon(Icons.call, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          SizedBox(height: 5),
          LocalizedText(
            text:  label,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Google Maps
          Positioned.fill(
            top: 0,
            left: 0,
            right: 0,
            bottom: 350,
            child: _locationFetched && _currentLocation != null
                ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 17,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                Marker(
                  markerId: MarkerId("current_location"),
                  position: _currentLocation!,
                  icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                ),
              },
            )
                : Center(child: CircularProgressIndicator()),
          ),

          // Back Button
          Positioned(
            top: 40,
            left: 15,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              ),
            ),
          ),

          // Bottom Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF232526), Color(0xFF414345)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 15,
                    spreadRadius: 3,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.car_repair, color: Colors.redAccent, size: 30),
                      SizedBox(width: 10),
                      LocalizedText(
                        text: "Roadside Assistance",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),

                  // Emergency Contacts
                  Column(
                    children: [
                      _buildEmergencyCard("Highway Toll Helpline", "18001234567", Icons.local_phone, Colors.green),
                      _buildEmergencyCard("Police Assistance", "100", Icons.local_police, Colors.blue),
                      _buildEmergencyCard("Ambulance", "108", Icons.health_and_safety, Colors.red),
                    ],
                  ),

                  SizedBox(height: 15),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton(Icons.share_location, "Share Location", Colors.blue, _shareLocationViaWhatsApp),
                      _buildActionButton(Icons.sms, "SMS Help", Colors.orange, _requestHelpViaSMS),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
