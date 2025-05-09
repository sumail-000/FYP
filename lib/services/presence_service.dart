import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

class PresenceService {
  static final PresenceService _instance = PresenceService._internal();

  factory PresenceService() => _instance;

  PresenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Update user's online status
  Future<void> updatePresence({
    bool isOnline = true,
    String? screen,
    String? additionalData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Get user data for display
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      String userName = 'Anonymous';
      String? profileUrl;

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        userName =
            userData['name'] ?? user.email?.split('@').first ?? 'Anonymous';
        profileUrl = userData['profileImageUrl'];

        // If profile image not found in users collection, check profiles collection
        if (profileUrl == null) {
          final profileDoc =
              await _firestore.collection('profiles').doc(user.uid).get();

          if (profileDoc.exists) {
            final profileData = profileDoc.data() as Map<String, dynamic>;
            profileUrl = profileData['secureUrl'];
          }
        }
      }

      // Update presence record
      await _firestore.collection('presence').doc(user.uid).set({
        'userId': user.uid,
        'userName': userName,
        'profileUrl': profileUrl,
        'lastActive': FieldValue.serverTimestamp(),
        'isOnline': isOnline,
        'screen': screen,
        'additionalData': additionalData,
      }, SetOptions(merge: true));

      developer.log(
        'User presence updated for ${user.uid} (online: $isOnline, screen: $screen)',
        name: 'PresenceService',
      );
    } catch (e) {
      developer.log(
        'Error updating user presence: $e',
        name: 'PresenceService',
      );
    }
  }

  // Mark user as offline
  Future<void> markOffline() async {
    return updatePresence(isOnline: false, screen: null, additionalData: null);
  }

  // Get a stream of a specific user's presence
  Stream<DocumentSnapshot> getUserPresenceStream(String userId) {
    return _firestore.collection('presence').doc(userId).snapshots();
  }

  // Get current user's ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if a user is online
  Future<bool> isUserOnline(String userId) async {
    try {
      final doc = await _firestore.collection('presence').doc(userId).get();
      return doc.exists && doc.data()?['isOnline'] == true;
    } catch (e) {
      developer.log(
        'Error checking if user is online: $e',
        name: 'PresenceService',
      );
      return false;
    }
  }
}
