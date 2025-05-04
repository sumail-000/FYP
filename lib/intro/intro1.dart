import 'package:flutter/material.dart';
import 'intro2.dart';
import '../auth/login.dart';

class IntroductionScreen1 extends StatelessWidget {
  const IntroductionScreen1({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;
    final double logoSize = screenSize.width * 0.3;
    final double illustrationWidth = screenSize.width * 0.8;

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        Container(
          height: screenSize.height * 0.15,
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

        SizedBox(height: screenSize.height * 0.03),

        // Illustration
        Image.asset(
          'assets/screen2.png',
          width: illustrationWidth,
          fit: BoxFit.contain,
        ),

        SizedBox(height: screenSize.height * 0.02),

        // Heading
        const Text(
          'Seamless Notes Sharing',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF125F9D),
          ),
        ),

        SizedBox(height: screenSize.height * 0.01),

        // Paragraph
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            'Easily share and access study materials, notes, and assignments. '
                'Filter by university, department, and semester for quick retrieval.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF125F9D),
            ),
          ),
        ),

        const Spacer(),

        // Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Next Button
              SizedBox(
                width: screenSize.width * 0.8,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D7FBA),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF125F9D).withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IntroductionScreen2(),
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

              SizedBox(height: screenSize.height * 0.02),

              // Skip Button
              SizedBox(
                width: screenSize.width * 0.8,
                height: 50,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F4F4),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFFF5F5F5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 22,
                        color: Color(0xFF125F9D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: screenSize.height * 0.03),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLandscape
            ? SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: screenSize.height),
            child: IntrinsicHeight(child: content),
          ),
        )
            : content,
      ),
    );
  }
}
