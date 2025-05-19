import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'dart:developer' as developer;
import 'dashboard_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/profile_screen.dart';
import '../chatroom/chatroom_screen.dart';
import '../services/presence_service.dart';
import '../chatbot/chatbot_screen.dart';
import '../services/activity_points_service.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _profileImageUrl;
  int _selectedIndex = 0;
  bool _isStreakMessageShown = false;

  // Define the exact orange color
  final Color orangeColor = Color(0xFFf06517);

  // Define the exact blue color
  final Color blueColor = Color(0xFF2D6DA8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    developer.log('DashboardScreen initialized', name: 'Dashboard');

    // Debug check for user university
    _getUserUniversity().then((university) {
      developer.log(
        'User university is: ${university ?? "NULL"}',
        name: 'Dashboard',
      );
    });

    // Load user profile image
    _loadUserProfileImage();

    // Update user presence
    _updatePresence(true);
    
    // Check and show streak notification if needed
    // Delay slightly to ensure dashboard is fully loaded
    Future.delayed(Duration(milliseconds: 800), () {
      _checkAndShowStreakNotification();
    });
  }

  // Check if there's a streak notification to show and display it
  Future<void> _checkAndShowStreakNotification() async {
    try {
      final user = _authService.currentUser;
      if (user == null || _isStreakMessageShown) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final lastStreakCheck = userData['lastStreakCheck'] as Map<String, dynamic>?;
      
      if (lastStreakCheck != null && lastStreakCheck['shown'] == false) {
        final currentStreak = lastStreakCheck['currentStreak'] as int;
        final pointsAwarded = lastStreakCheck['pointsAwarded'] as int;
        
        // Only show if we have a meaningful streak (more than 1 day)
        if (currentStreak > 1 && mounted && !_isStreakMessageShown) {
          setState(() => _isStreakMessageShown = true);
          
          // Show a subtle notification at the bottom
          final streakMessage = 'Login streak: $currentStreak days! +$pointsAwarded point';
          
          // Use a less intrusive notification that appears at the bottom
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text(
                    streakMessage,
                    style: TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.only(bottom: 20, left: 20, right: 20),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: Colors.black87,
            ),
          );
          
          // Mark as shown in the database
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'lastStreakCheck.shown': true
          });
          
          developer.log('Displayed streak notification: Streak=$currentStreak', name: 'Dashboard');
        }
      }
    } catch (e) {
      developer.log('Error checking streak notification: $e', name: 'Dashboard');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updatePresence(false);
    }
  }

  // Update user presence status
  Future<void> _updatePresence(bool isOnline) async {
    await _presenceService.updatePresence(
      isOnline: isOnline,
      screen: 'dashboard',
    );
  }

  Future<void> _loadUserProfileImage() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // First check if profile exists in the profiles collection
        final profileDoc =
            await FirebaseFirestore.instance
                .collection('profiles')
                .doc(user.uid)
                .get();

        if (profileDoc.exists) {
          final profileData = profileDoc.data() as Map<String, dynamic>;
          if (profileData.containsKey('secureUrl') &&
              profileData['secureUrl'] != null) {
            setState(() {
              _profileImageUrl = profileData['secureUrl'];
            });
            developer.log(
              'Loaded profile image from profiles collection',
              name: 'Dashboard',
            );
            return; // Exit early if found in profiles collection
          }
        }

        // Fall back to user document if not found in profiles collection
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          if (data.containsKey('profileImageUrl') &&
              data['profileImageUrl'] != null) {
            setState(() {
              _profileImageUrl = data['profileImageUrl'];
            });
            developer.log(
              'Loaded profile image from users collection',
              name: 'Dashboard',
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error loading profile image: $e', name: 'Dashboard');
    }
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
                    child:
                        _profileImageUrl != null
                            ? ClipOval(
                              child: Image.network(
                                _profileImageUrl!,
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: Color(0xFF2D6DA8),
                                    size: 40,
                                  );
                                },
                              ),
                            )
                            : Icon(
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
            _buildDrawerItem(
              icon: Icons.home_outlined,
              title: 'Home',
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 0;
                });
              },
            ),
            _buildDrawerItem(
              icon: Icons.people_outline,
              title: 'Friends',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friends');
              },
              showUnreadCount: true,
            ),
            // Add Friend Requests option
            _buildDrawerItem(
              icon: Icons.person_add_alt_1,
              title: 'Friend Requests',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friend_requests');
              },
              showUnreadCount: true,
            ),
            ListTile(
              leading: Icon(Icons.file_copy),
              title: Row(
                children: [
                  Text('Documents'),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Documents feature coming soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
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
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
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
              top: 0,
            ),
            padding: EdgeInsets.only(
              bottom: height * 0.02,
              top: statusBarHeight,
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
                    right: width * 0.02,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Custom hamburger menu icon
                      Padding(
                        padding: EdgeInsets.only(left: width * 0.03),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _scaffoldKey.currentState!.openDrawer();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: EdgeInsets.all(width * 0.02),
                              width: width * 0.1,
                              height: width * 0.1,
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
                      ),

                      // Profile icon
                      Padding(
                        padding: EdgeInsets.only(right: width * 0.03),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                            // Refresh profile image when returning from profile screen
                            _loadUserProfileImage();
                          },
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
                            child:
                                _profileImageUrl != null
                                    ? ClipOval(
                                      child: Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        width: width * 0.1,
                                        height: width * 0.1,
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          developer.log(
                                            'Error loading profile image: $error',
                                            name: 'Dashboard',
                                          );
                                          return Icon(
                                            Icons.person,
                                            color: Color(0xFF2D6DA8),
                                            size: width * 0.06,
                                          );
                                        },
                                      ),
                                    )
                                    : Center(
                                      child: Icon(
                                        Icons.person,
                                        color: Color(0xFF2D6DA8),
                                        size: width * 0.06,
                                      ),
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
                    vertical: height * 0.03,
                  ),
                  child: Container(
                    height: height * 0.06,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(height * 0.03),
                      border: Border.all(color: orangeColor, width: 1.5),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: width * 0.02,
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search for resources',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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
                        onTap: () => Navigator.pushNamed(context, '/friends'),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Bot",
                        icon: Icons.smart_toy,
                        color: orangeColor,
                        onTap:
                            () => DashboardService.navigateToChatbotScreen(
                              context,
                            ),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Upload",
                        icon: Icons.cloud_upload,
                        color: orangeColor,
                        onTap:
                            () => DashboardService.navigateToUploadScreen(
                              context,
                            ),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "ChatRoom",
                        icon: Icons.chat_bubble,
                        color: orangeColor,
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatRoomScreen(),
                              ),
                            ),
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
            child: Column(
              children: [
                // Filter options row
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.04,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left filter button
                      IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.grey[700]),
                        onPressed: () {
                          // Left filter functionality to be implemented later
                          DashboardService.showFeatureNotAvailable(
                            context,
                            "Filters",
                          );
                        },
                      ),

                      // Right sort button
                      IconButton(
                        icon: Icon(Icons.sort, color: Colors.grey[700]),
                        onPressed: () {
                          _showSortOptions(context);
                        },
                      ),
                    ],
                  ),
                ),

                // Recent documents grid
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _getRecentDocuments(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: orangeColor),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[300],
                                size: 56,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Failed to load documents',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        );
                      }

                      final documents = snapshot.data ?? [];

                      if (documents.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open,
                                color: Colors.grey[400],
                                size: 64,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No documents yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try uploading some files',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed:
                                    () =>
                                        DashboardService.navigateToUploadScreen(
                                          context,
                                        ),
                                icon: Icon(Icons.cloud_upload),
                                label: Text('Upload Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orangeColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: width * 0.02),
                        child: GridView.builder(
                          physics: BouncingScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: documents.length,
                          itemBuilder: (context, index) {
                            final doc = documents[index];
                            return _buildDocumentCard(doc);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
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
            child: Icon(icon, color: Colors.white, size: width * 0.08),
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

  // Method to fetch recent documents
  Future<List<Map<String, dynamic>>> _getRecentDocuments() async {
    try {
      // First, get the current user's university
      String? userUniversity = await _getUserUniversity();

      if (userUniversity == null) {
        developer.log('User university not found', name: 'Dashboard');
        return [];
      }

      developer.log(
        'Filtering documents for university: $userUniversity',
        name: 'Dashboard',
      );

      // Get reference to Firestore collection
      final documentsRef = FirebaseFirestore.instance.collection('documents');

      // Query for documents from the user's university, ordered by upload timestamp (most recent first)
      final snapshot =
          await documentsRef
              .where('university', isEqualTo: userUniversity)
              .orderBy('uploadedAt', descending: true)
              .limit(10) // Limit to 10 documents
              .get();

      if (snapshot.docs.isEmpty) {
        developer.log(
          'No documents found for university: $userUniversity',
          name: 'Dashboard',
        );
        return [];
      }

      // Process query results into the format needed by the UI
      List<Map<String, dynamic>> result = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        developer.log('Processing document: ${doc.id}', name: 'Dashboard');

        // Extract file extension from fileName or format
        String extension = '';
        if (data['format'] != null) {
          extension = data['format'].toString().toLowerCase();
        } else if (data['fileName'] != null) {
          final fileName = data['fileName'] as String;
          final parts = fileName.split('.');
          if (parts.length > 1) {
            extension = parts.last.toLowerCase();
          }
        }

        // Only include supported document types
        if (!['pdf', 'doc', 'docx', 'ppt', 'pptx'].contains(extension)) {
          continue; // Skip unsupported formats
        }

        // Format timestamp for time ago display
        String timeAgo = 'Recently';
        if (data['uploadedAt'] != null) {
          final timestamp = data['uploadedAt'] as Timestamp;
          final now = DateTime.now();
          final difference = now.difference(timestamp.toDate());

          if (difference.inDays > 0) {
            timeAgo =
                '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
          } else if (difference.inHours > 0) {
            timeAgo =
                '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
          } else if (difference.inMinutes > 0) {
            timeAgo =
                '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
          } else {
            timeAgo = 'Just now';
          }
        }

        // Add document to result list with proper field mappings
        result.add({
          'id': doc.id,
          'fileName':
              data['displayName'] ?? data['fileName'] ?? 'Unnamed Document',
          'extension': extension,
          'course': data['course'] ?? '',
          'courseCode': data['courseCode'] ?? '',
          'department': data['department'] ?? '',
          'documentType': data['documentType'] ?? '',
          'timeAgo': timeAgo,
          'fileUrl': data['secureUrl'] ?? '',
          'bytes': data['bytes'] ?? 0,
          'uploaderName': data['uploaderName'] ?? 'Anonymous',
          'uploaderId': data['uploaderId'] ?? '',
        });
      }

      return result;
    } catch (e) {
      developer.log('Error fetching documents: $e', name: 'Dashboard');
      return [];
    }
  }

  // Helper method to get current user's university
  Future<String?> _getUserUniversity() async {
    try {
      if (_authService.currentUser == null) {
        return null;
      }

      // Get the user document
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .get();

      if (!userDoc.exists) {
        return null;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['university'] as String?;
    } catch (e) {
      developer.log('Error getting user university: $e', name: 'Dashboard');
      return null;
    }
  }

  // Method to show sort options
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: blueColor),
                    SizedBox(width: 16),
                    Text(
                      'Sort By',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.calendar_today, color: blueColor),
                title: Text('Latest Uploads'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    // Already the default sort order
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.sort_by_alpha, color: blueColor),
                title: Text('File Name (A-Z)'),
                onTap: () {
                  Navigator.pop(context);
                  // Implementation would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sorting by name'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Document card widget
  Widget _buildDocumentCard(Map<String, dynamic> document) {
    final fileName = document['fileName'] ?? 'Unnamed Document';
    final extension = document['extension']?.toLowerCase() ?? '';
    final course = document['course'] ?? '';
    final courseCode = document['courseCode'] ?? '';
    final department = document['department'] ?? '';
    final documentType = document['documentType'] ?? '';
    final timeAgo = document['timeAgo'] ?? '';
    final fileUrl = document['fileUrl'] ?? '';
    final bytes = document['bytes'] as int? ?? 0;
    final uploaderName = document['uploaderName'] ?? 'Anonymous';
    final uploaderId = document['uploaderId'] ?? '';

    // Format file size
    String fileSize = '';
    if (bytes > 0) {
      if (bytes < 1024) {
        fileSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        fileSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    // Determine file type color and image asset
    Color cardColor;
    String assetImage = '';
    String fileType;

    switch (extension) {
      case 'pdf':
        cardColor = Color(0xFFE94235); // Red for PDF
        assetImage = 'assets/pdf.png';
        fileType = 'PDF';
        break;
      case 'doc':
      case 'docx':
        cardColor = Color(0xFF2A5699); // Blue for Word
        assetImage = 'assets/doc.png';
        fileType = 'DOC';
        break;
      case 'ppt':
      case 'pptx':
        cardColor = Color(0xFFD24726); // Orange for PowerPoint
        assetImage = 'assets/ppt.png';
        fileType = 'PPT';
        break;
      default:
        // Fallback for any other supported format (should not occur with our filters)
        cardColor = Colors.grey;
        assetImage = '';
        fileType = extension.isEmpty ? 'DOC' : extension.toUpperCase();
    }

    return GestureDetector(
      onTap: () {
        // Show document details instead of opening the document
        _showDocumentDetails(document);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject name header with more space
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Course/subject name on left
                  Expanded(
                    child: Text(
                      course.isNotEmpty
                          ? course
                          : (courseCode.isNotEmpty
                              ? courseCode
                              : 'Subject Name'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            extension == 'pdf'
                                ? Colors.red[400]
                                : extension == 'doc' || extension == 'docx'
                                ? Colors.blue[600]
                                : extension == 'ppt' || extension == 'pptx'
                                ? Colors.orange[700]
                                : Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Three-dot menu on right
                  GestureDetector(
                    onTap: () {
                      // Show document details directly
                      _showDocumentDetails(document);
                    },
                    child: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            // File preview (centered with more space)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Document background or image
                      Container(
                        width: 85,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 0.5,
                          ),
                        ),
                        child:
                            assetImage.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    assetImage,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Show icon if asset fails to load
                                      return Center(
                                        child: Icon(
                                          DashboardService.getIconForFileType(
                                            extension,
                                          ),
                                          color: cardColor,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                )
                                : Center(
                                  child: Icon(
                                    DashboardService.getIconForFileType(
                                      extension,
                                    ),
                                    color: cardColor,
                                    size: 40,
                                  ),
                                ),
                      ),

                      // File type overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                          child: Text(
                            fileType,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Filename
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                fileName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey[800],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Time and download
            Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time indicator with circle background
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: orangeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.access_time,
                          size: 10,
                          color: orangeColor,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Action buttons (comment and rating)
                  Row(
                    children: [
                      // Comment button
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () {
                            _showCommentDialog(document);
                          },
                          child: Icon(Icons.comment, size: 14, color: blueColor),
                        ),
                      ),
                      SizedBox(width: 8),
                      
                      // Rating button
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: orangeColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: InkWell(
                          onTap: () {
                            _showRatingDialog(document);
                          },
                          child: Icon(Icons.star, size: 14, color: orangeColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show document details bottom sheet
  void _showDocumentDetails(Map<String, dynamic> document) {
    final fileName = document['fileName'] ?? 'Unnamed Document';
    final extension = document['extension']?.toLowerCase() ?? '';
    final course = document['course'] ?? '';
    final courseCode = document['courseCode'] ?? '';
    final department = document['department'] ?? '';
    final documentType = document['documentType'] ?? '';
    final timeAgo = document['timeAgo'] ?? '';
    final fileUrl = document['fileUrl'] ?? '';
    final bytes = document['bytes'] as int? ?? 0;
    final uploaderName = document['uploaderName'] ?? 'Anonymous';
    final uploaderId = document['uploaderId'] ?? '';
    final currentUserId = _authService.currentUser?.uid;
    final isCurrentUserDocument = uploaderId == currentUserId;

    // Format file size
    String fileSize = '';
    if (bytes > 0) {
      if (bytes < 1024) {
        fileSize = '$bytes B';
      } else if (bytes < 1024 * 1024) {
        fileSize = '${(bytes / 1024).toStringAsFixed(0)} KB';
      } else {
        fileSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
    }

    // Determine document color based on file extension
    Color documentColor =
        extension == 'pdf'
            ? Color(0xFFE94235) // Red for PDF
            : extension == 'doc' || extension == 'docx'
            ? Color(0xFF2A5699) // Blue for Word
            : extension == 'ppt' || extension == 'pptx'
            ? Color(0xFFD24726) // Orange for PowerPoint
            : Colors.grey; // Grey for other types

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 10,
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with document type color
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: documentColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Document Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  // Document details section
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Document icon and file name
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Document icon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: documentColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      extension == 'pdf'
                                          ? Icons.picture_as_pdf
                                          : extension == 'doc' ||
                                              extension == 'docx'
                                          ? Icons.description
                                          : extension == 'ppt' ||
                                              extension == 'pptx'
                                          ? Icons.slideshow
                                          : Icons.insert_drive_file,
                                      color: documentColor,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // File name
                                Expanded(
                                  child: Text(
                                    fileName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // File details as a card
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRowStyled(
                                    'Type',
                                    extension.toUpperCase(),
                                    Icons.description,
                                  ),
                                  _buildDetailRowStyled(
                                    'Size',
                                    fileSize,
                                    Icons.data_usage,
                                  ),
                                  if (course.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Course',
                                      course,
                                      Icons.book,
                                    ),
                                  if (courseCode.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Code',
                                      courseCode,
                                      Icons.code,
                                    ),
                                  if (department.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Department',
                                      department,
                                      Icons.domain,
                                    ),
                                  if (documentType.isNotEmpty)
                                    _buildDetailRowStyled(
                                      'Type',
                                      documentType,
                                      Icons.category,
                                    ),
                                  _buildDetailRowStyled(
                                    'Uploaded',
                                    timeAgo,
                                    Icons.access_time,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 20),

                            // Uploader section
                            Text(
                              'Uploaded by',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: blueColor,
                              ),
                            ),
                            SizedBox(height: 10),

                            // Uploader card with profile
                            Container(
                              padding: EdgeInsets.all(12),
                              margin: EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: FutureBuilder<Map<String, dynamic>?>(
                                future: _getUserProfileData(uploaderId),
                                builder: (context, snapshot) {
                                  // Get profile picture URL if available
                                  final profileImageUrl =
                                      snapshot.data?['profileImageUrl'] ??
                                      snapshot.data?['secureUrl'];

                                  return Row(
                                    children: [
                                      // Profile image
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: blueColor.withOpacity(0.1),
                                          border: Border.all(
                                            color: blueColor.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child:
                                            profileImageUrl != null
                                                ? ClipOval(
                                                  child: Image.network(
                                                    profileImageUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Icon(
                                                        Icons.person,
                                                        color: blueColor
                                                            .withOpacity(0.7),
                                                        size: 25,
                                                      );
                                                    },
                                                  ),
                                                )
                                                : Icon(
                                                  Icons.person,
                                                  color: blueColor.withOpacity(
                                                    0.7,
                                                  ),
                                                  size: 25,
                                                ),
                                      ),
                                      SizedBox(width: 12),

                                      // Uploader info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              uploaderName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            SizedBox(height: 2),

                                            // Show university or role if available
                                            if (snapshot.data != null &&
                                                (snapshot.data!['university'] !=
                                                        null ||
                                                    snapshot.data!['role'] !=
                                                        null))
                                              Text(
                                                '${snapshot.data!['role'] ?? ''} ${snapshot.data!['role'] != null && snapshot.data!['university'] != null ? '• ' : ''}${snapshot.data!['university'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            else
                                              Text(
                                                'Uploaded $timeAgo',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Connect button (only for documents not uploaded by current user)
                                      if (!isCurrentUserDocument)
                                        Container(
                                          margin: EdgeInsets.only(left: 8),
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _sendFriendRequest(
                                                uploaderId,
                                                uploaderName,
                                              );
                                            },
                                            icon: Icon(
                                              Icons.person_add,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'Connect',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: blueColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action buttons
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Close button
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        // Action buttons
                        Row(
                          children: [
                            // Comment button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showCommentDialog(document);
                              },
                              icon: Icon(Icons.comment, size: 16),
                              label: Text('Comment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            
                            // Rating button
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showRatingDialog(document);
                              },
                              icon: Icon(Icons.star, size: 16),
                              label: Text('Rate'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orangeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Helper method to build styled detail rows
  Widget _buildDetailRowStyled(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: blueColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: blueColor),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label + ':',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // Get user profile data
  Future<Map<String, dynamic>?> _getUserProfileData(String userId) async {
    try {
      if (userId.isEmpty) return null;

      // First check profiles collection
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(userId)
              .get();

      if (profileDoc.exists) {
        return profileDoc.data();
      }

      // Fall back to users collection
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        return userDoc.data();
      }

      return null;
    } catch (e) {
      developer.log('Error getting user profile data: $e', name: 'Dashboard');
      return null;
    }
  }

  // Send friend request
  Future<void> _sendFriendRequest(
    String recipientId,
    String recipientName,
  ) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to be logged in to send requests')),
        );
        return;
      }

      // Get current user data
      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserName =
          currentUserData['name'] ?? currentUser.displayName ?? 'User';

      // Check if request already exists
      final existingRequestQuery =
          await FirebaseFirestore.instance
              .collection('friendRequests')
              .where('senderId', isEqualTo: currentUser.uid)
              .where('recipientId', isEqualTo: recipientId)
              .get();

      if (existingRequestQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You already sent a request to this user')),
        );
        return;
      }

      // Create friend request
      await FirebaseFirestore.instance.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'senderName': currentUserName,
        'senderProfileUrl': currentUserData['profileImageUrl'],
        'recipientId': recipientId,
        'recipientName': recipientName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'message': 'I would like to connect regarding your shared document.',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request sent to $recipientName')));
    } catch (e) {
      developer.log('Error sending friend request: $e', name: 'Dashboard');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send request')));
    }
  }

  // Show comment dialog
  void _showCommentDialog(Map<String, dynamic> document) async {
    final TextEditingController commentController = TextEditingController();
    final documentId = document['id'];
    final fileName = document['fileName'] ?? 'Unnamed Document';
    
    // Show loading dialog while fetching comments
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: blueColor),
      ),
    );
    
    // Fetch existing comments
    List<Map<String, dynamic>> comments = [];
    try {
      final commentsSnapshot = await FirebaseFirestore.instance
          .collection('documents')
          .doc(documentId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();
          
      for (var doc in commentsSnapshot.docs) {
        final data = doc.data();
        comments.add({
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'userName': data['userName'] ?? 'Anonymous',
          'userProfileUrl': data['userProfileUrl'],
          'comment': data['comment'] ?? '',
          'createdAt': data['createdAt'] as Timestamp?,
        });
      }
      
      // Close loading dialog
      Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      developer.log('Error fetching comments: $e', name: 'Dashboard');
    }
    
    // Show comments dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 10,
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with document title
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: blueColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Comments - $fileName',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Comments list
              Flexible(
                child: comments.isEmpty
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Be the first to comment!',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16),
                        itemCount: comments.length,
                        separatorBuilder: (context, index) => Divider(),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final userName = comment['userName'];
                          final userComment = comment['comment'];
                          final profileUrl = comment['userProfileUrl'];
                          final createdAt = comment['createdAt'];
                          
                          // Format timestamp
                          String timeAgo = 'Recently';
                          if (createdAt != null) {
                            final now = DateTime.now();
                            final difference = now.difference(createdAt.toDate());
                            
                            if (difference.inDays > 0) {
                              timeAgo = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
                            } else if (difference.inHours > 0) {
                              timeAgo = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
                            } else if (difference.inMinutes > 0) {
                              timeAgo = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
                            } else {
                              timeAgo = 'Just now';
                            }
                          }
                          
                          return Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User info row
                                Row(
                                  children: [
                                    // User avatar
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: blueColor.withOpacity(0.1),
                                        border: Border.all(
                                          color: blueColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: profileUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                profileUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.person,
                                                    color: blueColor.withOpacity(0.7),
                                                    size: 20,
                                                  );
                                                },
                                              ),
                                            )
                                          : Icon(
                                              Icons.person,
                                              color: blueColor.withOpacity(0.7),
                                              size: 20,
                                            ),
                                    ),
                                    SizedBox(width: 8),
                                    
                                    // Username and time
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Comment text
                                Padding(
                                  padding: EdgeInsets.only(left: 44, top: 8),
                                  child: Text(
                                    userComment,
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              
              // Comment input section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: -2,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write your comment here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: blueColor, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blueColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, size: 16),
                              SizedBox(width: 4),
                              Text('Comment'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true && commentController.text.isNotEmpty) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You need to be logged in to comment')),
          );
          return;
        }

        // Get current user data
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userData = userDoc.data() as Map<String, dynamic>?;

        // Add comment to Firestore
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('comments')
            .add({
              'userId': currentUser.uid,
              'userName': userData?['name'] ?? currentUser.displayName ?? 'User',
              'userProfileUrl': userData?['profileImageUrl'],
              'comment': commentController.text,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Award points for commenting
        await ActivityPointsService().awardPoints(
          currentUser.uid,
          2,
          'Commented on a document',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment added successfully')),
        );
      } catch (e) {
        developer.log('Error adding comment: $e', name: 'Dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment')),
        );
      }
    }
  }

  // Show rating dialog
  void _showRatingDialog(Map<String, dynamic> document) async {
    final documentId = document['id'];
    final fileName = document['fileName'] ?? 'Unnamed Document';
    double rating = 3.0; // Default rating
    double averageRating = 0.0;
    int ratingCount = 0;
    
    // Show loading dialog while fetching ratings
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: orangeColor),
      ),
    );
    
    // Fetch document to get average rating
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('documents')
          .doc(documentId)
          .get();
          
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        averageRating = (data['averageRating'] as num?)?.toDouble() ?? 0.0;
        ratingCount = (data['ratingCount'] as num?)?.toInt() ?? 0;
      }
      
      // Check if current user has already rated
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final userRatingDoc = await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('ratings')
            .doc(currentUser.uid)
            .get();
            
        if (userRatingDoc.exists) {
          final data = userRatingDoc.data() as Map<String, dynamic>;
          rating = (data['rating'] as num?)?.toDouble() ?? 3.0;
        }
      }
      
      // Close loading dialog
      Navigator.pop(context);
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);
      developer.log('Error fetching ratings: $e', name: 'Dashboard');
    }
    
    // Show rating dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 10,
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with document title
              Container(
                padding: EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: orangeColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Rate Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              
              // Document info - make scrollable to handle overflow
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Current average rating
                        if (ratingCount > 0) ...[
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Average rating with stars
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Average Rating: ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      averageRating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: orangeColor,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      '/5',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 8),
                                
                                // Visual star representation
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    // Show full, half or empty star based on rating
                                    IconData iconData;
                                    if (index + 0.5 < averageRating) {
                                      iconData = Icons.star;
                                    } else if (index < averageRating) {
                                      iconData = Icons.star_half;
                                    } else {
                                      iconData = Icons.star_border;
                                    }
                                    
                                    return Icon(
                                      iconData,
                                      color: orangeColor,
                                      size: 20,
                                    );
                                  }),
                                ),
                                
                                SizedBox(height: 8),
                                
                                // Total number of ratings
                                Text(
                                  'Based on $ratingCount ${ratingCount == 1 ? 'rating' : 'ratings'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                        
                        Text(
                          'How would you rate this document?',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[800],
                          ),
                        ),
                        
                        // Show previous rating message if user has rated before
                        FutureBuilder<DocumentSnapshot>(
                          future: _authService.currentUser != null 
                              ? FirebaseFirestore.instance
                                  .collection('documents')
                                  .doc(documentId)
                                  .collection('ratings')
                                  .doc(_authService.currentUser!.uid)
                                  .get()
                              : null,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final previousRating = (snapshot.data!.data() as Map<String, dynamic>)['rating'] as double?;
                              if (previousRating != null) {
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Your previous rating: ${previousRating.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                            }
                            return SizedBox(height: 8);
                          },
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Rating stars - fix overflow with Wrap
                        StatefulBuilder(
                          builder: (context, setState) {
                            return Wrap(
                              alignment: WrapAlignment.center,
                              children: List.generate(5, (index) {
                                return IconButton(
                                  icon: Icon(
                                    index < rating ? Icons.star : Icons.star_border,
                                    color: orangeColor,
                                    size: 32,
                                  ),
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      rating = index + 1.0;
                                    });
                                  },
                                );
                              }),
                            );
                          },
                        ),
                        
                        SizedBox(height: 8),
                        
                        // Rating description
                        StatefulBuilder(
                          builder: (context, setState) {
                            String ratingText = '';
                            if (rating <= 1) {
                              ratingText = 'Poor';
                            } else if (rating <= 2) {
                              ratingText = 'Fair';
                            } else if (rating <= 3) {
                              ratingText = 'Good';
                            } else if (rating <= 4) {
                              ratingText = 'Very Good';
                            } else {
                              ratingText = 'Excellent';
                            }
                            
                            return Text(
                              ratingText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: orangeColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orangeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16),
                          SizedBox(width: 4),
                          Text('Submit'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      try {
        final currentUser = _authService.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You need to be logged in to rate')),
          );
          return;
        }

        // Add rating to Firestore
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('ratings')
            .doc(currentUser.uid) // One rating per user
            .set({
              'userId': currentUser.uid,
              'rating': rating,
              'createdAt': FieldValue.serverTimestamp(),
            });

        // Update average rating in document
        final ratingsSnapshot = await FirebaseFirestore.instance
            .collection('documents')
            .doc(documentId)
            .collection('ratings')
            .get();
            
        if (ratingsSnapshot.docs.isNotEmpty) {
          double totalRating = 0;
          for (var doc in ratingsSnapshot.docs) {
            totalRating += doc.data()['rating'] as double;
          }
          double averageRating = totalRating / ratingsSnapshot.docs.length;
          
          await FirebaseFirestore.instance
              .collection('documents')
              .doc(documentId)
              .update({
                'averageRating': averageRating,
                'ratingCount': ratingsSnapshot.docs.length,
              });
        }

        // Award points for rating
        await ActivityPointsService().awardPoints(
          currentUser.uid,
          1,
          'Rated a document',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rating submitted successfully')),
        );
      } catch (e) {
        developer.log('Error adding rating: $e', name: 'Dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating')),
        );
      }
    }
  }

  // Add this method to get total unread messages
  Future<int> _getTotalUnreadMessages() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return 0;

      // Get all chat rooms where user is a participant
      final chatRooms =
          await FirebaseFirestore.instance
              .collection('privateChats')
              .where('participants', arrayContains: currentUser.uid)
              .get();

      int totalUnread = 0;

      // For each chat room, count unread messages
      for (var chatRoom in chatRooms.docs) {
        final unreadMessages =
            await chatRoom.reference
                .collection('messages')
                .where('recipientId', isEqualTo: currentUser.uid)
                .where('isRead', isEqualTo: false)
                .get();

        totalUnread += unreadMessages.docs.length;
      }

      return totalUnread;
    } catch (e) {
      developer.log(
        'Error getting total unread messages: $e',
        name: 'Dashboard',
      );
      return 0;
    }
  }

  // Update the drawer item builder to include unread message count
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showUnreadCount = false,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          Icon(icon, color: blueColor),
          if (showUnreadCount)
            StreamBuilder<QuerySnapshot>(
              stream:
                  title == 'Friend Requests'
                      ? FirebaseFirestore.instance
                          .collection('friendRequests')
                          .where(
                            'recipientId',
                            isEqualTo: _authService.currentUser?.uid,
                          )
                          .where('status', isEqualTo: 'pending')
                          .snapshots()
                      : FirebaseFirestore.instance
                          .collection('privateChats')
                          .where(
                            'participants',
                            arrayContains: _authService.currentUser?.uid,
                          )
                          .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return SizedBox.shrink();

                int count = 0;

                if (title == 'Friend Requests') {
                  // Count pending friend requests
                  count = snapshot.data!.docs.length;
                } else {
                  // Count unread messages
                  int totalUnread = 0;
                  for (var chatRoom in snapshot.data!.docs) {
                    final unreadMessages =
                        chatRoom.reference
                            .collection('messages')
                            .where(
                              'recipientId',
                              isEqualTo: _authService.currentUser?.uid,
                            )
                            .where('isRead', isEqualTo: false)
                            .snapshots();

                    unreadMessages.listen((messages) {
                      totalUnread += messages.docs.length;
                    });
                  }
                  count = totalUnread;
                }

                if (count > 0) {
                  return Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            title == 'Friend Requests'
                                ? Colors.red
                                : orangeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }
}
