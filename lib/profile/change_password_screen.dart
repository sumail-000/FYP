import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../auth/reset_password.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isUpdating = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  
  // Form validation
  final _formKey = GlobalKey<FormState>();
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;
  
  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate new password and confirmation match
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = 'New passwords do not match';
      });
      return;
    } else {
      setState(() {
        _confirmPasswordError = null;
      });
    }
    
    // New password must be at least 6 characters
    if (_newPasswordController.text.length < 6) {
      setState(() {
        _newPasswordError = 'New password must be at least 6 characters';
      });
      return;
    } else {
      setState(() {
        _newPasswordError = null;
      });
    }
    
    setState(() => _isUpdating = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // Reauthenticate user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Change password
        await user.updatePassword(_newPasswordController.text);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        // Go back to previous screen
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
        setState(() {
          _currentPasswordError = message;
        });
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
        setState(() {
          _newPasswordError = message;
        });
      } else {
        setState(() {
          _currentPasswordError = null;
          _newPasswordError = null;
          _confirmPasswordError = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      developer.log('Error changing password: ${e.code} - ${e.message}', name: 'ChangePasswordScreen');
    } catch (e) {
      developer.log('Error changing password: $e', name: 'ChangePasswordScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change password'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  void _navigateToResetPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResetPasswordScreen(fromPasswordChange: true),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure screen resizes when keyboard appears
      appBar: AppBar(
        title: Text(
          'Change Password',
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
          // Use LayoutBuilder to get constraints of parent widget
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SafeArea(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Add extra padding when keyboard is shown
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: 20),
                            
                            // Lock icon at top
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: blueColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.lock,
                                color: blueColor,
                                size: 40,
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            Text(
                              'Set a New Password',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: blueColor,
                              ),
                            ),
                            
                            SizedBox(height: 8),
                            
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Your new password must be different from your current password',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 30),
                            
                            // Password fields container
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
                                  // Current password field
                                  _buildPasswordField(
                                    controller: _currentPasswordController,
                                    label: 'Current Password',
                                    icon: Icons.lock_outline,
                                    error: _currentPasswordError,
                                    obscureText: _obscureCurrentPassword,
                                    onToggleVisibility: () {
                                      setState(() {
                                        _obscureCurrentPassword = !_obscureCurrentPassword;
                                      });
                                    },
                                    showForgotPassword: true,
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // New password field
                                  _buildPasswordField(
                                    controller: _newPasswordController,
                                    label: 'New Password',
                                    icon: Icons.lock_open,
                                    error: _newPasswordError,
                                    helperText: 'Password must be at least 6 characters',
                                    obscureText: _obscureNewPassword,
                                    onToggleVisibility: () {
                                      setState(() {
                                        _obscureNewPassword = !_obscureNewPassword;
                                      });
                                    },
                                  ),
                                  
                                  SizedBox(height: 20),
                                  
                                  // Confirm new password field
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm New Password',
                                    icon: Icons.check_circle_outline,
                                    error: _confirmPasswordError,
                                    obscureText: _obscureConfirmPassword,
                                    onToggleVisibility: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 30),
                            
                            // Action buttons - wrap in a container with flex to push to bottom when space allows
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Update password button
                                    Container(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: _isUpdating ? null : _changePassword,
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
                                              'Update Password',
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
  
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? error,
    String? helperText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    bool showForgotPassword = false,
  }) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Just the label without the Forgot Password link
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
          obscureText: obscureText,
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
            suffixIcon: IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: onToggleVisibility,
            ),
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
            if (value == null || value.isEmpty) {
              return 'This field is required';
            }
            return null;
          },
        ),
        // Add Forgot Password link after the TextFormField
        if (showForgotPassword)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: GestureDetector(
                onTap: _navigateToResetPassword,
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: orangeColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
} 