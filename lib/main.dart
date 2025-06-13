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
import 'services/metadata_service.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'splashscreen.dart'; // Import the new splash screen
// DocumentsScreen will be implemented later

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize EnvConfig to load Cloudinary credentials
  await EnvConfig.initialize();

  // Initialize MetadataService to load predefined metadata
  await MetadataService().initialize();

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
        '/': (context) => WaveScreen(), // Use the new WaveScreen
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
