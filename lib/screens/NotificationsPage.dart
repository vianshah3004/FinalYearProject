import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:permission_handler/permission_handler.dart';

import '../localized_text_widget.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    PermissionStatus status = await Permission.notification.status;
    bool isAllowed = status.isGranted;
    bool savedState = prefs.getBool('notifications_enabled') ?? true;

    setState(() {
      _notificationsEnabled = isAllowed && savedState;
    });

    print("System Notification Permission: $isAllowed");
    print("Saved Notification Preference: $savedState");
  }

  Future<void> _toggleNotifications(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    setState(() {
      _notificationsEnabled = value;
    });

    if (value) {
      _requestNotificationPermission();
      FirebaseMessaging.instance.subscribeToTopic("all_users");
      _triggerVibration();
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic("all_users");
    }
  }

  Future<void> _requestNotificationPermission() async {
    PermissionStatus status = await Permission.notification.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      _showSettingsDialog();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const LocalizedText(
            text:"Permission Required"),
        content: const LocalizedText(
            text:"Enable notifications in system settings to receive alerts."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LocalizedText(
                text:"Cancel"),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const LocalizedText(
                text:"Open Settings"),
          ),
        ],
      ),
    );
  }

  void _triggerVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 300);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title:LocalizedText(
          text: "Notifications",
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Soft Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFfdfbfb), Color(0xFFebedee)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7), // Soft glass effect
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// **Animated Icon**
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: _notificationsEnabled
                          ? BounceIn(
                        child: Icon(Icons.notifications_active,
                            key: ValueKey(1), size: 80, color: Colors.blueAccent),
                      )
                          : FadeIn(
                        child: Icon(Icons.notifications_off,
                            key: ValueKey(2), size: 80, color: Colors.redAccent.shade200),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// **Title**
                    LocalizedText(
                      text: "Enable Notifications",
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),

                    /// **Status Message**
                    LocalizedText(
                      text:  _notificationsEnabled
                          ? "Stay updated with real-time alerts and updates."
                          : "Turn off notifications to stop receiving alerts.",
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),

                    /// **Modern Green Toggle Button**
                    GestureDetector(
                      onTap: () => _toggleNotifications(!_notificationsEnabled),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 80,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: _notificationsEnabled
                                ? [Colors.blue.shade200, Colors.blue.shade500]
                                : [Colors.red.shade100, Colors.red.shade200],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            AnimatedAlign(
                              duration: const Duration(milliseconds: 300),
                              alignment:
                              _notificationsEnabled ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 35,
                                height: 35,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, animation) =>
                                        ScaleTransition(scale: animation, child: child),
                                    child: Icon(
                                      _notificationsEnabled ? Icons.notifications : Icons.notifications_off,
                                      key: ValueKey<bool>(_notificationsEnabled),
                                      color: _notificationsEnabled ? Colors.blue : Colors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}
