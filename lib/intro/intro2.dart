import 'package:flutter/material.dart';
import 'intro3.dart'; // Import intro3.dart from same directory
import '../auth/login.dart'; // Updated import path for login.dart

class IntroductionScreen2 extends StatelessWidget {
  const IntroductionScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final Size screenSize = MediaQuery.of(context).size;
    final double logoSize = screenSize.width * 0.3; // 30% of screen width
    final double illustrationWidth = screenSize.width * 0.8; // 80% of screen width
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo at the top with flexible container
            Container(
              height: screenSize.height * 0.15, // 15% of screen height
              padding: const EdgeInsets.only(top: 5.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/Logo.png',
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            SizedBox(height: screenSize.height * 0.03), // 3% of screen height

            // Illustration Image with responsive width
            Image.asset(
              'assets/screen3.png',
              width: illustrationWidth,
              fit: BoxFit.contain,
            ),

            SizedBox(height: screenSize.height * 0.02), // 2% of screen height

            // Heading
            const Text(
              'Interactive Discussions & Live Chat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF125F9D),
              ),
            ),

            SizedBox(height: screenSize.height * 0.01), // 1% of screen height

            // Paragraph
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30), // Center text
              child: Text(
                'Engage in meaningful discussions with peers and instructors.'
                    'Participate in live chat rooms for assignments and get real-time assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF125F9D),
                ),
              ),
            ),

            const Spacer(), // Push buttons to the bottom

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Next Button with Shadow Effect
                  SizedBox(
                    width: screenSize.width * 0.8, // 80% of screen width
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D7FBA), // Slightly lighter version of 0xFF0F95A2
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF125F9D).withOpacity(0.3), // Softer shadow
                            spreadRadius: 1,
                            blurRadius: 6, // Increase blur for softer effect
                            offset: const Offset(0, 4), // Shadow direction
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Transparent to inherit container color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          // Navigate to Next Screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IntroductionScreen3(),
                            ),
                          );
                        },
                        child: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: screenSize.height * 0.02), // 2% of screen height

                  // Skip Button with Shadow Effect
                  SizedBox(
                    width: screenSize.width * 0.8, // 80% of screen width
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F4F4), // Light grey background
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5), // Lighter shadow for skip button
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 6), // Push shadow downward
                          ),
                        ],
                      ),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Transparent to inherit container color
                          side: const BorderSide(color: Color(0xFFF5F5F5)), // Border color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: () {
                          // Skip to Home Screen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF125F9D), // Correct text color
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: screenSize.height * 0.03), // 3% of screen height
          ],
        ),
      ),
    );
  }
}