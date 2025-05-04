import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../model/user_model.dart';
import 'role_selection_screen.dart';
import 'university_selection_screen.dart';
import '../dashboard/dashboard_screen.dart';

class ProfileCompletionWrapper extends StatefulWidget {
  const ProfileCompletionWrapper({Key? key}) : super(key: key);

  @override
  _ProfileCompletionWrapperState createState() => _ProfileCompletionWrapperState();
}

class _ProfileCompletionWrapperState extends State<ProfileCompletionWrapper> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserRole? _selectedRole;
  String? _selectedUniversity;
  String? _userName;
  int _currentStep = 0;
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData.name;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: $e';
        _isLoading = false;
      });
    }
  }
  
  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      _currentStep = 1; // Move to university selection
      _errorMessage = null;
    });
  }
  
  void _selectUniversity(String university) {
    setState(() {
      _selectedUniversity = university;
      _errorMessage = null;
      _isLoading = true;
    });
    
    // Save to Firestore and complete profile
    _completeProfile();
  }
  
  Future<void> _completeProfile() async {
    if (_selectedRole != null && _selectedUniversity != null) {
      try {
        await _authService.completeProfile(
          role: _selectedRole!,
          university: _selectedUniversity!,
        );
        
        // Check if widget is still mounted before navigating
        if (mounted) {
          // Successfully completed profile - navigate to home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => DashboardScreen()),
          );
        }
      } catch (e) {
        // Handle error
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error saving profile: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'An unknown error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Show loading indicator while loading user data or saving profile
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF125F9D),
              ),
              SizedBox(height: 20),
              Text(
                "Setting up your profile...",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF125F9D),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Display error message if there's an error
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF125F9D),
                ),
                child: Text("Try Again", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    
    // Check if username is missing and show username input if needed
    if (_userName == null || _userName!.isEmpty) {
      return _buildUsernameInputScreen();
    }
    
    // Role selection is the first step
    if (_currentStep == 0) {
      return RoleSelectionScreen(onRoleSelected: _selectRole);
    } 
    
    // University selection is the second step
    return UniversitySelectionScreen(onUniversitySelected: _selectUniversity);
  }
  
  Widget _buildUsernameInputScreen() {
    final TextEditingController _usernameController = TextEditingController();
    bool _isSubmitting = false;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              "Complete Your Profile",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Color(0xFF125F9D),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 30),
                  Text(
                    "What should we call you?",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF125F9D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Please provide a username to continue.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person, color: Color(0xFF125F9D)),
                      hintText: "Enter your username",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Color(0xFF125F9D),
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Color(0xFF125F9D),
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Color(0xFF125F9D),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting 
                      ? null 
                      : () async {
                        final username = _usernameController.text.trim();
                        
                        // Validate length
                        if (username.length < 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Username must be at least 3 characters long"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Validate that username isn't just numbers
                        if (RegExp(r'^[0-9]+$').hasMatch(username)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Username cannot contain only numbers"),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        setState(() {
                          _isSubmitting = true;
                        });
                        
                        try {
                          // Save username to Firestore
                          User? user = _authService.currentUser;
                          if (user != null) {
                            await _firestore.collection('users').doc(user.uid).update({
                              'name': username,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            
                            // Update state
                            this.setState(() {
                              _userName = username;
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Error saving username: $e"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isSubmitting = false;
                            });
                          }
                        }
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF125F9D),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isSubmitting
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
    );
  }
} 