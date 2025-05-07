import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({Key? key}) : super(key: key);

  @override
  _FriendRequestsScreenState createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  bool _isLoading = false;
  
  // Search functionality
  final TextEditingController _receivedSearchController = TextEditingController();
  final TextEditingController _sentSearchController = TextEditingController();
  String _receivedSearchQuery = '';
  String _sentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _receivedSearchController.addListener(() {
      setState(() {
        _receivedSearchQuery = _receivedSearchController.text.toLowerCase();
      });
    });
    
    _sentSearchController.addListener(() {
      setState(() {
        _sentSearchQuery = _sentSearchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _receivedSearchController.dispose();
    _sentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // App color scheme
    final blueColor = Color(0xFF2D6DA8);
    final orangeColor = Color(0xFFf06517);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Friend Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: blueColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: orangeColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[100]!,
              Colors.white,
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Received requests tab
            _buildReceivedRequestsTab(),
            
            // Sent requests tab
            _buildSentRequestsTab(),
          ],
        ),
      ),
    );
  }

  // Build search bar widget
  Widget _buildSearchBar(TextEditingController controller, String hintText) {
    final Color blueColor = Color(0xFF2D6DA8);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: blueColor),
          suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  controller.clear();
                },
              )
            : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // Build the received requests tab
  Widget _buildReceivedRequestsTab() {
    if (_authService.currentUser == null) {
      return _buildSignInPrompt();
    }

    return Column(
      children: [
        // Search bar for received requests
        _buildSearchBar(_receivedSearchController, 'Search received requests'),
        
        // List of received requests
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friendRequests')
                .where('recipientId', isEqualTo: _authService.currentUser!.uid)
                .where('status', isEqualTo: 'pending')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading requests: ${snapshot.error}'),
                );
              }

              final requests = snapshot.data?.docs ?? [];
              
              // Filter requests based on search query
              final filteredRequests = _receivedSearchQuery.isEmpty
                  ? requests
                  : requests.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final senderName = (data['senderName'] ?? '').toLowerCase();
                      return senderName.contains(_receivedSearchQuery);
                    }).toList();

              if (filteredRequests.isEmpty) {
                if (_receivedSearchQuery.isNotEmpty) {
                  return _buildEmptyState(
                    'No matching requests',
                    'No friend requests match your search for "$_receivedSearchQuery"'
                  );
                }
                return _buildEmptyState('No pending friend requests', 'You don\'t have any pending friend requests');
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredRequests.length,
                itemBuilder: (context, index) {
                  final request = filteredRequests[index].data() as Map<String, dynamic>;
                  final requestId = filteredRequests[index].id;
                  return _buildRequestCard(
                    requestId: requestId,
                    senderName: request['senderName'] ?? 'Unknown User',
                    senderId: request['senderId'] ?? '',
                    profileUrl: request['senderProfileUrl'],
                    timestamp: request['createdAt'] as Timestamp?,
                    message: request['message'] ?? 'Would like to connect with you',
                    isPending: true,
                    isReceived: true,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Get user profile data
  Future<Map<String, dynamic>?> _getUserProfileData(String userId) async {
    try {
      if (userId.isEmpty) return null;
      
      // First check profiles collection
      final profileDoc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .get();
          
      if (profileDoc.exists) {
        return profileDoc.data();
      }
      
      // Fall back to users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
          
      if (userDoc.exists) {
        return userDoc.data();
      }
      
      return null;
    } catch (e) {
      developer.log('Error getting user profile data: $e', name: 'FriendRequests');
      return null;
    }
  }
  
  // Build the sent requests tab
  Widget _buildSentRequestsTab() {
    if (_authService.currentUser == null) {
      return _buildSignInPrompt();
    }

    return Column(
      children: [
        // Search bar for sent requests
        _buildSearchBar(_sentSearchController, 'Search sent requests'),
        
        // List of sent requests
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('friendRequests')
                .where('senderId', isEqualTo: _authService.currentUser!.uid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading requests: ${snapshot.error}'),
                );
              }

              final requests = snapshot.data?.docs ?? [];
              
              // Filter requests based on search query
              final filteredRequests = _sentSearchQuery.isEmpty
                  ? requests
                  : requests.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final recipientName = (data['recipientName'] ?? '').toLowerCase();
                      return recipientName.contains(_sentSearchQuery);
                    }).toList();

              if (filteredRequests.isEmpty) {
                if (_sentSearchQuery.isNotEmpty) {
                  return _buildEmptyState(
                    'No matching requests',
                    'No friend requests match your search for "$_sentSearchQuery"'
                  );
                }
                return _buildEmptyState('No sent requests', 'You haven\'t sent any friend requests yet');
              }

              return ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredRequests.length,
                itemBuilder: (context, index) {
                  final request = filteredRequests[index].data() as Map<String, dynamic>;
                  final requestId = filteredRequests[index].id;
                  final isPending = request['status'] == 'pending';
                  final recipientId = request['recipientId'] ?? '';
                  
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUserProfileData(recipientId),
                    builder: (context, profileSnapshot) {
                      // Get recipient's profile image if available
                      final profileImageUrl = profileSnapshot.data?['profileImageUrl'] ?? 
                                              profileSnapshot.data?['secureUrl'];
                      
                      return _buildRequestCard(
                        requestId: requestId,
                        senderName: request['recipientName'] ?? 'Unknown User',
                        senderId: recipientId,
                        profileUrl: profileImageUrl,
                        timestamp: request['createdAt'] as Timestamp?,
                        message: request['message'] ?? 'You sent a connection request',
                        isPending: isPending,
                        isReceived: false,
                        status: request['status'] ?? 'pending',
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Build a request card
  Widget _buildRequestCard({
    required String requestId,
    required String senderName,
    required String senderId,
    String? profileUrl,
    Timestamp? timestamp,
    required String message,
    required bool isPending,
    required bool isReceived,
    String status = 'pending',
  }) {
    final Color blueColor = Color(0xFF2D6DA8);
    final Color orangeColor = Color(0xFFf06517);
    
    // Format time
    String timeText = 'Recently';
    if (timestamp != null) {
      final now = DateTime.now();
      final difference = now.difference(timestamp.toDate());
      
      if (difference.inDays > 0) {
        timeText = '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
      } else if (difference.inHours > 0) {
        timeText = '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inMinutes > 0) {
        timeText = '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      } else {
        timeText = 'Just now';
      }
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                // Profile image
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isReceived ? blueColor.withOpacity(0.3) : orangeColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: profileUrl != null
                      ? Image.network(
                          profileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              color: isReceived ? blueColor : orangeColor,
                              size: 25,
                            );
                          },
                        )
                      : Icon(
                          Icons.person,
                          color: isReceived ? blueColor : orangeColor,
                          size: 25,
                        ),
                  ),
                ),
                SizedBox(width: 12),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Status indicator for sent requests
                if (!isReceived)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: status == 'pending'
                          ? Colors.amber.withOpacity(0.1)
                          : status == 'accepted'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: status == 'pending'
                            ? Colors.amber.withOpacity(0.3)
                            : status == 'accepted'
                                ? Colors.green.withOpacity(0.3)
                                : Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      status == 'pending'
                          ? 'Pending'
                          : status == 'accepted'
                              ? 'Accepted'
                              : 'Declined',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: status == 'pending'
                            ? Colors.amber[800]
                            : status == 'accepted'
                                ? Colors.green[700]
                                : Colors.red[700],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Message
            if (message.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            
            // Action buttons (only for received pending requests)
            if (isReceived && isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Decline button
                  TextButton(
                    onPressed: () => _updateRequestStatus(requestId, 'declined'),
                    child: Text(
                      'Decline',
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
                  SizedBox(width: 8),
                  
                  // Accept button
                  ElevatedButton(
                    onPressed: () => _updateRequestStatus(requestId, 'accepted'),
                    child: Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              
            // Cancel button (only for sent pending requests)
            if (!isReceived && isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _cancelRequest(requestId),
                    icon: Icon(Icons.close, size: 16),
                    label: Text('Cancel Request'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
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
    );
  }

  // Empty state widget with improved design
  Widget _buildEmptyState(String title, String message) {
    final Color blueColor = Color(0xFF2D6DA8);
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: blueColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 50,
                color: blueColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Sign in prompt widget
  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'Sign In Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'You need to be signed in to view friend requests',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2D6DA8),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ensure friend list exists for a user
  Future<void> _ensureFriendListExists(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
          
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // If the friends field doesn't exist, initialize it with an empty array
        if (!userData.containsKey('friends')) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'friends': [],
          });
          developer.log('Initialized empty friends list for user $userId', name: 'FriendRequests');
        }
      }
    } catch (e) {
      developer.log('Error ensuring friend list exists: $e', name: 'FriendRequests');
    }
  }

  // Update request status
  Future<void> _updateRequestStatus(String requestId, String status) async {
    try {
      setState(() => _isLoading = true);
      
      developer.log('Updating request $requestId to status: $status', name: 'FriendRequests');
      
      // Get the request data first to access sender and recipient information
      final requestDoc = await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .get();
          
      if (!requestDoc.exists) {
        developer.log('Request $requestId not found', name: 'FriendRequests');
        throw Exception('Request not found');
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final senderId = requestData['senderId'] as String;
      final recipientId = requestData['recipientId'] as String;
      
      developer.log('Request is from $senderId to $recipientId', name: 'FriendRequests');
      
      // Update the request status
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      developer.log('Updated request status to $status', name: 'FriendRequests');
      
      // If the request is accepted, add users to each other's friends lists
      if (status == 'accepted') {
        developer.log('Request accepted, adding users to each other\'s friends lists', name: 'FriendRequests');
        
        // Make sure the friends fields exist
        await _ensureFriendListExists(senderId);
        await _ensureFriendListExists(recipientId);
        
        try {
          // Create or update sender document with recipient in friends array
          developer.log('Adding recipient $recipientId to sender\'s friends list', name: 'FriendRequests');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .set({
            'friends': FieldValue.arrayUnion([recipientId])
          }, SetOptions(merge: true));
          
          // Create or update recipient document with sender in friends array
          developer.log('Adding sender $senderId to recipient\'s friends list', name: 'FriendRequests');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(recipientId)
              .set({
            'friends': FieldValue.arrayUnion([senderId])
          }, SetOptions(merge: true));
          
          // Verify the friends were added
          final senderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .get();
              
          final recipientDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(recipientId)
              .get();
              
          if (senderDoc.exists && recipientDoc.exists) {
            final senderData = senderDoc.data() as Map<String, dynamic>;
            final recipientData = recipientDoc.data() as Map<String, dynamic>;
            
            final senderFriends = senderData['friends'] as List<dynamic>? ?? [];
            final recipientFriends = recipientData['friends'] as List<dynamic>? ?? [];
            
            developer.log('Sender friends after update: ${senderFriends.join(", ")}', name: 'FriendRequests');
            developer.log('Recipient friends after update: ${recipientFriends.join(", ")}', name: 'FriendRequests');
          }
          
          developer.log('Added users to each other\'s friends lists using merge option', name: 'FriendRequests');
        } catch (e) {
          developer.log('Error adding friends with merge: $e', name: 'FriendRequests');
          // Fallback to the update method if set with merge fails
          await FirebaseFirestore.instance
              .collection('users')
              .doc(senderId)
              .update({
            'friends': FieldValue.arrayUnion([recipientId])
          });
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(recipientId)
              .update({
            'friends': FieldValue.arrayUnion([senderId])
          });
          
          developer.log('Added users to each other\'s friends lists using update fallback', name: 'FriendRequests');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'accepted'
                ? 'Friend request accepted'
                : 'Friend request declined'
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      developer.log('Error updating request status: $e', name: 'FriendRequests');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update request: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Cancel a sent request
  Future<void> _cancelRequest(String requestId) async {
    try {
      setState(() => _isLoading = true);
      
      await FirebaseFirestore.instance
          .collection('friendRequests')
          .doc(requestId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      developer.log('Error cancelling request: $e', name: 'FriendRequests');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel request: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
} 