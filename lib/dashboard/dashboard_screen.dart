import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import 'dart:developer' as developer;
import 'dashboard_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Define the exact orange color
  final Color orangeColor = Color(0xFFf06517);

  // Define the exact blue color
  final Color blueColor = Color(0xFF2D6DA8);

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
                        child: Container(
                          width: width * 0.08,
                          height: width * 0.08,
                          decoration: BoxDecoration(shape: BoxShape.circle),
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
                        onTap:
                            () => DashboardService.showFeatureNotAvailable(
                              context,
                              "Friends",
                            ),
                        width: width,
                        height: height,
                      ),
                      _buildMenuButton(
                        title: "Bot",
                        icon: Icons.smart_toy,
                        color: orangeColor,
                        onTap:
                            () => DashboardService.showFeatureNotAvailable(
                              context,
                              "Bot",
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
                            () => DashboardService.showFeatureNotAvailable(
                              context,
                              "ChatRoom",
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
      // Get reference to Firestore collection
      final documentsRef = FirebaseFirestore.instance.collection('documents');

      // Query for documents ordered by upload timestamp (most recent first)
      final snapshot =
          await documentsRef
              .orderBy('uploadedAt', descending: true)
              .limit(10) // Limit to 10 documents
              .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Process query results into the format needed by the UI
      List<Map<String, dynamic>> result = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

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
        });
      }

      return result;
    } catch (e) {
      developer.log('Error fetching documents: $e', name: 'Dashboard');
      return [];
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
        // Open document on tap
        DashboardService.openDocument(context, fileUrl, fileName);
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
                      // Show document options menu (to be implemented later)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Document options coming soon'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
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

                  // Download button with improved styling
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: orangeColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: InkWell(
                      onTap: () {
                        DashboardService.openDocument(
                          context,
                          fileUrl,
                          fileName,
                        );
                      },
                      child: Icon(Icons.download, size: 14, color: orangeColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Method to open document
  void _openDocument(String url, String fileName) async {
    DashboardService.openDocument(context, url, fileName);
  }

  // Helper method to get icon for file type when no asset is available
  IconData _getIconForFileType(String extension) {
    return DashboardService.getIconForFileType(extension);
  }
}
