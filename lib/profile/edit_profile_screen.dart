import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import 'dart:developer' as developer;

class EditProfileScreen extends StatefulWidget {
  final String? initialProfileImageUrl;
  final String initialName;
  final String? initialEmail; // Made optional since we're not displaying it
  final String? initialBio;

  const EditProfileScreen({
    Key? key,
    this.initialProfileImageUrl,
    required this.initialName,
    this.initialEmail, // No longer required
    this.initialBio,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  // Form validation
  final _formKey = GlobalKey<FormState>();
  String? _bioError;
  
  bool _isUpdating = false;
  String? _profileImageUrl;
  
  // Bio word count
  int _maxBioWords = 50;
  int _currentBioWords = 0;
  
  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _bioController.text = widget.initialBio ?? '';
    _profileImageUrl = widget.initialProfileImageUrl;
    
    // Calculate initial word count
    _updateBioWordCount(_bioController.text);
    
    // Add listener to track word count
    _bioController.addListener(() {
      _updateBioWordCount(_bioController.text);
    });
  }
  
  void _updateBioWordCount(String text) {
    // Count words (exclude empty strings after splitting)
    final wordCount = text.trim().split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty).length;
    
    setState(() {
      _currentBioWords = wordCount;
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // No need to validate name anymore as it's read-only
    
    // Validate bio doesn't exceed word limit
    if (_currentBioWords > _maxBioWords) {
      setState(() {
        _bioError = 'Bio cannot exceed $_maxBioWords words';
      });
      return;
    } else {
      setState(() {
        _bioError = null;
      });
    }
    
    setState(() => _isUpdating = true);
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Map to store updates (only bio, name is read-only)
        Map<String, dynamic> updates = {
          'bio': _bioController.text.trim(),
          'lastProfileUpdate': FieldValue.serverTimestamp(),
        };
        
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update(updates);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
        
        Navigator.pop(context); // Return to profile screen
      }
    } catch (e) {
      developer.log('Error updating profile: $e', name: 'EditProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'Edit Bio',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: blueColor,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          color: Colors.grey[50],
          height: MediaQuery.of(context).size.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 24),
                            
                            // Display profile image (non-editable)
                            if (_profileImageUrl != null)
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: NetworkImage(_profileImageUrl!),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Edit your profile information",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            
                            SizedBox(height: 30),
                            
                            // Form fields container
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 20),
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: blueColor.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name field (read-only)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Full Name',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: blueColor,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _nameController,
                                        readOnly: true,
                                        enabled: false,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          prefixIcon: Icon(Icons.person, color: Colors.grey),
                                          hintStyle: TextStyle(color: Colors.grey[600]),
                                          filled: true,
                                          fillColor: Colors.grey[100],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Name cannot be changed to maintain database integrity',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Bio field with word counter
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Bio',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: blueColor,
                                            ),
                                          ),
                                          Text(
                                            '${_maxBioWords - _currentBioWords} words left',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _currentBioWords > _maxBioWords 
                                                  ? Colors.red 
                                                  : Colors.grey[600],
                                              fontWeight: _currentBioWords > _maxBioWords
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      TextFormField(
                                        controller: _bioController,
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: blueColor, width: 2),
                                          ),
                                                                                     errorBorder: OutlineInputBorder(
                                             borderRadius: BorderRadius.circular(12),
                                             borderSide: BorderSide(color: Colors.red, width: 1),
                                           ),
                                           errorText: _bioError,
                                          helperText: 'Tell others a little about yourself (max 50 words)',
                                          helperStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          errorStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        validator: (value) {
                                          if (value != null && value.trim().isNotEmpty) {
                                            final wordCount = value.trim().split(RegExp(r'\s+'))
                                                .where((word) => word.isNotEmpty).length;
                                            if (wordCount > _maxBioWords) {
                                              return 'Bio cannot exceed $_maxBioWords words';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                  
                                  // No email field - removed as it's already displayed on the profile screen
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 30),
                            
                            // Action buttons at the bottom
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Save button
                                    Container(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: _isUpdating ? null : _updateProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          elevation: 4,
                                          shadowColor: blueColor.withOpacity(0.5),
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: _isUpdating 
                                          ? SizedBox(
                                              width: 24, 
                                              height: 24, 
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'Save Changes',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: 20),
                                    
                                    // Cancel button - secondary style
                                    Container(
                                      width: double.infinity,
                                      height: 55,
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.grey[700],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(15),
                                            side: BorderSide(color: Colors.grey.shade300),
                                          ),
                                          backgroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(height: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  // Helper method to build text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? error,
    String? helperText,
    int? maxLines,
  }) {
    final Color blueColor = Color(0xFF2D6DA8);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: blueColor,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: blueColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            prefixIcon: Icon(icon, color: blueColor),
            errorText: error,
            helperText: helperText,
            helperStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            errorStyle: TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (label == 'Full Name' && (value == null || value.isEmpty)) {
              return 'Name cannot be empty';
            }
            return null;
          },
        ),
      ],
    );
  }
} 