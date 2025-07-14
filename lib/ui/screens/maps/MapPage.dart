import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../home/dashboard/wallet_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_page.dart';


class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  int _selectedIconIndex = 1; // Map is selected by default
  LatLng? _currentLocation;
  String? _locationName = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _locationName = "${place.locality}, ${place.administrativeArea}, ${place.country}";
        });
      } else {
        setState(() {
          _locationName = "Unknown location";
        });
      }
    } catch (e) {
      print("Error getting location: $e");
      setState(() {
        _locationName = "Location not found";
      });
    }
  }


  void _onItemTapped(int index) {
    if (index == _selectedIconIndex) return;

    setState(() {
      _selectedIconIndex = index;
    });

    Widget page;
    if (index == 0) {
      page = HomeScreen();
    } else if (index == 2) {
      page = WalletTab();
    } else if (index == 3) {
      page = ProfileScreen();
    } else {
      return;
    }

    Navigator.of(context).pushReplacement(_fadeRoute(page));
  }

  Route _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // **MAP**
          Positioned.fill(
            child: _currentLocation != null
                ? FlutterMap(
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 17.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.redAccent.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                                stops: [0.2, 1.0],
                              ),
                            ),
                          ),
                          Icon(
                            Icons.directions_car,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
                : Center(child: CircularProgressIndicator()),
          ),

          // **BACK BUTTON**
          Positioned(
            top: 40,
            left: 15,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // **BOTTOM INFO CARD**
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_pin, color: Colors.redAccent),
                  SizedBox(width: 10),
                  Text(
                    _locationName ?? "Fetching location...",
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // **Custom Rounded Bottom Navigation Bar**
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black, // Background color of the container
          borderRadius: BorderRadius.circular(30), // Rounded edges
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 25,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed, // Ensures no shifting mode
            backgroundColor: Colors.transparent, // Prevents white background issue
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            showSelectedLabels: true,
            showUnselectedLabels: false,
            currentIndex: _selectedIconIndex,
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

  BottomNavigationBarItem _buildNavItem(
      IconData filledIcon, IconData outlinedIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: _selectedIconIndex == index
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        child: Icon(filledIcon, color: Colors.white),
      )
          : Icon(outlinedIcon, color: Colors.white),
      label: _selectedIconIndex == index ? label : "",
    );
  }
}
