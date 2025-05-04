import 'package:flutter/material.dart';
import 'login.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  bool _isObscure = true; // Initially, password is hidden
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isKeyboardVisible = false;
  bool _showAnimatedWidgets = false; // Added to control visibility
  final _usernameController = TextEditingController();
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
      
      // Username field - from left
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.1, 0.6, curve: Curves.easeOutBack),
        ),
      ),
      
      // Email field - from right
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.2, 0.7, curve: Curves.easeOutBack),
        ),
      ),
      
      // Password field - from left
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.3, 0.8, curve: Curves.easeOutBack),
        ),
      ),
      
      // Signup button - from right (changed from bottom)
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.4, 0.9, curve: Curves.easeOutBack),
        ),
      ),
      
      // Divider - from left (changed from scale in)
      Tween<Offset>(begin: Offset(-1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.5, 1.0, curve: Curves.easeOutBack),
        ),
      ),
      
      // Google button - from right (changed from bottom)
      Tween<Offset>(begin: Offset(1.5, 0.0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.6, 1.0, curve: Curves.easeOutBack),
        ),
      ),
      
      // Login text - from left (changed from bottom slide)
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Function to handle signup
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.registerWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        // Save additional user data if needed (like username)
        // This would typically go to a database like Firestore
        
        // Navigate to login page or directly to home page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account created successfully'))
          );
          
          // Navigate back to login page
          Navigator.of(context).pushReplacementNamed('/login');
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
                        top: _isKeyboardVisible ? 50 : 210,
                        child: SlideTransition(
                          position: _animations[0],
                          child: Text(
                      "Sign up",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF125F9D),
                            ),
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Positioned(
                          top: _isKeyboardVisible ? 90 : 250,
                          child: Container(
                            width: MediaQuery.of(context).size.width - 80,
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                      // Username field
                      Positioned(
                        top: _isKeyboardVisible ? 120 : 280,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 80,
                          child: SlideTransition(
                            position: _animations[1],
                            child: TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.person, color: Color(0xFF125F9D), size: 24),
                                hintText: "Enter your username",
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
                                  return 'Please enter your username';
                                }
                                if (value.length < 3) {
                                  return 'Username must be at least 3 characters';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      
                      // Email field
                      Positioned(
                        top: _isKeyboardVisible ? 200 : 360,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 80,
                          child: SlideTransition(
                            position: _animations[2],
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
                      ),
                      
                      // Password field
                      Positioned(
                        top: _isKeyboardVisible ? 280 : 440,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 80,
                          child: SlideTransition(
                            position: _animations[3],
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
                      ),

                      // Signup button
                      Positioned(
                        top: _isKeyboardVisible ? 370 : 530,
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
                              onPressed: _isLoading ? null : _signUp,
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
                                  : Text('Sign up', style: TextStyle(color: Colors.white, fontSize: 22)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Divider
                      Positioned(
                        top: _isKeyboardVisible ? 440 : 600,
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
                        top: _isKeyboardVisible ? 490 : 650,
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
                    
                      // Login text
                      Positioned(
                        top: _isKeyboardVisible ? 550 : 710,
                        child: SlideTransition(
                          position: _animations[7],
                          child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account?", style: TextStyle(fontSize: 15, color: Color(0xFF125F9D))),
                        TextButton(
                          onPressed: () {
                                  // Reset animation before navigation
                                  _animationController.reset();
                                  Navigator.of(context).pushReplacementNamed('/login');
                          },
                          child: Text('Login', style: TextStyle(color: Color(0xFF125F9D), fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                          ),
                        ),
                      ),
                      
                      // Extra bottom padding space
                      Positioned(
                        top: _isKeyboardVisible ? 590 : 750,
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