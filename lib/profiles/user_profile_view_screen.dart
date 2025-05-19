import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';
import '../model/activity_points_model.dart';
import '../model/badge_model.dart' as models;
import '../services/badge_service.dart';
import '../widgets/badge_widget.dart';
import '../widgets/profile_badge_overlay.dart' as overlay;
import '../services/activity_points_service.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;
  final String initialUserName;
  
  const UserProfileViewScreen({
    required this.userId,
    required this.initialUserName,
    Key? key
  }) : super(key: key);
  
  @override
  _UserProfileViewScreenState createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final BadgeService _badgeService = BadgeService();
  
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _profileData = {};
  Map<String, dynamic> _statsData = {};
  ActivityPointsModel? _activityPoints;
  bool _isLoadingPoints = true;
  bool _isFriend = false;
  bool _hasPendingRequest = false;
  List<Map<String, dynamic>> _recentDocuments = [];
  
  // Badges data
  List<models.Badge> _userBadges = [];
  models.Badge? _primaryBadge;
  bool _isLoadingBadges = true;
  
  // App colors
  final Color blueColor = const Color(0xFF2D6DA8);
  final Color orangeColor = const Color(0xFFf06517);
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadActivityPoints();
    _loadUserBadges();
  }
  
  Future<void> _loadUserBadges() async {
    setState(() => _isLoadingBadges = true);
    
    try {
      // Get user's activity points to determine badge eligibility
      final activityPointsDoc = await _firestore.collection('activity_points').doc(widget.userId).get();
      int activityPoints = 0;
      
      if (activityPointsDoc.exists) {
        final data = activityPointsDoc.data() as Map<String, dynamic>;
        activityPoints = data['totalPoints'] ?? 0;
      }
      
      // Get user badges and validate against current activity points
      // Use the new method that ensures badges accurately reflect current points
      _userBadges = await _badgeService.validateAndUpdateUserBadges(widget.userId, activityPoints);
      
      // Get primary badge (highest earned)
      _primaryBadge = await _badgeService.getHighestEarnedBadge(widget.userId);
      
    } catch (e) {
      developer.log('Error loading user badges: $e', name: 'UserProfileView');
    } finally {
      setState(() => _isLoadingBadges = false);
    }
  }
  
  Future<void> _loadActivityPoints() async {
    setState(() => _isLoadingPoints = true);
    
    try {
      // Get activity points data
      final activityPointsDoc = await _firestore.collection('activity_points').doc(widget.userId).get();
      
      if (activityPointsDoc.exists) {
        final data = activityPointsDoc.data() as Map<String, dynamic>;
        _activityPoints = ActivityPointsModel.fromMap(data, widget.userId);
      }
    } catch (e) {
      developer.log('Error loading activity points: $e', name: 'UserProfileView');
    } finally {
      setState(() => _isLoadingPoints = false);
    }
  }
  
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      // Get basic user data
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      
      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
      }
      
      // Get profile image data
      final profileDoc = await _firestore.collection('profiles').doc(widget.userId).get();
      if (profileDoc.exists) {
        _profileData = profileDoc.data() as Map<String, dynamic>;
      }
      
      // Check if already friends
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        // Check friend status
        final friendQuerySnapshot = await _firestore
            .collection('friends')
            .where('userId', isEqualTo: currentUser.uid)
            .where('friendId', isEqualTo: widget.userId)
            .limit(1)
            .get();
            
        _isFriend = friendQuerySnapshot.docs.isNotEmpty;
        
        // Check pending request
        final requestQuerySnapshot = await _firestore
            .collection('friendRequests')
            .where('senderId', isEqualTo: currentUser.uid)
            .where('recipientId', isEqualTo: widget.userId)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
            
        _hasPendingRequest = requestQuerySnapshot.docs.isNotEmpty;
      }
      
      // Load user stats (documents, connections, etc.)
      await _loadUserStats();
      
      // Load recent documents
      await _loadRecentDocuments();
      
    } catch (e) {
      developer.log('Error loading profile data: $e', name: 'UserProfileView');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile data')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadUserStats() async {
    try {
      // Get document count
      final documentsQuery = await _firestore
          .collection('documents')
          .where('uploaderId', isEqualTo: widget.userId)
          .get();
      
      // Get connections count - Check the user document for friends array
      final userDoc = await _firestore.collection('users').doc(widget.userId).get();
      int connectionsCount = 0;
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData.containsKey('friends') && userData['friends'] is List) {
          connectionsCount = (userData['friends'] as List).length;
        }
      }
          
      // Get activity score from activity_points collection
      int activityPoints = 0;
      final activityPointsDoc = await _firestore
          .collection('activity_points')
          .doc(widget.userId)
          .get();
          
      if (activityPointsDoc.exists) {
        final activityData = activityPointsDoc.data() as Map<String, dynamic>;
        activityPoints = activityData['totalPoints'] ?? 0;
      }
          
      // Check recent activity (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentActivityQuery = await _firestore
          .collection('activity_logs')
          .where('userId', isEqualTo: widget.userId)
          .where('timestamp', isGreaterThan: thirtyDaysAgo)
          .get();
          
      _statsData = {
        'documentCount': documentsQuery.docs.length,
        'connectionCount': connectionsCount,
        'activityScore': activityPoints > 0 ? activityPoints : 
                      (documentsQuery.docs.length * 5 + connectionsCount * 2 + recentActivityQuery.docs.length),
        'recentActivity': recentActivityQuery.docs.length,
      };
      
    } catch (e) {
      developer.log('Error loading user stats: $e', name: 'UserProfileView');
    }
  }
  
  Future<void> _loadRecentDocuments() async {
    try {
      final documentsQuery = await _firestore
          .collection('documents')
          .where('uploaderId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();
          
      _recentDocuments = documentsQuery.docs
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['fileName'] ?? data['displayName'] ?? 'Untitled Document',
              'type': data['documentType'] ?? data['format'] ?? 'Unknown',
              'uploadedAt': data['createdAt'] ?? data['uploadedAt'],
              'thumbnailUrl': data['thumbnailUrl'],
              'downloadUrl': data['secureUrl'] ?? data['url'],
              'category': data['category'],
              'course': data['course'],
              'semester': data['semester'],
            };
          })
          .toList();
          
    } catch (e) {
      developer.log('Error loading recent documents: $e', name: 'UserProfileView');
    }
  }
  
  Future<void> _sendFriendRequest() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to send requests')),
        );
        return;
      }
      
      // Get current user data
      final currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
          
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserName = currentUserData['name'] ?? currentUser.displayName ?? 'User';
      
      // Create friend request
      await _firestore.collection('friendRequests').add({
        'senderId': currentUser.uid,
        'senderName': currentUserName,
        'senderProfileUrl': currentUserData['profileImageUrl'],
        'recipientId': widget.userId,
        'recipientName': _userData['name'] ?? widget.initialUserName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'message': 'I would like to connect with you.',
      });
      
      setState(() {
        _hasPendingRequest = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection request sent to ${_userData['name'] ?? widget.initialUserName}. You\'ll receive ${ActivityPointsService.CONNECTION_POINTS} points when accepted!'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      developer.log('Error sending friend request: $e', name: 'UserProfileView');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send request')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? _buildLoadingView()
        : _buildProfileView(),
    );
  }
  
  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: blueColor),
          const SizedBox(height: 16),
          Text(
            'Loading profile...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileView() {
    final userName = _userData['name'] ?? widget.initialUserName;
    final userRole = _userData['role'] ?? 'Student';
    final university = _userData['university'] ?? 'Not specified';
    final profileImageUrl = _profileData['secureUrl'] ?? _userData['profileImageUrl'];
    
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar(
                backgroundColor: blueColor,
                expandedHeight: MediaQuery.of(context).size.height * 0.35,
                pinned: true,
                forceElevated: innerBoxIsScrolled,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildProfileHeader(
                    name: userName,
                    role: userRole,
                    university: university,
                    imageUrl: profileImageUrl,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: Container(
                    decoration: BoxDecoration(
                      color: blueColor,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: TabBar(
                      tabs: const [
                        Tab(text: 'INFO'),
                        Tab(text: 'CONTRIBUTIONS'),
                        Tab(text: 'ACTIVITY'),
                      ],
                      indicatorColor: orangeColor,
                      indicatorWeight: 5,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white.withOpacity(0.7),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildSafeAreaTab(_buildInfoTab()),
            _buildSafeAreaTab(_buildContributionsTab()),
            _buildSafeAreaTab(_buildActivityTab()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSafeAreaTab(Widget child) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Builder(
        builder: (BuildContext context) {
          return CustomScrollView(
            slivers: <Widget>[
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverPadding(
                padding: EdgeInsets.zero,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [child],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildProfileHeader({
    required String name,
    required String role,
    required String university,
    String? imageUrl,
  }) {
    // Get available screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.35; // Limit to 35% of screen height
    final avatarSize = 100.0;
    
    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            blueColor,
            blueColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile image with badge overlay
                Stack(
                  children: [
                    // Profile image
                    Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: imageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 36,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                    ),
                    
                    // Badge overlay (if badge earned)
                    if (_primaryBadge != null && !_isLoadingBadges)
                      overlay.ProfileBadgeOverlay(
                        badge: _primaryBadge!,
                        avatarSize: avatarSize,
                      ),
                  ],
                ),
                SizedBox(height: 12),
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                // Role and university
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        '$role at $university',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          _buildStatsCards(),
          const SizedBox(height: 24),
          
          // About section
          _buildSectionHeader('About'),
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _userData['bio'] ?? _profileData['bio'] ?? 
                'This user has not added a bio yet.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[800],
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Badges section - Add badges here
          if (_userBadges.isNotEmpty && !_isLoadingBadges) ...[
            _buildSectionHeader('Badges'),
            Card(
              elevation: 2,
              margin: EdgeInsets.zero,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BadgesRow(
                      badges: _userBadges,
                      size: 60,
                      onBadgeTap: _showBadgeDetails,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Academic info
          _buildSectionHeader('Academic Information'),
          Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.school, 
                    label: 'University', 
                    value: _userData['university'] ?? 'Not specified'
                  ),
                  Divider(height: 16, thickness: 1, color: Colors.grey[200]),
                  _buildInfoRow(
                    icon: Icons.person, 
                    label: 'Role', 
                    value: _userData['role'] ?? 'Student'
                  ),
                  Divider(height: 16, thickness: 1, color: Colors.grey[200]),
                  _buildInfoRow(
                    icon: Icons.book, 
                    label: 'Field of Study', 
                    value: _userData['fieldOfStudy'] ?? 'Not specified'
                  ),
                  Divider(height: 16, thickness: 1, color: Colors.grey[200]),
                  _buildInfoRow(
                    icon: Icons.timeline, 
                    label: 'Year/Level', 
                    value: _userData['yearLevel'] ?? 'Not specified'
                  ),
                ],
              ),
            ),
          ),
          // Extra space at bottom for better scrolling
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildContributionsTab() {
    // Use a StreamBuilder for real-time updates
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('documents')
          .where('uploaderId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: blueColor),
          );
        }
        
        // Check if we have documents
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder_open,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No documents shared yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This user hasn\'t uploaded any documents',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Convert documents to a list
        final documents = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'title': data['fileName'] ?? data['displayName'] ?? 'Untitled Document',
            'type': data['documentType'] ?? data['format'] ?? 'Unknown',
            'uploadedAt': data['createdAt'] ?? data['uploadedAt'],
            'thumbnailUrl': data['thumbnailUrl'],
            'downloadUrl': data['secureUrl'] ?? data['url'],
            'category': data['category'],
            'course': data['course'],
            'semester': data['semester'],
          };
        }).toList();
        
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header with count
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: orangeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Contributions (${documents.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Documents list
                if (documents.isNotEmpty)
                  ListView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      final doc = documents[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        color: Colors.white,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            // Just show a message with document name
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Viewing document: ${doc['title']}')),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Document icon - larger with no container
                                _getDocumentTypeIcon(doc['type'], 60),
                                SizedBox(width: 16),
                                
                                // Document details
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      Text(
                                        doc['title'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      
                                      // Course info if available and bottom row with tags
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Document type tag
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getColorForDocType(doc['type']).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Text(
                                              _getFormattedDocType(doc['type']),
                                              style: TextStyle(
                                                color: _getColorForDocType(doc['type']),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          
                                          // Extra metadata if available
                                          if (doc['category'] != null) ...[
                                            SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: blueColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: Text(
                                                doc['category'].toString(),
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                          
                                          Spacer(),
                                          
                                          // Timestamp with icon
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded, 
                                                size: 11,
                                                color: Colors.grey[400]
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                _formatTimestamp(doc['uploadedAt']),
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 10,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
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
                    },
                  ),
                
                // Extra space at bottom for better scrolling
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Helper method to build document type icon with appropriate asset
  Widget _getDocumentTypeIcon(String type, double size) {
    // Normalize type to lowercase
    String normalizedType = type.toLowerCase();
    
    // Check file type and return appropriate asset
    if (normalizedType.contains('pdf')) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset('assets/pdf.png', width: size, height: size),
      );
    } else if (normalizedType.contains('doc')) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset('assets/doc.png', width: size, height: size),
      );
    } else if (normalizedType.contains('ppt')) {
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Image.asset('assets/ppt.png', width: size, height: size),
      );
    } else {
      // Fallback to icon for unknown types
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: _getColorForDocType(type).withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          _getFileIcon(type),
          color: _getColorForDocType(type),
          size: size * 0.9,
        ),
      );
    }
  }
  
  // Helper method to get color for document type
  Color _getColorForDocType(String type) {
    String normalizedType = type.toLowerCase();
    if (normalizedType.contains('pdf')) {
      return Colors.red;
    } else if (normalizedType.contains('doc')) {
      return Colors.blue;
    } else if (normalizedType.contains('ppt')) {
      return Colors.orange;
    } else if (normalizedType.contains('xls')) {
      return Colors.green;
    } else {
      return blueColor;
    }
  }
  
  // Helper method to get formatted document type
  String _getFormattedDocType(String type) {
    String normalizedType = type.toLowerCase();
    if (normalizedType.contains('pdf')) {
      return 'PDF';
    } else if (normalizedType.contains('doc')) {
      return 'DOC';
    } else if (normalizedType.contains('ppt')) {
      return 'PPT';
    } else if (normalizedType.contains('xls')) {
      return 'XLS';
    } else {
      return type.toUpperCase();
    }
  }
  
  Widget _buildActivityTab() {
    // Use static activity data for now instead of relying on Firestore queries
    // that might require complex indices
    final userName = _userData['name'] ?? widget.initialUserName;
    final university = _userData['university'] ?? 'Not specified';
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActivityScoreCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('Recent Activity'),
          
          // Use the userName and university in placeholder items instead of hardcoded values
          _buildActivityItem(
            action: 'Joined',
            subject: '$university community',
            time: DateTime.now().subtract(const Duration(days: 2)),
            color: Colors.blue[700]!,
          ),
          _buildActivityItem(
            action: 'Updated profile',
            subject: 'Added education information',
            time: DateTime.now().subtract(const Duration(days: 5)),
            color: Colors.green[700]!,
          ),
          if (_statsData['connectionCount'] != null && _statsData['connectionCount'] > 0)
            _buildActivityItem(
              action: 'Connected with others',
              subject: 'Made ${_statsData['connectionCount']} connections',
              time: DateTime.now().subtract(const Duration(days: 7)),
              color: Colors.orange[700]!,
            ),
          if (_statsData['documentCount'] != null && _statsData['documentCount'] > 0)
            _buildActivityItem(
              action: 'Shared resources',
              subject: 'Uploaded ${_statsData['documentCount']} documents',
              time: DateTime.now().subtract(const Duration(days: 10)),
              color: Colors.purple[700]!,
            ),
          // Always show at least one more item
          _buildActivityItem(
            action: 'Created account',
            subject: 'Welcome to Academia Hub, $userName!',
            time: DateTime.now().subtract(const Duration(days: 14)),
            color: Colors.teal[700]!,
          ),
          // Extra space at bottom for better scrolling
          const SizedBox(height: 30),
        ],
      ),
    );
  }
  
  Widget _buildActivityScoreCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insights, color: orangeColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Activity Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        orangeColor,
                        orangeColor.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: orangeColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${_statsData['activityScore'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _getActivityDescription(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActivityItem({
    required String action,
    required String subject,
    required DateTime time,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                _getActivityIcon(action),
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subject,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(time),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
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
  
  Widget _buildStatsCards() {
    return Column(
      children: [
        // Use StreamBuilder to listen for real-time updates to user document and documents
        StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('users').doc(widget.userId).snapshots(),
          builder: (context, userSnapshot) {
            // Get connection count from stream
            int connectionCount = 0;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData = userSnapshot.data!.data() as Map<String, dynamic>;
              if (userData.containsKey('friends') && userData['friends'] is List) {
                connectionCount = (userData['friends'] as List).length;
                
                // Update stats data with new connection count
                if (_statsData.containsKey('connectionCount') && 
                    _statsData['connectionCount'] != connectionCount) {
                  // Update stats data with new value
                  _statsData['connectionCount'] = connectionCount;
                }
              }
            }
            
            // Use another StreamBuilder for real-time document count
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                .collection('documents')
                .where('uploaderId', isEqualTo: widget.userId)
                .snapshots(),
              builder: (context, documentsSnapshot) {
                // Get document count from stream
                int documentCount = 0;
                if (documentsSnapshot.hasData) {
                  documentCount = documentsSnapshot.data!.docs.length;
                  
                  // Update stats data with new document count
                  if (_statsData.containsKey('documentCount') && 
                      _statsData['documentCount'] != documentCount) {
                    // Update stats data with new value
                    _statsData['documentCount'] = documentCount;
                  }
                } else {
                  // Use the cached document count if stream hasn't loaded yet
                  documentCount = _statsData['documentCount'] ?? 0;
                }
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          title: 'Documents',
                          value: '$documentCount',
                          icon: Icons.insert_drive_file,
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          title: 'Connections',
                          value: '$connectionCount',
                          icon: Icons.people,
                        ),
                        _buildDivider(),
                        _buildStatItem(
                          title: 'Points',
                          value: '${_statsData['activityScore'] ?? 0}',
                          icon: Icons.emoji_events,
                        ),
                      ],
                    ),
                  ),
                );
              }
            );
          }
        ),
        
        // Add activity points card if available
        if (_activityPoints != null && !_isLoadingPoints)
          _buildActivityPointsCard(),
      ],
    );
  }
  
  Widget _buildActivityPointsCard() {
    // Count completed activities
    int completedActivities = 0;
    final oneTimeActivities = _activityPoints!.oneTimeActivities;
    
    if (oneTimeActivities.containsKey(ActivityType.profileCompletion) && 
        oneTimeActivities[ActivityType.profileCompletion] == true) {
      completedActivities++;
    }
    if (oneTimeActivities.containsKey(ActivityType.universityEmail) && 
        oneTimeActivities[ActivityType.universityEmail] == true) {
      completedActivities++;
    }
    if (oneTimeActivities.containsKey(ActivityType.firstLogin) && 
        oneTimeActivities[ActivityType.firstLogin] == true) {
      completedActivities++;
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            spreadRadius: 0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: orangeColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: orangeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Achievements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed $completedActivities out of 3 one-time activities',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: orangeColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_activityPoints!.totalPoints} pts',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Activity breakdown
          _buildAchievementItem(
            'Profile Completion',
            oneTimeActivities[ActivityType.profileCompletion] ?? false,
          ),
          const SizedBox(height: 12),
          _buildAchievementItem(
            'University Email Verification',
            oneTimeActivities[ActivityType.universityEmail] ?? false,
          ),
          const SizedBox(height: 12),
          _buildAchievementItem(
            'First Login',
            oneTimeActivities[ActivityType.firstLogin] ?? false,
          ),
        ],
      ),
    );
  }
  
  Widget _buildAchievementItem(String title, bool completed) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.circle_outlined,
          color: completed ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: completed ? Colors.black87 : Colors.grey[700],
              fontWeight: completed ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }
  
  Widget _buildStatItem({required String title, required String value, required IconData icon}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: blueColor,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: orangeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label, 
    required String value
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(right: 10),
            child: Icon(
              icon,
              size: 18,
              color: blueColor.withOpacity(0.8),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getActivityIcon(String action) {
    if (action.contains('Upload')) return Icons.upload_file;
    if (action.contains('Join')) return Icons.group;
    if (action.contains('Connect')) return Icons.people;
    if (action.contains('Ask')) return Icons.help;
    return Icons.event_note;
  }
  
  IconData _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'image':
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown time';
    }
    
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }
  
  String _getActivityDescription() {
    final score = _statsData['activityScore'] ?? 0;
    
    if (score >= 100) {
      return 'Power User: Extremely active and valuable contributor to the community!';
    } else if (score >= 50) {
      return 'Active Contributor: Regularly shares content and engages with others.';
    } else if (score >= 20) {
      return 'Regular Participant: Getting involved in the community.';
    } else {
      return 'New Member: Just starting their journey in Academia Hub.';
    }
  }

  // Method to show badge details in a modal dialog
  void _showBadgeDetails(models.Badge badge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge header with color
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: badge.color.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  BadgeWidget(
                    badge: badge,
                    size: 60,
                    showUnearned: true,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: badge.color,
                          ),
                        ),
                        if (badge.isEarned) ...[
                          SizedBox(height: 4),
                          Text(
                            'Earned: ${_formatTimestamp(badge.earnedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ] else ...[
                          SizedBox(height: 4),
                          Text(
                            'Required: ${badge.pointsRequired} points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Badge description
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20),
                  // Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
} 