import 'package:flutter/material.dart';
import 'how_it_works_1.dart';
import 'how_it_works_2.dart';
import 'how_it_works_3.dart';
import 'how_it_works_4.dart';
import 'how_it_works_5.dart';
import 'home_screen.dart'; // Replace with your target screen

class HowItWorksPage extends StatefulWidget {
  @override
  _HowItWorksPageState createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  final PageController _pageController = PageController(initialPage: 0);
  final ValueNotifier<double> _currentPage = ValueNotifier<double>(0.0); // Corrected to double

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeController.forward();
    _pageController.addListener(_updatePageIndicator);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.removeListener(_updatePageIndicator);
    _pageController.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  void _updatePageIndicator() {
    if (_pageController.page != null) {
      _currentPage.value = _pageController.page!; // Ensure double value
    }
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
          // Fixed status indicator with smooth transition
          Positioned(
            bottom: 180,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: _currentPage,
                builder: (context, pageValue, child) {
                  int currentIndex = pageValue.floor();
                  double progress = pageValue - currentIndex;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final isActive = index == currentIndex || (index == currentIndex + 1 && progress > 0);
                      final isTransitioning = index == currentIndex + 1 && progress > 0;
                      final animationValue = isTransitioning ? progress : (isActive ? 1.0 : 0.0);

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        width: 10 + (10 * animationValue), // Grow from 10 to 20
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(isActive ? 1.0 : 0.3),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: isActive
                              ? [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              offset: Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ),
          // SKIP button
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
          // NEXT/FINISH button
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
                    duration: Duration(milliseconds: 10),
                    curve: Curves.easeInOut,
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