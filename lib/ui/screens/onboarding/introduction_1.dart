import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import 'introduction_2.dart'; // Import IntroductionPage2
import 'introduction_3.dart';


class IntroductionPage extends StatefulWidget {
  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  final PageController _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeController,
            child: PageView(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              children: [
                _buildIntroductionPage1(context),
                IntroductionPage2(pageController: _pageController),
                IntroductionPage3(pageController: _pageController),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(_createFadeRoute());
              },
              child: Text(
                'SKIP',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_pageController.page!.round() < 2) {
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                } else {
                  // Optional: Navigate to the next screen after intro
                }
              },
              child: Text(_pageController.hasClients && _pageController.page!.round() == 2 ? 'FINISH' : 'NEXT'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroductionPage1(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TollSeva Welcomes You!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'With TollSeva, be effortless in your journey.\nAll the time. Everywhere.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32),
          Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -50,
                left: -50,
                child: Icon(Icons.home, size: 60, color: Colors.blue),
              ),
              Positioned(
                top: -50,
                right: -50,
                child: Icon(Icons.directions_car, size: 60, color: Colors.blue),
              ),
              Positioned(
                bottom: -50,
                left: -50,
                child: Icon(Icons.people, size: 60, color: Colors.blue),
              ),
              Positioned(
                bottom: -50,
                right: -50,
                child: Icon(Icons.pets, size: 60, color: Colors.blue),
              ),
              Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1000),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/Start1.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(true),
              SizedBox(width: 8),
              _buildDot(false),
              SizedBox(width: 8),
              _buildDot(false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? Colors.black : Colors.grey,
      ),
    );
  }
}
Route _createFadeRoute() {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 200), // Adjust duration for smoothness
    pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

