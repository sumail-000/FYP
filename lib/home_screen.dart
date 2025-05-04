import 'package:flutter/material.dart';
import 'auth/auth_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Academia Hub",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF125F9D),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Color(0xFF125F9D).withOpacity(0.1),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, ${_authService.currentUser?.email?.split('@').first ?? 'User'}!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF125F9D),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Access and share academic materials with your peers",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF125F9D).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildFeatureCard(
                    "Notes",
                    Icons.note_alt_outlined,
                    Color(0xFF125F9D),
                    () => _showFeatureNotAvailable(context, "Notes"),
                  ),
                  _buildFeatureCard(
                    "Books",
                    Icons.book_outlined,
                    Color(0xFFF26712),
                    () => _showFeatureNotAvailable(context, "Books"),
                  ),
                  _buildFeatureCard(
                    "Assignments",
                    Icons.assignment_outlined,
                    Color(0xFF5C5C5C),
                    () => _showFeatureNotAvailable(context, "Assignments"),
                  ),
                  _buildFeatureCard(
                    "Forums",
                    Icons.forum_outlined,
                    Color(0xFF0F95A2),
                    () => _showFeatureNotAvailable(context, "Forums"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: color,
            ),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureNotAvailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 