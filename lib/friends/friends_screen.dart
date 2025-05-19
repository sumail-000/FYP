import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';
import 'private_chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({Key? key}) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  List<String> _pinnedFriends = [];

  // App colors
  final Color blueColor = Color(0xFF2D6DA8);
  final Color orangeColor = Color(0xFFf06517);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadPinnedFriends();
    developer.log('FriendsScreen initialized', name: 'Friends');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load pinned friends from Firestore
  Future<void> _loadPinnedFriends() async {
    try {
      if (_authService.currentUser == null) {
        developer.log(
          'No current user, cannot load pinned friends',
          name: 'Friends',
        );
        return;
      }

      developer.log(
        'Loading pinned friends for user ${_authService.currentUser!.uid}',
        name: 'Friends',
      );

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        developer.log(
          'User document found: ${userData.keys.join(', ')}',
          name: 'Friends',
        );

        if (userData.containsKey('pinnedFriends') &&
            userData['pinnedFriends'] is List) {
          setState(() {
            _pinnedFriends = List<String>.from(userData['pinnedFriends']);
          });
          developer.log(
            'Loaded ${_pinnedFriends.length} pinned friends',
            name: 'Friends',
          );
        } else {
          developer.log(
            'No pinnedFriends field found in user document',
            name: 'Friends',
          );
        }

        // Debug: Check if friends field exists
        if (userData.containsKey('friends')) {
          final friendsList = userData['friends'] as List<dynamic>? ?? [];
          developer.log(
            'User has ${friendsList.length} friends in total',
            name: 'Friends',
          );
        } else {
          developer.log(
            'No friends field found in user document',
            name: 'Friends',
          );
        }
      } else {
        developer.log('User document not found', name: 'Friends');
      }
    } catch (e) {
      developer.log('Error loading pinned friends: $e', name: 'Friends');
    }
  }

  // Update pinned friend status
  Future<void> _togglePinFriend(String friendId, String friendName) async {
    try {
      if (_authService.currentUser == null) return;

      setState(() => _isLoading = true);

      final isPinned = _pinnedFriends.contains(friendId);

      if (isPinned) {
        // Unpin friend
        _pinnedFriends.remove(friendId);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_authService.currentUser!.uid)
            .update({'pinnedFriends': _pinnedFriends});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendName unpinned'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Check if max pins reached
        if (_pinnedFriends.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only pin up to 3 friends'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red[400],
            ),
          );
          return;
        }

        // Pin friend
        _pinnedFriends.add(friendId);

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_authService.currentUser!.uid)
            .update({'pinnedFriends': _pinnedFriends});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$friendName pinned'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() {
        // Already updated _pinnedFriends
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error toggling pin status: $e', name: 'Friends');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update pin status'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Delete friend
  Future<void> _deleteFriend(String friendId, String friendName) async {
    try {
      if (_authService.currentUser == null) return;

      setState(() => _isLoading = true);

      // 1. Update current user's friends list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_authService.currentUser!.uid)
          .update({
            'friends': FieldValue.arrayRemove([friendId]),
          });

      // 2. Update friend's friends list (removing current user)
      await FirebaseFirestore.instance.collection('users').doc(friendId).update(
        {
          'friends': FieldValue.arrayRemove([_authService.currentUser!.uid]),
        },
      );

      // 3. If pinned, remove from pinned list
      if (_pinnedFriends.contains(friendId)) {
        _pinnedFriends.remove(friendId);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_authService.currentUser!.uid)
            .update({'pinnedFriends': _pinnedFriends});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$friendName removed from friends'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      developer.log('Error deleting friend: $e', name: 'Friends');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove friend'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[400],
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> _getUserProfileData(String userId) async {
    try {
      if (userId.isEmpty) {
        developer.log(
          'Empty user ID provided to _getUserProfileData',
          name: 'Friends',
        );
        return null;
      }

      developer.log('Getting profile data for user $userId', name: 'Friends');

      // First check profiles collection
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(userId)
              .get();

      if (profileDoc.exists) {
        developer.log(
          'Found profile in profiles collection for $userId',
          name: 'Friends',
        );
        return profileDoc.data();
      }

      // Fall back to users collection
      developer.log(
        'Profile not found in profiles collection, checking users collection for $userId',
        name: 'Friends',
      );
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      if (userDoc.exists) {
        developer.log(
          'Found profile in users collection for $userId',
          name: 'Friends',
        );
        return userDoc.data();
      }

      developer.log('No profile data found for user $userId', name: 'Friends');
      return null;
    } catch (e) {
      developer.log(
        'Error getting user profile data for $userId: $e',
        name: 'Friends',
      );
      return null;
    }
  }

  // Add this method to get unread message count
  Future<int> _getUnreadMessageCount(String friendId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return 0;

      // Create chat room ID
      final List<String> ids = [currentUser.uid, friendId];
      ids.sort();
      final chatRoomId = ids.join('_');

      // Get unread messages count
      final unreadMessages =
          await FirebaseFirestore.instance
              .collection('privateChats')
              .doc(chatRoomId)
              .collection('messages')
              .where('recipientId', isEqualTo: currentUser.uid)
              .where('isRead', isEqualTo: false)
              .get();

      return unreadMessages.docs.length;
    } catch (e) {
      developer.log('Error getting unread message count: $e', name: 'Friends');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Friends',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: blueColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            margin: EdgeInsets.all(16),
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
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends',
                prefixIcon: Icon(Icons.search, color: blueColor),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ),

          // Friends list
          Expanded(child: _buildFriendsList()),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_authService.currentUser == null) {
      developer.log('No current user, showing sign in prompt', name: 'Friends');
      return _buildSignInPrompt();
    }

    developer.log(
      'Building friends list for user ${_authService.currentUser!.uid}',
      name: 'Friends',
    );

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          developer.log('Waiting for user document snapshot', name: 'Friends');
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          developer.log('Error loading friends: $error', name: 'Friends');
          return Center(child: Text('Error loading friends: ${error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          developer.log('User document does not exist', name: 'Friends');
          return _buildEmptyState(
            'No user data found',
            'Please try again later',
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        // Check if the friends field exists
        if (!userData.containsKey('friends')) {
          developer.log(
            'User document does not have a friends field',
            name: 'Friends',
          );

          // Initialize friends field if it doesn't exist
          FirebaseFirestore.instance
              .collection('users')
              .doc(_authService.currentUser!.uid)
              .set({'friends': []}, SetOptions(merge: true))
              .then(
                (_) => developer.log(
                  'Initialized empty friends list',
                  name: 'Friends',
                ),
              )
              .catchError(
                (e) => developer.log(
                  'Error initializing friends list: $e',
                  name: 'Friends',
                ),
              );

          return _buildEmptyState(
            'No friends yet',
            'Connect with others to add friends',
          );
        }

        // Get friends list
        final friendsList = userData['friends'];

        // Check if friends list is null or empty
        if (friendsList == null ||
            !(friendsList is List) ||
            friendsList.isEmpty) {
          developer.log(
            'Friends list is empty or not a list: ${friendsList.runtimeType}',
            name: 'Friends',
          );
          return _buildEmptyState(
            'No friends yet',
            'Connect with others to add friends',
          );
        }

        // Convert to List<String>
        final friends =
            friendsList.map<String>((item) => item.toString()).toList();
        developer.log(
          'Found ${friends.length} friends: ${friends.join(", ")}',
          name: 'Friends',
        );

        // Filter based on search
        final List<String> filteredFriends =
            _searchQuery.isEmpty
                ? friends
                : []; // Will populate via user profile lookups

        // Create a combined list with pinned friends first
        List<String> sortedFriends = [];

        // First add pinned friends
        for (final friendId in friends) {
          if (_pinnedFriends.contains(friendId)) {
            sortedFriends.add(friendId);
          }
        }

        // Then add non-pinned friends
        for (final friendId in friends) {
          if (!_pinnedFriends.contains(friendId)) {
            sortedFriends.add(friendId);
          }
        }

        if (_searchQuery.isEmpty) {
          // Show all friends in sorted order
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: sortedFriends.length,
            itemBuilder: (context, index) {
              final friendId = sortedFriends[index];
              final isPinned = _pinnedFriends.contains(friendId);

              return _buildFriendItem(friendId, isPinned);
            },
          );
        } else {
          // Show filtered results based on search
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait(
              friends.map((friendId) async {
                final userData = await _getUserProfileData(friendId);
                if (userData != null) {
                  // Add user ID to the data for reference
                  userData['userId'] = friendId;
                }
                return userData ?? {};
              }),
            ),
            builder: (context, userDataSnapshot) {
              if (!userDataSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              // Filter friends based on search query
              final filteredUserData =
                  userDataSnapshot.data!.where((userData) {
                    if (userData.isEmpty) return false;

                    final userName =
                        ((userData['name'] ?? '') as String).toLowerCase();
                    return userName.contains(_searchQuery);
                  }).toList();

              if (filteredUserData.isEmpty) {
                return _buildEmptyState(
                  'No matching friends',
                  'No friends match your search for "$_searchQuery"',
                );
              }

              // Sort with pinned friends first
              filteredUserData.sort((a, b) {
                final aIsPinned = _pinnedFriends.contains(a['userId']);
                final bIsPinned = _pinnedFriends.contains(b['userId']);

                if (aIsPinned && !bIsPinned) return -1;
                if (!aIsPinned && bIsPinned) return 1;
                return 0;
              });

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredUserData.length,
                itemBuilder: (context, index) {
                  final friendData = filteredUserData[index];
                  final friendId = friendData['userId'] as String;
                  final isPinned = _pinnedFriends.contains(friendId);

                  return _buildFriendItemWithData(
                    friendId,
                    friendData,
                    isPinned,
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  Widget _buildFriendItem(String friendId, bool isPinned) {
    developer.log(
      'Building friend item for ID: $friendId, isPinned: $isPinned',
      name: 'Friends',
    );

    return FutureBuilder<Map<String, dynamic>?>(
      future: _getUserProfileData(friendId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          developer.log(
            'Waiting for profile data for $friendId',
            name: 'Friends',
          );
          return Card(
            elevation: 1,
            margin: EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(blueColor),
                ),
              ),
              title: Container(
                height: 14,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          developer.log('No profile data found for $friendId', name: 'Friends');
          return SizedBox.shrink(); // Skip invalid users
        }

        final userData = snapshot.data!;
        final userName =
            userData['name'] ??
            userData['displayName'] ??
            (userData['email']?.toString().split('@').first) ??
            'User';
        final profileImageUrl =
            userData['profileImageUrl'] ?? userData['secureUrl'];

        developer.log(
          'Building friend item for $friendId with name: $userName',
          name: 'Friends',
        );
        return _buildFriendItemWithData(friendId, userData, isPinned);
      },
    );
  }

  Widget _buildFriendItemWithData(
    String friendId,
    Map<String, dynamic> userData,
    bool isPinned,
  ) {
    final userName =
        userData['name'] ??
        userData['displayName'] ??
        (userData['email']?.toString().split('@').first) ??
        'User';
    final profileImageUrl =
        userData['profileImageUrl'] ?? userData['secureUrl'];

    return Card(
      elevation: isPinned ? 2 : 1,
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          // Navigate to private chat when friend card is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PrivateChatScreen(
                    friendId: friendId,
                    friendName: userName,
                    friendProfileUrl: profileImageUrl,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient:
                isPinned
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.amber[50]!],
                    )
                    : null,
          ),
          child: ListTile(
            leading: Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isPinned ? Colors.amber : blueColor.withOpacity(0.3),
                      width: isPinned ? 2 : 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child:
                        profileImageUrl != null
                            ? Image.network(
                              profileImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  color: blueColor,
                                  size: 30,
                                );
                              },
                            )
                            : Icon(Icons.person, color: blueColor, size: 30),
                  ),
                ),
                if (isPinned)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              userName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            subtitle:
                userData['university'] != null
                    ? Text(
                      userData['university'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                    : null,
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[700]),
              onSelected: (value) {
                if (value == 'pin') {
                  _togglePinFriend(friendId, userName);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(friendId, userName);
                }
              },
              itemBuilder:
                  (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'pin',
                      child: ListTile(
                        leading: Icon(
                          isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                          color: isPinned ? Colors.grey : Colors.amber,
                        ),
                        title: Text(isPinned ? 'Unpin' : 'Pin'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Remove friend'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String friendId, String friendName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Remove Friend'),
            content: Text(
              'Are you sure you want to remove $friendName from your friends list?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCEL'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteFriend(friendId, friendName);
                },
                child: Text('REMOVE', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState(String title, String message) {
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
              child: Icon(Icons.people_outline, size: 50, color: blueColor),
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
            Icon(Icons.login, size: 80, color: Colors.grey[400]),
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
              'You need to be signed in to view your friends',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: Text('Sign In'),
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
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

  // Update the friend card builder to include chat navigation and unread indicators
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    final String friendId = friend['id'];
    final String friendName = friend['name'] ?? 'Unknown';
    final String? profileUrl = friend['profileUrl'];
    final bool isOnline = friend['isOnline'] ?? false;
    final bool isPinned = _pinnedFriends.contains(friendId);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PrivateChatScreen(
                    friendId: friendId,
                    friendName: friendName,
                    friendProfileUrl: profileUrl,
                  ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        profileUrl != null ? NetworkImage(profileUrl) : null,
                    child:
                        profileUrl == null
                            ? Icon(Icons.person, size: 30, color: Colors.grey)
                            : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friendName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? Colors.green : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned ? orangeColor : Colors.grey,
                    ),
                    onPressed: () => _togglePinFriend(friendId, friendName),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteFriend(friendId, friendName),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
