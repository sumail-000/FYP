import 'package:flutter/material.dart';
import 'signup.dart'; // Import signup.dart from same directory

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

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscure = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
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
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  children: [
                    SizedBox(height: 250),
                    Text(
                      "Login",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF125F9D),
                      ),
                    ),

                    // fields
                    SizedBox(height: 35),
                    buildTextField(Icons.email, "Enter your email", false),
                    SizedBox(height: 35),
                    buildTextField(Icons.lock, "Enter your password", true),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: Text('Forget password', style: TextStyle(fontSize: 16,color: Color(0xFF125F9D))),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF125F9D),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () {},
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('Login', style: TextStyle(color: Colors.white, fontSize: 22)),
                        ),
                      ),
                    ),
                    SizedBox(height: 35),
                    buildDivider(),
                    SizedBox(height: 35),
                    Image.asset('assets/google.png', width: 70, height: 30),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account?", style: TextStyle(fontSize: 15, color: Color(0xFF125F9D))),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen()));
                          },
                          child: Text('Signup', style: TextStyle(color: Color(0xFF125F9D), fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(IconData icon, String hint, bool isPassword) {
    return TextField(
      obscureText: isPassword ? _isObscure : false,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Color(0xFF125F9D), size: 24),
        hintText: hint,
        hintStyle: TextStyle(color: Color(0xFF125F9D), fontSize: 18),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Color(0xFF125F9D)),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Color(0xFF125F9D), width: 3.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Color(0xFF125F9D), width: 4),
        ),
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