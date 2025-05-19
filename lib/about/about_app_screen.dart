import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'About Academia Hub',
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
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Logo and Version
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: blueColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: blueColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "AH",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Academia Hub",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // About Section
              _buildSectionTitle("About", orangeColor),
              _buildInfoCard(
                "Academia Hub is an educational platform designed to connect students and educators, facilitating resource sharing and collaborative learning. Our mission is to make education more accessible and interactive for everyone."
              ),
              
              SizedBox(height: 24),
              
              // Features Section
              _buildSectionTitle("Key Features", orangeColor),
              _buildFeatureItem(
                "Resource Sharing",
                "Upload and share academic documents, notes, and study materials with peers",
                Icons.folder_shared,
                blueColor,
              ),
              _buildFeatureItem(
                "Profile System",
                "Create and customize your academic profile showcasing your educational journey",
                Icons.person,
                blueColor,
              ),
              _buildFeatureItem(
                "Social Connections",
                "Connect with fellow students and educators to expand your network",
                Icons.people,
                blueColor,
              ),
              _buildFeatureItem(
                "Activity Points",
                "Earn points through active participation and contributions",
                Icons.emoji_events,
                blueColor,
              ),
              _buildFeatureItem(
                "Achievement Badges",
                "Collect badges that highlight your accomplishments",
                Icons.workspace_premium,
                blueColor,
              ),
              
              SizedBox(height: 24),
              
              // Development Info
              _buildSectionTitle("Development", orangeColor),
              _buildInfoCard(
                "Academia Hub was developed using Flutter and Firebase, providing a cross-platform experience with real-time functionality. The application follows modern design principles and focuses on user experience."
              ),
              
              SizedBox(height: 24),
              
              // Contact Section
              _buildSectionTitle("Contact", orangeColor),
              _buildInfoCard(
                "For support or inquiries, reach out to us at:\nsupport@academiahub.com\n\nFollow us on social media for updates and tips!"
              ),
              
              SizedBox(height: 24),
              
              // Privacy Policy Link
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navigate to privacy policy or show dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Privacy Policy coming soon')),
                    );
                  },
                  child: Text(
                    "Privacy Policy",
                    style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 24),
              
              // Copyright
              Center(
                child: Text(
                  "© 2023 Academia Hub. All rights reserved.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String text) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey[300]!,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: Colors.grey[800],
          height: 1.5,
        ),
      ),
    );
  }
  
  Widget _buildFeatureItem(String title, String description, IconData icon, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.grey[300]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 