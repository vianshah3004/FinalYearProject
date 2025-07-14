import 'package:flutter/material.dart';
import 'dart:async';

class ObdPortLocatorPage extends StatefulWidget {
  const ObdPortLocatorPage({super.key});

  @override
  State<ObdPortLocatorPage> createState() => _ObdPortLocatorPageState();
}

class _ObdPortLocatorPageState extends State<ObdPortLocatorPage> with SingleTickerProviderStateMixin {
  bool _isFirstPage = true;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward(from: 1.0); // Start with content fully visible

    // Start the 10-second timer for automatic navigation
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _togglePage(isForward: _isFirstPage);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer to prevent memory leaks
    _controller.dispose();
    super.dispose();
  }

  void _togglePage({required bool isForward}) {
    setState(() {
      _isFirstPage = isForward ? false : true;
      // Update slide direction based on navigation
      _slideAnimation = Tween<Offset>(
        begin: isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      );
    });
    _controller.forward(from: 0.0); // Trigger animations
  }

  void _handleSwipe(DragEndDetails details) {
    // Detect swipe direction based on velocity
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! < -300 && _isFirstPage) {
        // Swipe left on first page -> go to second page
        _togglePage(isForward: true);
      } else if (details.primaryVelocity! > 300 && !_isFirstPage) {
        // Swipe right on second page -> go back to first page
        _togglePage(isForward: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: GestureDetector(
        onHorizontalDragEnd: _handleSwipe,
        child: Stack(
          children: [
            Column(
              children: [
                // Top semi-circle section with black background
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.elliptical(180, 70),
                      bottomRight: Radius.elliptical(180, 70),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 0.0),
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Image.asset(
                                _isFirstPage
                                    ? 'assets/images/OBD_locate_insert_1.png'
                                    : 'assets/images/Start_ignition_3.png',
                                width: _isFirstPage ? 340 : 300,
                                height: _isFirstPage ? 340 : 300,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Adding OBD-II text on top right of the image (only for first page)
                      if (_isFirstPage)
                        Positioned(
                          top: 111,
                          right: 35,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OBD-II',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w100,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 90),

                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              _isFirstPage
                                  ? 'Possible OBD-II port locations'
                                  : 'Connecting to OBD-II Device',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Text(
                                _isFirstPage
                                    ? "Locate your vehicle's OBD-II port based on its make and model, then insert the OBD device into the port."
                                    : "Turn on your vehicle, apply acceleration, and wait 4–5 minutes for the OBD device to connect with the app.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isFirstPage ? Colors.black : Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isFirstPage ? Colors.black.withOpacity(0.3) : Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Back button at top left (visible only on second page)
            if (!_isFirstPage)
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () => _togglePage(isForward: false),
                ),
              ),

            // Centered Next button
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isFirstPage ? () => _togglePage(isForward: true) : () {}, // Empty action for second page
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}