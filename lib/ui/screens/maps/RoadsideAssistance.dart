import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../widgets/localized_text_widget.dart';



class RoadsideAssistancePage extends StatefulWidget {
  @override
  _RoadsideAssistancePageState createState() => _RoadsideAssistancePageState();
}

class _RoadsideAssistancePageState extends State<RoadsideAssistancePage> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  bool _locationFetched = false;
  bool _isLoading = true;
  BitmapDescriptor? _carIcon;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  String _locationStatus = "Getting your location...";

  // Draggable sheet controller
  DraggableScrollableController _draggableController = DraggableScrollableController();

  // Nearby service locations (example data)
  final List<Map<String, dynamic>> _nearbyServices = [
    {
      'name': 'City Towing Service',
      'position': LatLng(37.4219999, -122.0840575), // Will be updated relative to user location
      'type': 'towing',
      'phone': '18001234568',
      'distance': '1.2 km'
    },
    {
      'name': 'Quick Repair Garage',
      'position': LatLng(37.4219999, -122.0862575), // Will be updated relative to user location
      'type': 'repair',
      'phone': '18001234569',
      'distance': '2.5 km'
    },
    {
      'name': 'Highway Gas Station',
      'position': LatLng(37.4230999, -122.0840575), // Will be updated relative to user location
      'type': 'gas',
      'phone': '18001234570',
      'distance': '3.1 km'
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _getCurrentLocation();
  }

  Future<void> _loadCarIcon() async {
    final iconData = Icons.directions_car;
    _carIcon = await _bitmapDescriptorFromIcon(iconData, Colors.red, 100);

    // Also load other service icons
    await _loadServiceIcons();
  }

  Future<void> _loadServiceIcons() async {
    // This would be implemented to load different icons for different service types
    // For now, we'll use the default markers with different hues
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIcon(
      IconData iconData, Color color, double size) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
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
    setState(() {
      _isLoading = true;
      _locationStatus = "Getting your location...";
    });

    try {
      Position? position = await _fetchLocation();
      if (position != null) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationFetched = true;
          _isLoading = false;
          _locationStatus = "Location found";
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 16));

        // Update markers and circles
        _updateMapFeatures();
      } else {
        setState(() {
          _isLoading = false;
          _locationStatus = "Unable to get location";
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _locationStatus = "Location error: ${e.toString()}";
      });
    }
  }

  void _updateMapFeatures() {
    if (_currentLocation == null) return;

    // Create a set of markers
    Set<Marker> markers = {};

    // Add user's current location marker
    markers.add(
      Marker(
        markerId: MarkerId("current_location"),
        position: _currentLocation!,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: "Your Location",
          snippet: "Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}, Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}",
        ),
      ),
    );

    // Add nearby service markers
    for (int i = 0; i < _nearbyServices.length; i++) {
      // Calculate position relative to user's location
      final offset = 0.002 * (i + 1); // Approximately 200m per increment
      final servicePosition = LatLng(
        _currentLocation!.latitude + (i % 2 == 0 ? offset : -offset),
        _currentLocation!.longitude + (i % 3 == 0 ? offset : -offset),
      );

      // Update the service position
      _nearbyServices[i]['position'] = servicePosition;

      // Add marker
      BitmapDescriptor markerIcon;
      switch(_nearbyServices[i]['type']) {
        case 'towing':
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
          break;
        case 'repair':
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
          break;
        case 'gas':
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
          break;
        default:
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
      }

      markers.add(
        Marker(
          markerId: MarkerId("service_$i"),
          position: servicePosition,
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: _nearbyServices[i]['name'],
            snippet: "Distance: ${_nearbyServices[i]['distance']} • Tap to call",
            onTap: () => _makeCall(_nearbyServices[i]['phone']),
          ),
        ),
      );
    }

    // Add a circle around user's location
    Set<Circle> circles = {};
    circles.add(
      Circle(
        circleId: CircleId("radius"),
        center: _currentLocation!,
        radius: 500, // 500 meters radius
        fillColor: Colors.blue.withOpacity(0.1),
        strokeColor: Colors.blue.withOpacity(0.5),
        strokeWidth: 2,
      ),
    );

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  Future<void> _requestHelpViaSMS() async {
    if (_currentLocation == null) {
      _showSnackBar("Location not available");
      return;
    }

    String locationUrl =
        "https://www.google.com/maps/search/?api=1&query=${_currentLocation!.latitude},${_currentLocation!.longitude}";
    String message = "🚨 EMERGENCY: I need roadside assistance! My location: $locationUrl";

    Uri smsUri = Uri.parse("sms:18001234567?body=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        _showSnackBar("Cannot send SMS");
      }
    } catch (e) {
      _showSnackBar("Error sending SMS: $e");
    }
  }

  Future<Position?> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showSnackBar("Location services are disabled");
      // Open system location settings
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Location permission denied");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar("Location permissions permanently denied");
      // Open app settings so the user can manually enable location access
      await Geolocator.openAppSettings();
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _makeCall(String number) async {
    final Uri phoneUri = Uri.parse("tel:$number");
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showSnackBar("Cannot make call to $number");
      }
    } catch (e) {
      _showSnackBar("Error making call: $e");
    }
  }

  Future<void> _shareLocationViaWhatsApp() async {
    if (_currentLocation == null) {
      _showSnackBar("Location not available");
      return;
    }

    String locationUrl =
        "https://www.google.com/maps/search/?api=1&query=${_currentLocation!.latitude},${_currentLocation!.longitude}";
    String message = "🚨 I need roadside assistance! My location: $locationUrl";

    Uri whatsappUri = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar("WhatsApp not available");
      }
    } catch (e) {
      _showSnackBar("Error opening WhatsApp: $e");
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
            child: LocalizedText(
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
            text: label,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyServicesList() {
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _nearbyServices.length,
        itemBuilder: (context, index) {
          final service = _nearbyServices[index];

          IconData iconData;
          Color iconColor;

          switch(service['type']) {
            case 'towing':
              iconData = Icons.car_repair;
              iconColor = Colors.blue;
              break;
            case 'repair':
              iconData = Icons.build;
              iconColor = Colors.green;
              break;
            case 'gas':
              iconData = Icons.local_gas_station;
              iconColor = Colors.amber;
              break;
            default:
              iconData = Icons.location_on;
              iconColor = Colors.purple;
          }

          return GestureDetector(
            onTap: () {
              // Center map on this service
              _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(service['position'], 17)
              );
            },
            child: Container(
              width: 150,
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(iconData, color: iconColor, size: 20),
                      SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          service['name'],
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Distance: ${service['distance']}",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        service['phone'],
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _makeCall(service['phone']),
                        child: Icon(Icons.call, color: iconColor, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
            child: _locationFetched && _currentLocation != null
                ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation!,
                zoom: 17,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Apply custom map style if needed
                // _setMapStyle(controller);
              },
              markers: _markers,
              circles: _circles,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
              compassEnabled: true,
            )
                : Container(
              color: Colors.grey[800],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      CircularProgressIndicator(color: Colors.redAccent),
                    SizedBox(height: 16),
                    Text(
                      _locationStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (!_isLoading && !_locationFetched) ...[
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: Text(
                          "Retry",
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
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

          // Refresh Location Button
          Positioned(
            top: 40,
            right: 15,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.my_location, color: Colors.white, size: 30),
              ),
            ),
          ),

          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.4,
            minChildSize: 0.2,
            maxChildSize: 0.8,
            builder: (context, scrollController) {
              return Container(
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
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle
                        Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        SizedBox(height: 15),

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

                        // Nearby Services
                        if (_locationFetched) ...[
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Colors.white70, size: 18),
                              SizedBox(width: 5),
                              Text(
                                "Nearby Services",
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          _buildNearbyServicesList(),
                          SizedBox(height: 15),
                        ],

                        // Emergency Contacts
                        Column(
                          children: [
                            _buildEmergencyCard("Highway Toll Helpline", "18001234567", Icons.local_phone, Colors.green),
                            _buildEmergencyCard("Police Assistance", "100", Icons.local_police, Colors.blue),
                            _buildEmergencyCard("Ambulance", "108", Icons.health_and_safety, Colors.red),
                          ],
                        ),

                        SizedBox(height: 15),

                        // Action Buttons (SMS button moved to where Navigate was)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(Icons.share_location, "Share Location", Colors.blue, _shareLocationViaWhatsApp),
                            _buildActionButton(Icons.sms, "SMS Help", Colors.orange, _requestHelpViaSMS),
                          ],
                        ),

                        // Add some bottom padding for better scrolling experience
                        SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draggableController.dispose();
    super.dispose();
  }

// Optional: Apply custom map style
// Future<void> _setMapStyle(GoogleMapController controller) async {
//   String style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
//   controller.setMapStyle(style);
// }
}