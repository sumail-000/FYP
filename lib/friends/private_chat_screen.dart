import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';
import '../services/presence_service.dart';
import 'package:intl/intl.dart';

class PrivateChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendProfileUrl;

  const PrivateChatScreen({
    Key? key,
    required this.friendId,
    required this.friendName,
    this.friendProfileUrl,
  }) : super(key: key);

  @override
  _PrivateChatScreenState createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  bool _isLoading = false;
  bool _isKeyboardVisible = false;

  // App colors
  final Color blueColor = const Color(0xFF2D6DA8);
  final Color orangeColor = const Color(0xFFf06517);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupKeyboardListeners();
    _markMessagesAsRead();
    _updatePresence(true);
    developer.log('PrivateChatScreen initialized', name: 'PrivateChat');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
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

  void _setupKeyboardListeners() {
    _focusNode.addListener(_onFocusChange);
    _messageController.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
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
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      // Get unread messages
      final unreadMessages =
          await FirebaseFirestore.instance
              .collection('privateChats')
              .doc(_getChatRoomId())
              .collection('messages')
              .where('recipientId', isEqualTo: currentUser.uid)
              .where('isRead', isEqualTo: false)
              .get();

      // Mark them as read
      for (var doc in unreadMessages.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      developer.log('Error marking messages as read: $e', name: 'PrivateChat');
    }
  }

  Future<void> _updatePresence(bool isOnline) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      await _presenceService.updatePresence(
        isOnline: isOnline,
        screen: 'privateChat',
        additionalData: widget.friendId,
      );
    } catch (e) {
      developer.log('Error updating presence: $e', name: 'PrivateChat');
    }
  }

  String _getChatRoomId() {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return '';

    // Create a unique chat room ID by sorting user IDs
    final List<String> ids = [currentUser.uid, widget.friendId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to send messages'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Get user data for sender name and profile picture
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();

      String senderName = 'Anonymous';
      String? profileUrl;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        senderName =
            userData['name'] ??
            currentUser.email?.split('@').first ??
            'Anonymous';
        profileUrl = userData['profileImageUrl'];

        if (profileUrl == null) {
          final profileDoc =
              await FirebaseFirestore.instance
                  .collection('profiles')
                  .doc(currentUser.uid)
                  .get();

          if (profileDoc.exists) {
            final profileData = profileDoc.data() as Map<String, dynamic>;
            profileUrl = profileData['secureUrl'];
          }
        }
      }

      // Create or get chat room
      final chatRoomId = _getChatRoomId();
      final chatRoomRef = FirebaseFirestore.instance
          .collection('privateChats')
          .doc(chatRoomId);

      // Add message
      await chatRoomRef.collection('messages').add({
        'senderId': currentUser.uid,
        'senderName': senderName,
        'senderProfileUrl': profileUrl,
        'recipientId': widget.friendId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Update chat room metadata
      await chatRoomRef.set({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'participants': [currentUser.uid, widget.friendId],
        'participantNames': {
          currentUser.uid: senderName,
          widget.friendId: widget.friendName,
        },
      }, SetOptions(merge: true));

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      developer.log('Error sending message: $e', name: 'PrivateChat');
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
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      return DateFormat.jm().format(timestamp);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat.jm().format(timestamp)}';
    } else {
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

    if (_isKeyboardVisible != isKeyboardOpen) {
      _isKeyboardVisible = isKeyboardOpen;
      if (isKeyboardOpen) {
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: blueColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child:
                  widget.friendProfileUrl != null
                      ? ClipOval(
                        child: Image.network(
                          widget.friendProfileUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                widget.friendName.isNotEmpty
                                    ? widget.friendName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                      : Center(
                        child: Text(
                          widget.friendName.isNotEmpty
                              ? widget.friendName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                // Friend online status
                StreamBuilder<DocumentSnapshot>(
                  stream: _presenceService.getUserPresenceStream(
                    widget.friendId,
                  ),
                  builder: (context, snapshot) {
                    bool isOnline = false;
                    if (snapshot.hasData && snapshot.data != null) {
                      try {
                        final data =
                            snapshot.data!.data() as Map<String, dynamic>?;
                        isOnline = data != null && data['isOnline'] == true;
                      } catch (e) {
                        developer.log(
                          'Error getting online status: $e',
                          name: 'PrivateChat',
                        );
                      }
                    }

                    return Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.greenAccent : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color:
                                isOnline ? Colors.greenAccent : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('privateChats')
                      .doc(_getChatRoomId())
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
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
                        SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        TextButton(
                          onPressed: () => setState(() {}),
                          child: Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isMe =
                        message['senderId'] == _authService.currentUser?.uid;
                    final timestamp =
                        (message['timestamp'] as Timestamp).toDate();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment:
                            isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: blueColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: blueColor.withOpacity(0.1),
                                  width: 2,
                                ),
                              ),
                              child:
                                  widget.friendProfileUrl != null
                                      ? ClipOval(
                                        child: Image.network(
                                          widget.friendProfileUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Center(
                                              child: Text(
                                                widget.friendName.isNotEmpty
                                                    ? widget.friendName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                      : Center(
                                        child: Text(
                                          widget.friendName.isNotEmpty
                                              ? widget.friendName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                            )
                          else
                            const SizedBox(width: 44),

                          if (isMe) const Spacer(),

                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? orangeColor.withOpacity(0.1)
                                      : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                              border: Border.all(
                                color:
                                    isMe
                                        ? orangeColor.withOpacity(0.2)
                                        : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['text'] ?? '',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      SizedBox(width: 4),
                                      Icon(
                                        message['isRead'] == true
                                            ? Icons.done_all
                                            : Icons.done,
                                        size: 14,
                                        color:
                                            message['isRead'] == true
                                                ? Colors.blue
                                                : Colors.grey[500],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (!isMe) const Spacer(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, -2),
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
                        SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            keyboardAppearance: Brightness.light,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Emoji picker coming soon!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: orangeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: orangeColor.withOpacity(0.4),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon:
                        _isSending
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(Icons.send, color: Colors.white),
                    onPressed: _isSending ? null : _sendMessage,
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
