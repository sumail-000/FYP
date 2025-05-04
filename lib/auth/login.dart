import 'package:flutter/material.dart';
import 'signup.dart'; 
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard/dashboard_screen.dart';

void main() {
  runApp(LoginApp());
}

class LoginApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isObscure = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isKeyboardVisible = false;
  bool _showAnimatedWidgets = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  String _errorMessage = '';
  late AnimationController _animationController;
  late List<Animation<Offset>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
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
      
      // Password field - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.2, 0.7, curve: Curves.easeOutBack),
        ),
      ),
      
      // Forget password - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.3, 0.8, curve: Curves.easeOutBack),
        ),
      ),
      
      // Login button - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.4, 0.9, curve: Curves.easeOutBack),
        ),
      ),
      
      // Divider - from left
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.5, 1.0, curve: Curves.easeOutBack),
        ),
      ),
      
      // Google button - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.6, 1.0, curve: Curves.easeOutBack),
        ),
      ),
      
      // Signup text - from left
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.7, 1.0, curve: Curves.easeOutBack),
        ),
      ),
    ];
    
    // Start the animation after a short delay
    Future.delayed(Duration(milliseconds: 100), () {
      // Set flag to show widgets just before animation starts
      setState(() {
        _showAnimatedWidgets = true;
      });
      
      // Start the animation
      Future.delayed(Duration(milliseconds: 100), () {
        _animationController.forward();
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Function to handle login
  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        // Navigate to home screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login successful'))
          );
          
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Function to handle password reset
  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email address to reset your password';
      });
      return;
    }

    try {
      await _authService.resetPassword(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent'))
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // Function to handle Google sign-in
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = '';
    });

    try {
      await _authService.signInWithGoogle();
      
      // Navigate to home screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in successful'))
        );
        
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  // Method to calculate dynamic positions based on error presence
  double _getEmailFieldTopPosition() {
    // Add extra space if error message is shown
    double basePosition = _isKeyboardVisible ? 140 : 310;
    if (_errorMessage.isNotEmpty) {
      return basePosition + 20; // Reduced extra space for error message
    }
    return basePosition;
  }

  double _getPasswordFieldTopPosition() {
    // Start with base position
    double basePosition = _isKeyboardVisible ? 220 : 390;
    
    // Add extra space if there's an email error
    if (_errorMessage.isNotEmpty && _isEmailError(_errorMessage)) {
      return basePosition + 20; // Add space for the error under email field
    }
    
    return basePosition;
  }

  double _getForgetPasswordTopPosition() {
    double basePosition = _isKeyboardVisible ? 290 : 448;
    
    // Add extra space if there's an email error
    if (_errorMessage.isNotEmpty && _isEmailError(_errorMessage)) {
      return basePosition + 20;
    }
    
    // Add extra space if there's a password error
    if (_errorMessage.isNotEmpty && !_isEmailError(_errorMessage)) {
      return basePosition + 20;
    }
    
    return basePosition;
  }

  double _getLoginButtonTopPosition() {
    double basePosition = _isKeyboardVisible ? 330 : 500;
    
    // Add extra space for errors
    if (_errorMessage.isNotEmpty) {
      return basePosition + 20;
    }
    
    return basePosition;
  }

  double _getDividerTopPosition() {
    double basePosition = _isKeyboardVisible ? 400 : 570;
    if (_errorMessage.isNotEmpty) {
      return basePosition + 20; // Reduced extra space for error message
    }
    return basePosition;
  }

  double _getGoogleButtonTopPosition() {
    double basePosition = _isKeyboardVisible ? 450 : 620;
    if (_errorMessage.isNotEmpty) {
      return basePosition + 20; // Reduced extra space for error message
    }
    return basePosition;
  }

  double _getSignupTextTopPosition() {
    double basePosition = _isKeyboardVisible ? 520 : 690;
    if (_errorMessage.isNotEmpty) {
      return basePosition + 20; // Reduced extra space for error message
    }
    return basePosition;
  }

  bool _isEmailError(String errorMessage) {
    // Check if the error is related to the email field
    String lowerCaseError = errorMessage.toLowerCase();
    return lowerCaseError.contains('email') || 
           lowerCaseError.contains('user-not-found') || 
           lowerCaseError.contains('no account') ||
           lowerCaseError.contains('invalid-email');
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
          
          // Main content in a stack to control positioning absolutely
          SingleChildScrollView(
            physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Form(
                key: _formKey,
                child: Container(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                  children: [
                      // Placeholder container for overall sizing
                      Container(
                        height: MediaQuery.of(context).size.height,
                        width: double.infinity,
                      ),
                      
                      // All elements positioned absolutely
                      
                      // Title
                      Positioned(
                        top: _isKeyboardVisible ? 70 : 240,
                        child: SlideTransition(
                          position: _animations[0],
                          child: Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF125F9D),
                            ),
                          ),
                        ),
                      ),

                      // Email field
                      Positioned(
                        top: _isKeyboardVisible ? 140 : 310,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width - 80,
                              child: SlideTransition(
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
                            ),
                            if (_errorMessage.isNotEmpty && _isEmailError(_errorMessage))
                              Container(
                                width: MediaQuery.of(context).size.width - 80,
                                margin: EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red[600], size: 14),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _formatErrorMessage(_errorMessage),
                                        style: TextStyle(
                                          color: Colors.red[600], 
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500
                                        ),
                                        textAlign: TextAlign.left,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Password field
                      Positioned(
                        top: _getPasswordFieldTopPosition(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width - 80,
                              child: SlideTransition(
                                position: _animations[2],
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _isObscure,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.lock, color: Color(0xFF125F9D), size: 24),
                                    hintText: "Enter your password",
                                    hintStyle: TextStyle(color: Color(0xFF125F9D), fontSize: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Color(0xFF125F9D)),
                                      onPressed: () => setState(() => _isObscure = !_isObscure),
                                    ),
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
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            if (_errorMessage.isNotEmpty && !_isEmailError(_errorMessage))
                              Container(
                                width: MediaQuery.of(context).size.width - 80,
                                margin: EdgeInsets.only(top: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.red[600], size: 14),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _formatErrorMessage(_errorMessage),
                                        style: TextStyle(
                                          color: Colors.red[600], 
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500
                                        ),
                                        textAlign: TextAlign.left,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Forget password
                      Positioned(
                        top: _getForgetPasswordTopPosition(),
                        right: 0,
                        child: SlideTransition(
                          position: _animations[3],
                      child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/reset-password');
                            },
                            child: Text('Forget password', style: TextStyle(fontSize: 16, color: Color(0xFF125F9D))),
                          ),
                        ),
                      ),
                      
                      // Login button
                      Positioned(
                        top: _getLoginButtonTopPosition(),
                        child: SlideTransition(
                          position: _animations[4],
                          child: SizedBox(
                      width: 200,
                            height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF125F9D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                              onPressed: _isLoading ? null : _signIn,
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
                                  : Text('Login', style: TextStyle(color: Colors.white, fontSize: 22)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Divider
                      Positioned(
                        top: _getDividerTopPosition(),
                        child: Container(
                          width: MediaQuery.of(context).size.width - 80,
                          child: SlideTransition(
                            position: _animations[5],
                            child: buildDivider(),
                          ),
                        ),
                      ),
                      
                      // Google button
                      Positioned(
                        top: _getGoogleButtonTopPosition(),
                        child: SlideTransition(
                          position: _animations[6],
                          child: Container(
                            width: 200,
                            height: 45,
                            child: OutlinedButton(
                              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Color(0xFFDDDDDD), width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isGoogleLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4285F4),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Continue with',
                                        style: TextStyle(
                                          color: Color(0xFF4285F4),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Image.asset(
                                        'assets/google.png',
                                        width: 25,
                                        height: 25,
                                      ),
                                    ],
                                  ),
                            ),
                        ),
                      ),
                    ),
                    
                      // Signup text
                      Positioned(
                        top: _getSignupTextTopPosition(),
                        child: SlideTransition(
                          position: _animations[7],
                          child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?", style: TextStyle(fontSize: 15, color: Color(0xFF125F9D))),
                        TextButton(
                          onPressed: () {
                                  // Reset animation before navigation
                                  _animationController.reset();
                                  Navigator.of(context).pushReplacementNamed('/signup');
                          },
                          child: Text('Signup', style: TextStyle(color: Color(0xFF125F9D), fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                          ),
                        ),
                      ),
                      
                      // Extra bottom padding space
                      Positioned(
                        top: _isKeyboardVisible ? 550 : 720,
                        child: SizedBox(height: 50),
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

  Widget buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(thickness: 1.5, color: Color(0xFF125F9D))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: TextStyle(fontSize: 20, color: Color(0xFF125F9D), fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Divider(thickness: 1.5, color: Color(0xFF125F9D))),
      ],
    );
  }

  String _formatErrorMessage(String errorMessage) {
    // Clean up Firebase error messages
    String cleanedMessage = errorMessage;
    
    // Handle specific Firebase error messages to make them more user-friendly and concise
    if (cleanedMessage.contains('auth/wrong-password') || 
        cleanedMessage.contains('credential is incorrect') ||
        cleanedMessage.contains('invalid-credential')) {
      return 'Incorrect email or password';
    }
    
    if (cleanedMessage.contains('auth/user-not-found')) {
      return 'No account found with this email';
    }
    
    if (cleanedMessage.contains('auth/too-many-requests')) {
      return 'Too many login attempts, try again later';
    }
    
    if (cleanedMessage.contains('auth/network-request-failed')) {
      return 'Network error, check your connection';
    }
    
    if (cleanedMessage.contains('auth/invalid-email')) {
      return 'Invalid email address';
    }
    
    if (cleanedMessage.contains('auth/user-disabled')) {
      return 'This account has been disabled';
    }
    
    // For any other message, clean and format it
    if (cleanedMessage.startsWith('Firebase: ')) {
      cleanedMessage = cleanedMessage.substring('Firebase: '.length);
    }
    
    if (cleanedMessage.startsWith('FirebaseError: ')) {
      cleanedMessage = cleanedMessage.substring('FirebaseError: '.length);
    }
    
    // Make the message concise - keep only the first sentence
    int firstPeriod = cleanedMessage.indexOf('.');
    if (firstPeriod > 0) {
      cleanedMessage = cleanedMessage.substring(0, firstPeriod + 1);
    }
    
    // Make sure first letter is uppercase
    if (cleanedMessage.isNotEmpty) {
      cleanedMessage = cleanedMessage[0].toUpperCase() + cleanedMessage.substring(1);
    }
    
    return cleanedMessage;
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