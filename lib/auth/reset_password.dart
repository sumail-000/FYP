import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login.dart';

class ResetPasswordScreen extends StatefulWidget {
  // Add a parameter to indicate where the user is coming from
  final bool fromPasswordChange;
  
  // Constructor with optional parameter
  const ResetPasswordScreen({
    Key? key, 
    this.fromPasswordChange = false,
  }) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _isKeyboardVisible = false;
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  String _errorMessage = '';
  String _successMessage = '';
  late AnimationController _animationController;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    // Create animations for each element with different directions and delays
    _animations = [
      // Title animation - from top
      Tween<Offset>(begin: Offset(0.0, -1.5), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.0, 0.5, curve: Curves.easeOutBack),
        ),
      ),
      
      // Email field - from left
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.1, 0.6, curve: Curves.easeOutBack),
        ),
      ),
      
      // Description - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.2, 0.7, curve: Curves.easeOutBack),
        ),
      ),
      
      // Reset button - from bottom
      Tween<Offset>(begin: Offset(0.0, 1.5), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.3, 0.8, curve: Curves.easeOutBack),
        ),
      ),
      
      // Back to login - fade in with slide
      Tween<Offset>(begin: Offset(0.0, 0.8), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.4, 0.9, curve: Curves.easeOutBack),
        ),
      ),
    ];
    
    // Start the animation after a short delay
    Future.delayed(Duration(milliseconds: 200), () {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Function to handle password reset
  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _successMessage = '';
      });

      try {
        await _authService.resetPassword(_emailController.text.trim());
        
        if (mounted) {
          setState(() {
            _successMessage = 'Password reset email sent to ${_emailController.text}. Please check your inbox.';
          });
        }
      } catch (e) {
        // Display network errors in a SnackBar
        if (mounted) {
          if (e.toString().contains('network') || 
              e.toString().contains('timeout') || 
              e.toString().contains('connection') ||
              e.toString().contains('unreachable')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Network error. Please check your internet connection and try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else {
            // For non-network errors, still show in the form
            setState(() {
              _errorMessage = e.toString();
            });
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if keyboard is visible
    _isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Only show decorative elements when keyboard is not visible
          if (!_isKeyboardVisible) ...[
            Positioned(
              left: -260,
              top: -590,
              child: CircleWidget(color: Color(0xFF5C5C5C).withOpacity(0.8)),
            ),
            Positioned(
              left: -320,
              top: -600,
              child: CircleWidget(color: Color(0xFFF26712).withOpacity(0.8)),
            ),
            Positioned(
              left: -355,
              top: -610,
              child: CircleWidget(color: Color(0xFF125F9D)),
            ),
          ],
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Adjust top padding based on keyboard visibility
                      SizedBox(height: _isKeyboardVisible ? 40 : 220),
                      // Animated title
                      SlideTransition(
                        position: _animations[0],
                        child: Text(
                          "Reset Password",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF125F9D),
                          ),
                        ),
                      ),

                      // Description text
                      SlideTransition(
                        position: _animations[2],
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Text(
                            "Enter your email address and we'll send you a link to reset your password.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF125F9D).withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      if (_successMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
                            ),
                            child: Text(
                              _successMessage,
                              style: TextStyle(color: Colors.green, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      // fields
                      SizedBox(height: 30),
                      // Animated email field
                      SlideTransition(
                        position: _animations[1],
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.email, color: Color(0xFF125F9D), size: 24),
                            hintText: "Enter your email",
                            hintStyle: TextStyle(color: Color(0xFF125F9D), fontSize: 18),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Color(0xFF125F9D), width: 3.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Color(0xFF125F9D), width: 4),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.red, width: 3.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.red, width: 4),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            // Basic email validation
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      SizedBox(height: 30),
                      // Animated reset button
                      SlideTransition(
                        position: _animations[3],
                        child: SizedBox(
                          width: 200,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF125F9D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _isLoading ? null : _resetPassword,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 18)),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 30),
                      // Animated back to login/password change link
                      SlideTransition(
                        position: _animations[4],
                        child: TextButton.icon(
                          icon: Icon(Icons.arrow_back, color: Color(0xFF125F9D), size: 20),
                          label: Text(
                            widget.fromPasswordChange ? 'Back to Password Change' : 'Back to Login',
                            style: TextStyle(
                              color: Color(0xFF125F9D),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onPressed: () {
                            if (widget.fromPasswordChange) {
                              Navigator.pop(context); // Go back to the previous screen (Password Change)
                            } else {
                              Navigator.of(context).pushReplacementNamed('/login');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleWidget extends StatelessWidget {
  final Color color;

  CircleWidget({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 799,
      width: 784,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: Offset(2, 4),
            blurRadius: 2,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
} 