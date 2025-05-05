import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'intro/intro1.dart';
import 'auth/login.dart';
import 'auth/signup.dart';
import 'auth/reset_password.dart';
import 'dashboard/dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth/auth_service.dart';
import 'auth/auth_state_wrapper.dart';
import 'config/env_config.dart';
import 'upload/upload_screen.dart';
// DocumentsScreen will be implemented later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize EnvConfig to load Cloudinary credentials
  await EnvConfig.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Academia Hub',
      theme: ThemeData(
        primaryColor: Color(0xFF125F9D),
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/intro': (context) => const IntroductionScreen1(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/reset-password': (context) => ResetPasswordScreen(),
        '/home': (context) => AuthStateWrapper(),
        '/upload': (context) => UploadScreen(),
        // Documents screen will be implemented later
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    // Check if user is already logged in
    Future.delayed(Duration.zero, () async {
      if (_authService.currentUser != null) {
        // Check if profile is complete before navigating
        bool isProfileComplete = await _authService.isProfileComplete();
        if (mounted) {
          // User is already logged in, navigate to home which will handle profile completion check
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Navigate to IntroductionScreen after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/intro');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F95A2), // Background color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/Logo.png', // Ensure the file exists in assets
              width: 400, // Adjust size as needed
            ),
          ],
        ),
      ),
    );
  }
}