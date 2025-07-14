import 'package:flutter/material.dart';

class HowItWorksPage2 extends StatelessWidget {
  final PageController pageController;

  HowItWorksPage2({required this.pageController});

  @override
  Widget build(BuildContext context) {
    return _buildHowItWorksPage2(context);
  }

  Widget _buildHowItWorksPage2(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Track Your Journey with GPS!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Our GPS technology automatically detects tolls\nas you drive, ensuring accurate tracking.',
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
                    'assets/images/how_it_works_2.png',
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
              _buildDot(false),
              SizedBox(width: 8),
              _buildDot(true),
              SizedBox(width: 8),
              _buildDot(false),
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