import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'login.dart';
import '../profile/profile_completion_wrapper.dart';
import '../home_screen.dart';

class AuthStateWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  AuthStateWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        // Loading state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF125F9D),
              ),
            ),
          );
        }
        
        // User not logged in - show login screen
        if (!authSnapshot.hasData) {
          return LoginScreen();
        }
        
        // User logged in - check profile completion
        return FutureBuilder<bool>(
          future: _authService.isProfileComplete(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF125F9D),
                  ),
                ),
              );
            }
            
            // Profile complete - go to home screen
            if (profileSnapshot.data == true) {
              return HomeScreen();
            } 
            
            // Profile incomplete - go to profile completion flow
            return ProfileCompletionWrapper();
          },
        );
      },
    );
  }
} 