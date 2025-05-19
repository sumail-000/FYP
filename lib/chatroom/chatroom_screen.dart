import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';
import 'chat_service.dart';
import 'chat_message.dart';
import 'package:intl/intl.dart';
import '../profiles/user_profile_view_screen.dart';
import '../services/presence_service.dart';

// ProfileImage widget for consistent profile image handling
class ProfileImage extends StatelessWidget {
  final String? imageUrl;
  final String fallbackText;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  
  const ProfileImage({
    required this.imageUrl,
    required this.fallbackText,
    this.size = 48.0,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final Color blueColor = const Color(0xFF2D6DA8);
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            spreadRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size / 3,
                      height: size / 3,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey[400],
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Text(
                      fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: size / 2.5,
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Text(
                  fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: size / 2.5,
                  ),
                ),
              ),
      ),
    );
  }
}

// StreamingProfileImage that listens to Firestore for real-time updates
class StreamingProfileImage extends StatelessWidget {
  final String userId;
  final String fallbackName;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  
  const StreamingProfileImage({
    required this.userId,
    required this.fallbackName,
    this.size = 48.0,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0.0,
    Key? key,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        String? profileUrl;
        String name = fallbackName;
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          profileUrl = userData?['profileImageUrl'];
          name = userData?['name'] ?? fallbackName;
          
          // If profile not found in users collection, check profiles collection
          if (profileUrl == null || profileUrl.isEmpty) {
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('profiles').doc(userId).snapshots(),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.hasData && profileSnapshot.data != null && profileSnapshot.data!.exists) {
                  final profileData = profileSnapshot.data!.data() as Map<String, dynamic>?;
                  profileUrl = profileData?['secureUrl'];
                }
                
                return ProfileImage(
                  imageUrl: profileUrl,
                  fallbackText: name,
                  size: size,
                  backgroundColor: backgroundColor,
                  borderColor: borderColor,
                  borderWidth: borderWidth,
                );
              },
            );
          }
        }
        
        return ProfileImage(
          imageUrl: profileUrl,
          fallbackText: name,
          size: size,
          backgroundColor: backgroundColor,
          borderColor: borderColor,
          borderWidth: borderWidth,
        );
      },
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({Key? key}) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();
  final PresenceService _presenceService = PresenceService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  int _onlineUsersCount = 0;
  bool _isLoading = false;
  bool _isSending = false;
  List<Map<String, dynamic>> _onlineUsers = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isKeyboardVisible = false;

  // App colors
  final Color blueColor = const Color(0xFF2D6DA8);
  final Color orangeColor = const Color(0xFFf06517);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOnlineUsersCount();
    _updateUserPresence();
    _setupKeyboardListeners();
    
    // Add a post-frame callback to immediately jump to bottom without animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    
    developer.log('ChatRoomScreen initialized', name: 'ChatRoom');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _markUserOffline();
    super.dispose();
  }

  void _setupKeyboardListeners() {
    _focusNode.addListener(_onFocusChange);
    _messageController.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Slight delay to ensure the keyboard is fully visible
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    }
  }

  void _onTextChange() {
    if (_messageController.text.isNotEmpty && _isKeyboardVisible) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        _scrollController.position.maxScrollExtent,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserPresence();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.detached) {
      _markUserOffline();
    }
  }

  Future<void> _updateUserPresence() async {
    try {
      await _chatService.updateUserPresence();
    } catch (e) {
      developer.log('Error updating user presence: $e', name: 'ChatRoom');
    }
  }

  Future<void> _markUserOffline() async {
    try {
      await _chatService.markUserOffline();
    } catch (e) {
      developer.log('Error marking user offline: $e', name: 'ChatRoom');
    }
  }

  Future<void> _loadOnlineUsersCount() async {
    try {
      final count = await _chatService.getOnlineUsersCount();
      setState(() {
        _onlineUsersCount = count;
      });
    } catch (e) {
      developer.log('Error loading online users count: $e', name: 'ChatRoom');
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be logged in to send messages')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Get user data for sender name and profile picture
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String senderName = 'Anonymous';
      String? profileUrl;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        senderName = userData['name'] ?? currentUser.email?.split('@').first ?? 'Anonymous';
        profileUrl = userData['profileImageUrl'];

        // If profile image not found in users collection, check profiles collection
        if (profileUrl == null) {
          final profileDoc = await FirebaseFirestore.instance
              .collection('profiles')
              .doc(currentUser.uid)
              .get();

          if (profileDoc.exists) {
            final profileData = profileDoc.data() as Map<String, dynamic>;
            profileUrl = profileData['secureUrl'];
          }
        }
      }

      await _chatService.sendMessage(
        senderId: currentUser.uid,
        senderName: senderName,
        senderProfileUrl: profileUrl,
        text: text,
      );

      _messageController.clear();
      // Scroll to bottom after sending message
      _scrollToBottom();
    } catch (e) {
      developer.log('Error sending message: $e', name: 'ChatRoom');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      // Today, show only time
      return DateFormat.jm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday, ${DateFormat.jm().format(timestamp)}';
    } else {
      // Other days
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final width = screenSize.width;
    final height = screenSize.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;
    
    // Update keyboard visibility state
    if (_isKeyboardVisible != isKeyboardOpen) {
      _isKeyboardVisible = isKeyboardOpen;
      if (isKeyboardOpen) {
        // Slight delay to ensure the keyboard is fully visible
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    }

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside of text field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey[100],
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: blueColor,
          elevation: 0,
          title: const Text(
            'Live ChatRoom',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // Online users indicator - now clickable to show drawer
            InkWell(
              onTap: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getOnlineUsersStream(),
                  builder: (context, snapshot) {
                    int count = 0;
                    if (snapshot.hasData) {
                      count = snapshot.data!.length;
                    }
                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$count Online',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        // End drawer to show online users
        endDrawer: _buildOnlineUsersDrawer(),
      body: SafeArea(
        child: Column(
          children: [
              // Header banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: isKeyboardOpen ? 6 : 12
                ),
              decoration: BoxDecoration(
                color: blueColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isKeyboardOpen 
                  ? null // Hide content when keyboard is open to save space
                  : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.shield,
                          color: orangeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                            Text(
                              'Community Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                                fontSize: 14,
                    ),
                  ),
                            const SizedBox(height: 2),
                  Text(
                              'Ask questions and connect with peers',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),

            // Chat messages
            Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatService.getMessagesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading messages',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      );
                    }

                    final messages = snapshot.data ?? [];
                    
                    // Remove the reverse operation since we want newest at bottom
                    final displayMessages = messages.toList();

                    if (displayMessages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to start the conversation!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Add a post-frame callback to scroll to bottom once the messages are loaded
                    // This ensures we scroll to the bottom when new data comes in
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom();
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: false, // Keep false to show newest at bottom
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, index) {
                        final message = displayMessages[index];
                        final isMe = message.senderId == _authService.currentUser?.uid;
                        final showSenderInfo = index == 0 || 
                            displayMessages[index - 1].senderId != message.senderId;

                        // Show date separator if needed
                        bool showDateSeparator = false;
                        String dateText = '';
                        
                        if (index == 0) {
                          showDateSeparator = true;
                          dateText = _getDateText(message.timestamp);
                        } else {
                          final prevMessage = displayMessages[index - 1];
                          final prevDate = DateTime(
                            prevMessage.timestamp.year,
                            prevMessage.timestamp.month,
                            prevMessage.timestamp.day,
                          );
                          final currentDate = DateTime(
                            message.timestamp.year,
                            message.timestamp.month,
                            message.timestamp.day,
                          );
                          
                          if (prevDate != currentDate) {
                            showDateSeparator = true;
                            dateText = _getDateText(message.timestamp);
                          }
                        }

                        return Column(
                children: [
                            if (showDateSeparator)
                              _buildDateSeparator(dateText),
                            _buildMessageItem(message, isMe, showSenderInfo),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

            // Input field
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                      offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                      decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                keyboardAppearance: Brightness.light,
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                              onPressed: () {
                                // Emoji picker would be implemented here
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Emoji picker coming soon!')),
                                );
                              },
                            ),
                          ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                        color: orangeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: orangeColor.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: _isSending
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSending ? null : _sendMessage,
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
  }

  Widget _buildOnlineUsersDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            color: blueColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Online Members',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatService.getOnlineUsersStream(),
                  builder: (context, snapshot) {
                    int count = 0;
                    if (snapshot.hasData) {
                      count = snapshot.data!.length;
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$count ${count == 1 ? 'person' : 'people'} online now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _chatService.getOnlineUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading online users'),
                    );
                  }

                  final onlineUsers = snapshot.data ?? [];

                  if (onlineUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No one else is online',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: onlineUsers.length,
                    itemBuilder: (context, index) {
                      final user = onlineUsers[index];
                      final isCurrentUser = user['userId'] == _authService.currentUser?.uid;
                      
                      return Card(
                        elevation: 1,
                        color: isCurrentUser ? orangeColor.withOpacity(0.1) : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrentUser ? orangeColor.withOpacity(0.3) : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: StreamingProfileImage(
                            userId: user['userId'],
                            fallbackName: user['userName'],
                            size: 48,
                            backgroundColor: blueColor.withOpacity(0.1),
                            borderColor: Colors.green,
                            borderWidth: 2,
                          ),
                          title: Text(
                            user['userName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrentUser ? orangeColor : Colors.black87,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                isCurrentUser ? 'You (Online)' : 'Online',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: isCurrentUser
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: orangeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: orangeColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      color: orangeColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Chat with your peers and get help with your studies',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: blueColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDateText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildDateSeparator(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300], thickness: 1),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300], thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message, bool isMe, bool showSenderInfo) {
    // Handle system messages differently
    if (message.isSystemMessage) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Divider(color: Colors.grey[300], thickness: 1),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: blueColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Divider(color: Colors.grey[300], thickness: 1),
            ),
          ],
      ),
    );
  }

    // Regular user message
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe && showSenderInfo)
            GestureDetector(
              onTap: () {
                // Show profile options when tapping on profile picture
                _showProfileOptions(message.senderId, message.senderName);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: StreamingProfileImage(
                  userId: message.senderId,
                  fallbackName: message.senderName,
                  size: 36,
                  backgroundColor: blueColor.withOpacity(0.2),
                  borderColor: blueColor.withOpacity(0.1),
                  borderWidth: 2,
                ),
              ),
            )
          else if (!isMe && !showSenderInfo)
            const SizedBox(width: 44),
          
          if (isMe) const Spacer(),
          
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && showSenderInfo)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
                  color: isMe 
                      ? orangeColor.withOpacity(0.1)
                      : Colors.white,
          borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isMe 
                        ? orangeColor.withOpacity(0.2)
                        : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 15,
          ),
        ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (!isMe) const Spacer(),
        ],
      ),
    );
  }

  // Method to show profile options when tapping on user avatar
  void _showProfileOptions(String userId, String userName) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      elevation: 10,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(top: 20, bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button and header row
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "User Profile",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: blueColor,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Profile header with improved UI
                    Container(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    // Profile image with loading from Firebase
                    StreamingProfileImage(
                      userId: userId,
                      fallbackName: userName,
                      size: 64,
                      backgroundColor: blueColor.withOpacity(0.1),
                      borderColor: blueColor.withOpacity(0.3),
                      borderWidth: 2,
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          StreamBuilder<DocumentSnapshot>(
                            stream: _presenceService.getUserPresenceStream(userId),
                            builder: (context, snapshot) {
                              // Loading state
                              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      SizedBox(width: 5),
                          Text(
                                        'Checking status...',
                            style: TextStyle(
                              color: Colors.grey[600],
                                          fontSize: 12,
                            ),
                          ),
                        ],
                                  ),
                                );
                              }
                              
                              bool isOnline = false;
                              String lastSeenText = '';
                              
                              if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                                final data = snapshot.data!.data() as Map<String, dynamic>?;
                                isOnline = data?['isOnline'] == true;
                                
                                // If user is offline, show last active time
                                if (!isOnline && data?['lastActive'] != null) {
                                  final lastActive = (data!['lastActive'] as Timestamp).toDate();
                                  lastSeenText = 'Last seen ${_formatTimestamp(lastActive)}';
                                }
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOnline 
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isOnline
                                            ? Colors.green.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 5),
                                          decoration: BoxDecoration(
                                            color: isOnline ? Colors.green : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Text(
                                          isOnline ? 'Online' : 'Offline',
                                          style: TextStyle(
                                            color: isOnline ? Colors.green[700] : Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
                                  if (!isOnline && lastSeenText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 2),
                                      child: Text(
                                        lastSeenText,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              Divider(height: 1, thickness: 1, color: Colors.grey[200]),
              SizedBox(height: 8),
              
              // Connect button (renamed from Send Friend Request)
              FutureBuilder<Map<String, bool>>(
                future: _checkFriendStatus(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: blueColor,
                          ),
                        ),
                      ),
                      title: Text(
                        'Checking connection status...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  
                  bool isFriend = false;
                  bool hasPendingRequest = false;
                  
                  if (snapshot.hasData && snapshot.data != null) {
                    isFriend = snapshot.data!['isFriend'] == true;
                    hasPendingRequest = snapshot.data!['hasPendingRequest'] == true;
                  }
                  
                  if (isFriend) {
                    return ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people, color: Colors.green[700]),
                      ),
                      title: Text(
                        'Connected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.green[700],
                        ),
                      ),
                      subtitle: Text(
                        'You are already connected with this user',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    );
                  } else if (hasPendingRequest) {
                    return ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people_alt_outlined, color: Colors.orange[700]),
                      ),
                      title: Text(
                        'Request Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.orange[700],
                        ),
                      ),
                      subtitle: Text(
                        'You have already sent a connection request',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    );
                  } else {
                    return ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people_outline, color: blueColor),
                      ),
                      title: Text(
                        'Connect',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Send a connection request to this user',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                onTap: () async {
                  Navigator.pop(context);
                  await _sendFriendRequest(userId, userName);
                      },
                    );
                  }
                },
              ),
              
              // View profile button with enhanced styling
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: orangeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline, color: orangeColor),
                ),
                title: Text(
                  'View Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'See full profile details and activity',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileViewScreen(
                        userId: userId,
                        initialUserName: userName,
                      ),
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

  // Add this method to send friend request
  Future<void> _sendFriendRequest(String recipientId, String recipientName) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You need to be logged in to send requests')),
        );
        return;
      }
      
      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
          
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUserName = currentUserData['name'] ?? currentUser.displayName ?? 'User';
      
      // Check if request already exists
      final existingRequestQuery = await FirebaseFirestore.instance
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
        'message': 'I would like to connect with you.',
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to $recipientName')),
      );
    } catch (e) {
      developer.log('Error sending friend request: $e', name: 'ChatRoom');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request')),
      );
    }
  }

  Future<Map<String, bool>> _checkFriendStatus(String userId) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        return {'isFriend': false, 'hasPendingRequest': false};
      }
      
      // Check if already friends
      final friendQuerySnapshot = await _firestore
          .collection('friends')
          .where('userId', isEqualTo: currentUser.uid)
          .where('friendId', isEqualTo: userId)
          .limit(1)
          .get();
          
      bool isFriend = friendQuerySnapshot.docs.isNotEmpty;
      
      // Check pending request
      final requestQuerySnapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('recipientId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
          
      bool hasPendingRequest = requestQuerySnapshot.docs.isNotEmpty;
      
      return {
        'isFriend': isFriend,
        'hasPendingRequest': hasPendingRequest,
      };
    } catch (e) {
      developer.log('Error checking friend status: $e', name: 'ChatRoom');
      return {'isFriend': false, 'hasPendingRequest': false};
    }
  }
} 