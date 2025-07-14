import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import 'how_it_works_1.dart';
import 'how_it_works_2.dart';
import 'how_it_works_3.dart';
import 'how_it_works_4.dart';
import 'how_it_works_5.dart';

class HowItWorksPage extends StatefulWidget {
  @override
  _HowItWorksPageState createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> with TickerProviderStateMixin {
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeController,
            child: PageView(
              controller: _pageController,
              scrollDirection: Axis.horizontal,
              children: [
                HowItWorksPage1(pageController: _pageController),
                HowItWorksPage2(pageController: _pageController),
                HowItWorksPage3(pageController: _pageController),
                HowItWorksPage4(pageController: _pageController),
                HowItWorksPage5(pageController: _pageController),
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
                if (_pageController.page!.round() < 4) {
                  _pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                  );
                } else {
                  Navigator.of(context).push(_createFadeRoute());
                }
              },
              child: Text(_pageController.hasClients && _pageController.page!.round() == 4 ? 'FINISH' : 'NEXT'),
            ),
          ),
        ],
      ),
    );
  }

  Route _createFadeRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}