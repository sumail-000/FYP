import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'login.dart';
import '../profile/profile_completion_wrapper.dart';
import '../dashboard/dashboard_screen.dart';
import '../model/user_model.dart';

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
            
            // Profile complete - check user role to determine where to navigate
            if (profileSnapshot.data == true) {
              return FutureBuilder<UserModel?>(
                future: _authService.getUserData(),
                builder: (context, userDataSnapshot) {
                  if (userDataSnapshot.connectionState == ConnectionState.waiting) {
                    return Scaffold(
                      backgroundColor: Colors.white,
                      body: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF125F9D),
                        ),
                      ),
                    );
                  }
                  
                  // Check user role and navigate accordingly
                  if (userDataSnapshot.hasData) {
                    final userData = userDataSnapshot.data!;
                    
                    if (userData.role == UserRole.teacher) {
                      // Teachers see the pending screen
                      return _buildTeacherPendingScreen(context);
                    } else {
                      // Students (and default case) go to dashboard
                      return DashboardScreen();
                    }
                  } else {
                    // Default fallback to dashboard if we can't determine role
                    return DashboardScreen();
                  }
                },
              );
            } 
            
            // Profile incomplete - go to profile completion flow
            return ProfileCompletionWrapper();
          },
        );
      },
    );
  }
  
  // Temporary screen for teacher role until teacher dashboard is implemented
  Widget _buildTeacherPendingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Teacher Portal",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFFF26712), // Use orange color for teacher
        actions: [
          // Allow logout
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 80,
                color: Color(0xFFF26712),
              ),
              SizedBox(height: 30),
              Text(
                "Teacher Portal Coming Soon",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF125F9D),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                "We're working hard to bring you a dedicated teacher dashboard with all the tools you need to share educational content.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  await _authService.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF26712),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  "Sign Out",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 