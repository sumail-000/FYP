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
import 'profile/profile_screen.dart';
import 'friend_requests/friend_requests_screen.dart';
import 'friends/friends_screen.dart';
import 'chatbot/chatbot_screen.dart';
import 'services/activity_points_service.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
// DocumentsScreen will be implemented later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
        '/profile': (context) => ProfileScreen(),
        '/friend_requests': (context) => FriendRequestsScreen(),
        '/friends': (context) => FriendsScreen(),
        '/chatbot': (context) => ChatbotScreen(),
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
  final ActivityPointsService _activityPointsService = ActivityPointsService();

  @override
  void initState() {
    super.initState();

    // Check if user is already logged in
    Future.delayed(Duration.zero, () async {
      if (_authService.currentUser != null) {
        // Award daily login streak points
        await _checkDailyLoginStreak();
        
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
  
  // Check and award daily login streak points
  Future<void> _checkDailyLoginStreak() async {
    try {
      final result = await _activityPointsService.checkAndAwardDailyLoginStreak();
      
      if (result['success']) {
        // Store streak information in a static variable that can be accessed by the dashboard
        if (result['streakIncreased'] && result['currentStreak'] > 1) {
          // Store streak data for dashboard to use
          await _storeStreakData(result['currentStreak'], result['pointsAwarded']);
        }
        
        developer.log(
          'Daily login streak processed: Streak=${result['currentStreak']}, '
          'Points awarded=${result['pointsAwarded']}',
          name: 'WelcomeScreen'
        );
      } else {
        developer.log('Failed to process daily login: ${result['message']}', name: 'WelcomeScreen');
      }
    } catch (e) {
      developer.log('Error checking daily login streak: $e', name: 'WelcomeScreen');
    }
  }
  
  // Store streak data in shared preferences or other storage
  Future<void> _storeStreakData(int currentStreak, int pointsAwarded) async {
    try {
      // Store in Firestore for the current user to ensure persistence
      final user = _authService.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastStreakCheck': {
            'timestamp': FieldValue.serverTimestamp(),
            'currentStreak': currentStreak,
            'pointsAwarded': pointsAwarded,
            'shown': false,
          }
        });
        
        developer.log('Stored streak data for dashboard to display', name: 'WelcomeScreen');
      }
    } catch (e) {
      developer.log('Error storing streak data: $e', name: 'WelcomeScreen');
    }
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
