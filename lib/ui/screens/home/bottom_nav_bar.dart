import 'package:flutter/material.dart';
import '../maps/map_google.dart';
import '../profile/profile_page.dart';
import 'dashboard/wallet_screen.dart';
import 'home_screen.dart';


class BottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const BottomNavBar({Key? key, required this.selectedIndex}) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    if (index == selectedIndex) return; // Prevent unnecessary navigation

    Widget screen;
    switch (index) {
      case 0:
        screen = HomeScreen();
        break;
      case 1:
        screen = MapScreen();
        break;
      case 2:
        screen = WalletTab();
        break;
      case 3:
        screen = ProfileScreen();
        break;
      default:
        screen = HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal:0, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
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
            currentIndex: selectedIndex,
            onTap: (index) => _onItemTapped(context, index),
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

  BottomNavigationBarItem _buildNavItem(IconData filledIcon, IconData outlinedIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: selectedIndex == index
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        child: Icon(filledIcon, color: Colors.white),
      )
          : Icon(outlinedIcon, color: Colors.white),
      label: selectedIndex == index ? label : "",
    );
  }
}
