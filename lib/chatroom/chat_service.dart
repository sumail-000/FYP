import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import 'chat_message.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _chatRoomCollection = 'chatrooms';
  final String _messagesCollection = 'messages';
  final String _presenceCollection = 'presence';
  final String _generalChatRoomId = 'general';

  // Get messages stream for the general chat room
  Stream<List<ChatMessage>> getMessagesStream() {
    return _firestore
        .collection(_chatRoomCollection)
        .doc(_generalChatRoomId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: false)
        .limitToLast(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
        });
  }

  // Send a message to the general chat room
  Future<void> sendMessage({
    required String senderId,
    required String senderName,
    String? senderProfileUrl,
    required String text,
  }) async {
    try {
      // Check if the chat room document exists, create if not
      final chatRoomDoc = await _firestore
          .collection(_chatRoomCollection)
          .doc(_generalChatRoomId)
          .get();

      if (!chatRoomDoc.exists) {
        await _firestore.collection(_chatRoomCollection).doc(_generalChatRoomId).set({
          'name': 'General Chat',
          'description': 'Public chat room for all users',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Add the message to the chat room
      await _firestore
          .collection(_chatRoomCollection)
          .doc(_generalChatRoomId)
          .collection(_messagesCollection)
          .add({
        'senderId': senderId,
        'senderName': senderName,
        'senderProfileUrl': senderProfileUrl,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
      });

      developer.log('Message sent successfully', name: 'ChatService');
    } catch (e) {
      developer.log('Error sending message: $e', name: 'ChatService');
      throw e;
    }
  }

  // Update user presence status (online)
  Future<void> updateUserPresence() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user data for display
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      String userName = 'Anonymous';
      String? profileUrl;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userName = userData['name'] ?? user.email?.split('@').first ?? 'Anonymous';
        profileUrl = userData['profileImageUrl'];

        // If profile image not found in users collection, check profiles collection
        if (profileUrl == null) {
          final profileDoc = await _firestore
              .collection('profiles')
              .doc(user.uid)
              .get();

          if (profileDoc.exists) {
            final profileData = profileDoc.data() as Map<String, dynamic>;
            profileUrl = profileData['secureUrl'];
          }
        }
      }

      // Check if user was already in the chat room
      final presenceDoc = await _firestore.collection(_presenceCollection).doc(user.uid).get();
      final bool wasOnline = presenceDoc.exists && 
                             presenceDoc.data() != null && 
                             presenceDoc.data()!['isOnline'] == true &&
                             presenceDoc.data()!['inChatRoom'] == _generalChatRoomId;

      // Update presence record
      await _firestore.collection(_presenceCollection).doc(user.uid).set({
        'userId': user.uid,
        'userName': userName,
        'profileUrl': profileUrl,
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': true,
        'inChatRoom': _generalChatRoomId,
      }, SetOptions(merge: true));

      // Send a system message if user is newly joining
      if (!wasOnline) {
        await _sendSystemMessage('$userName joined the chat');
      }

      developer.log('User presence updated: ${user.uid}', name: 'ChatService');
    } catch (e) {
      developer.log('Error updating user presence: $e', name: 'ChatService');
    }
  }

  // Mark user as offline
  Future<void> markUserOffline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get the user's name before marking offline
      final presenceDoc = await _firestore.collection(_presenceCollection).doc(user.uid).get();
      if (presenceDoc.exists && presenceDoc.data() != null) {
        final data = presenceDoc.data()!;
        final userName = data['userName'] ?? 'Anonymous';
        final wasInChatRoom = data['inChatRoom'] == _generalChatRoomId;
        
        // Send a system message that user left
        if (wasInChatRoom) {
          await _sendSystemMessage('$userName left the chat');
        }
      }

      await _firestore.collection(_presenceCollection).doc(user.uid).update({
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': false,
        'inChatRoom': null,
      });

      developer.log('User marked offline: ${user.uid}', name: 'ChatService');
    } catch (e) {
      developer.log('Error marking user offline: $e', name: 'ChatService');
    }
  }

  // Send a system message
  Future<void> _sendSystemMessage(String text) async {
    try {
      await _firestore
          .collection(_chatRoomCollection)
          .doc(_generalChatRoomId)
          .collection(_messagesCollection)
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });
      
      developer.log('System message sent: $text', name: 'ChatService');
    } catch (e) {
      developer.log('Error sending system message: $e', name: 'ChatService');
    }
  }

  // Get stream of online users in the chatroom
  Stream<List<Map<String, dynamic>>> getOnlineUsersStream() {
    return _firestore
        .collection(_presenceCollection)
        .where('isOnline', isEqualTo: true)
        .where('inChatRoom', isEqualTo: _generalChatRoomId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'userId': doc.id,
              'userName': data['userName'] ?? 'Anonymous',
              'profileUrl': data['profileUrl'],
              'lastActive': data['lastActive'],
            };
          }).toList();
        });
  }

  // Get the number of online users
  Future<int> getOnlineUsersCount() async {
    try {
      final snapshot = await _firestore
          .collection(_presenceCollection)
          .where('isOnline', isEqualTo: true)
          .where('inChatRoom', isEqualTo: _generalChatRoomId)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      developer.log('Error getting online users count: $e', name: 'ChatService');
      return 0;
    }
  }
} 