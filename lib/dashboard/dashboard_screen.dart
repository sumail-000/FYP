import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'dart:developer' as developer;
import 'dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Define the exact orange color
  final Color orangeColor = Color(0xFFf06517);
  
  @override
  void initState() {
    super.initState();
    developer.log('DashboardScreen initialized', name: 'Dashboard');
  }
  
  @override
  Widget build(BuildContext context) {
    developer.log('Building DashboardScreen', name: 'Dashboard');
    
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    developer.log('Screen size: ${width} x ${height}', name: 'Dashboard');
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFE6E8EB),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF2D6DA8), // Updated to match blue in reference
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(
                      Icons.person,
                      color: Color(0xFF2D6DA8),
                      size: 40,
                    ),
                  ),
                  SizedBox(height: height * 0.01),
                  Text(
                    "${_authService.currentUser?.email?.split('@').first ?? 'User'}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: height * 0.022,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${_authService.currentUser?.email ?? ''}",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: height * 0.016,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await _authService.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: width,
            margin: EdgeInsets.only(
              bottom: height * 0.015,
              left: 0,
              right: 0,
              top: 0
            ),
            padding: EdgeInsets.only(
              bottom: height * 0.02,
              top: statusBarHeight
            ),
            decoration: BoxDecoration(
              color: Color(0xFF2D6DA8),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(width * 0.15),
                bottomRight: Radius.circular(width * 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Bar Section
                Padding(
                  padding: EdgeInsets.only(
                    top: height * 0.02, 
                    left: width * 0.02, 
                    right: width * 0.02
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Custom hamburger menu icon
                      Padding(
                        padding: EdgeInsets.only(left: width * 0.03),
                        child: Container(
                          width: width * 0.08,
                          height: width * 0.08,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              _scaffoldKey.currentState!.openDrawer();
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: width * 0.07,
                                  height: 3,
                                  margin: EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                Container(
                                  width: width * 0.05,
                                  height: 3,
                                  margin: EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                Container(
                                  width: width * 0.07,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Profile icon
                      Padding(
                        padding: EdgeInsets.only(right: width * 0.03),
                        child: Container(
                          width: width * 0.1,
                          height: width * 0.1,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.person,
                              color: Color(0xFF2D6DA8),
                              size: width * 0.06,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.07,
                    vertical: height * 0.03
                  ),
                  child: Container(
                    height: height * 0.06,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(height * 0.03),
                      border: Border.all(
                        color: orangeColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: EdgeInsets.only(left: width * 0.0),
                          width: height * 0.06,
                          height: height * 0.07,
                          decoration: BoxDecoration(
                            color: orangeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.search,
                              color: Colors.white,
                              size: height * 0.035,
                            ),
                          ),
                        ),
                        
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search for resources',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        
                        Container(
                          margin: EdgeInsets.only(right: width * 0.04),
                          child: Icon(
                            Icons.tune,
                            color: const Color(0xFFf06517),
                            size: width * 0.07,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMenuButton(
                        title: "Friends",
                        icon: Icons.people,
                        color: orangeColor,
                        onTap: () => DashboardService.showFeatureNotAvailable(context, "Friends"),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Bot",
                        icon: Icons.smart_toy,
                        color: orangeColor,
                        onTap: () => DashboardService.showFeatureNotAvailable(context, "Bot"),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Upload",
                        icon: Icons.cloud_upload,
                        color: orangeColor,
                        onTap: () => DashboardService.navigateToUploadScreen(context),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "ChatRoom",
                        icon: Icons.chat_bubble,
                        color: orangeColor,
                        onTap: () => DashboardService.showFeatureNotAvailable(context, "ChatRoom"),
                        width: width,
                        height: height,
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: height * 0.025),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(width * 0.04),
              child: Column(
                children: [
                  // Content will be added later
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double width,
    required double height,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: width * 0.16,
            height: width * 0.16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(width * 0.04),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: width * 0.08,
            ),
          ),
          SizedBox(height: height * 0.01),
          Text(
            title,
            style: TextStyle(
              fontSize: width * 0.035,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 