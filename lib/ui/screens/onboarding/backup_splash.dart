import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'dart:async';
import 'package:new_ui/main.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..addListener(() {
      setState(() {});
    });

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => AuthCheck(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade900, Colors.black],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // "Toll Seva" at Top Left
          Positioned(
            top: 530,
            left: 20,
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Toll Seva',
                  textStyle: TextStyle(
                    fontSize: 70.0,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DancingScript',
                    color: Colors.white,
                  ),
                  speed: Duration(milliseconds: 150),
                ),
              ],
              totalRepeatCount: 1,
            ),
          ),

          // "Apka Safar, Humari Seva" at Bottom Right
          Positioned(
            bottom: 220,
            right: 20,
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Apka Safar, Humari Seva',
                  textStyle: TextStyle(
                    fontSize: 30.0,
                    fontFamily: 'DancingScript',
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  speed: Duration(milliseconds: 100),
                ),
              ],
              totalRepeatCount: 1,
            ),
          ),

          // Centered Logo
          // Centered Logo with Animation
          Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/main_logo_2.png',
                width: 190,
                height: 190,
                fit: BoxFit.cover,
              ),
            ),
          ),


          // Progress Bar at the Bottom
          Positioned(
            bottom: 200,
            left: 30,
            right: 30,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: _controller.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.purpleAccent, Colors.blueAccent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // "Loading..." text below Progress Bar
        ],
      ),
    );
  }
}
