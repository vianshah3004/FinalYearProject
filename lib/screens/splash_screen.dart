import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:new_ui/main.dart';
import 'backup_splash.dart';// Import main to access AuthCheck

class TollAnimationScreen extends StatefulWidget {
  const TollAnimationScreen({Key? key}) : super(key: key);

  @override
  _TollAnimationScreenState createState() => _TollAnimationScreenState();
}

class _TollAnimationScreenState extends State<TollAnimationScreen> {
  late VideoPlayerController _videoPlayerController;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.asset(
        'assets/images/toll_animation.mp4',
      );

      await _videoPlayerController.initialize();
      await _videoPlayerController.setLooping(false);
      await _videoPlayerController.setVolume(0.0);
      await _videoPlayerController.play();

      setState(() {
        _isInitialized = true;
      });

      Timer(
        _videoPlayerController.value.duration ?? const Duration(seconds: 5),
            () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AuthCheck()), // ✅ Navigate to AuthCheck
            );
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      print('Error initializing video: $e');

      Timer(const Duration(seconds: 9), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AuthCheck()), // ✅ Navigate to AuthCheck
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _errorMessage != null
            ? Text(
          'Error: $_errorMessage',
          style: GoogleFonts.poppins(color: Colors.red),
          textAlign: TextAlign.center,
        )
            : _isInitialized
            ? SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: VideoPlayer(_videoPlayerController),
        )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
