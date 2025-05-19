import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/badge_model.dart' as models;

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  final CollectionReference _userBadgesCollection = 
      FirebaseFirestore.instance.collection('user_badges');
  final CollectionReference _badgesCollection = 
      FirebaseFirestore.instance.collection('badges');
  
  // Initialize badges collection with default values if it doesn't exist
  Future<void> initializeBadgesCollection() async {
    try {
      // Check if badges collection has any documents
      final snapshot = await _badgesCollection.limit(1).get();
      
      // If collection is empty, populate with default badges
      if (snapshot.docs.isEmpty) {
        final defaultBadges = models.Badge.getDefaultBadges();
        
        // Use batch write to add all badges
        final batch = _firestore.batch();
        for (var badge in defaultBadges) {
          batch.set(_badgesCollection.doc(badge.id), badge.toMap());
        }
        
        await batch.commit();
        print('Default badges added to collection');
      }
    } catch (e) {
      print('Error initializing badges collection: $e');
    }
  }
  
  // Get all available badges from Firestore
  Future<List<models.Badge>> getAllBadges() async {
    try {
      // Ensure badges collection is initialized
      await initializeBadgesCollection();
      
      final snapshot = await _badgesCollection.get();
      
      return snapshot.docs.map((doc) {
        return models.Badge.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('Error getting badges: $e');
      // Return default badges if Firestore fails
      return models.Badge.getDefaultBadges();
    }
  }
  
  // Get user badges with earned status
  Future<List<models.Badge>> getUserBadges(String userId) async {
    try {
      // Get all available badges
      final allBadges = await getAllBadges();
      
      // Get user's earned badges
      final userBadgesDoc = await _userBadgesCollection.doc(userId).get();
      
      if (!userBadgesDoc.exists) {
        // If user doesn't have a badges document yet, they should at least have newcomer
        await _awardNewcomerBadge(userId);
        return _applyEarnedStatus(allBadges, {'newcomer': Timestamp.now()});
      }
      
      // Extract earned badges data
      final userData = userBadgesDoc.data() as Map<String, dynamic>;
      final earnedBadges = userData['earnedBadges'] as Map<String, dynamic>? ?? {};
      
      // Apply earned status to the badges
      return _applyEarnedStatus(allBadges, earnedBadges);
    } catch (e) {
      print('Error getting user badges: $e');
      // Return default badges without earned status if there's an error
      return models.Badge.getDefaultBadges();
    }
  }
  
  // Apply earned status to badges based on user data
  List<models.Badge> _applyEarnedStatus(List<models.Badge> badges, Map<String, dynamic> earnedBadges) {
    return badges.map((badge) {
      if (earnedBadges.containsKey(badge.id)) {
        return badge.copyWith(earnedAt: earnedBadges[badge.id]);
      }
      return badge;
    }).toList();
  }
  
  // Award newcomer badge to new users
  Future<void> _awardNewcomerBadge(String userId) async {
    try {
      await _userBadgesCollection.doc(userId).set({
        'earnedBadges': {
          'newcomer': Timestamp.now(),
        },
        'lastUpdated': Timestamp.now(),
      });
    } catch (e) {
      print('Error awarding newcomer badge: $e');
    }
  }
  
  // Update user badges based on their activity points
  Future<List<models.Badge>> updateUserBadges(String userId, int activityPoints) async {
    try {
      // Get all available badges
      final allBadges = await getAllBadges();
      
      // Get user's current badges
      final userBadgesDoc = await _userBadgesCollection.doc(userId).get();
      Map<String, dynamic> earnedBadges = {};
      
      if (userBadgesDoc.exists) {
        final userData = userBadgesDoc.data() as Map<String, dynamic>;
        earnedBadges = userData['earnedBadges'] as Map<String, dynamic>? ?? {};
      } else {
        // Ensure user has newcomer badge
        earnedBadges = {'newcomer': Timestamp.now()};
      }
      
      // Check each badge for eligibility
      bool badgesUpdated = false;
      for (var badge in allBadges) {
        // If user has enough points for badge and hasn't earned it yet
        if (activityPoints >= badge.pointsRequired && 
            !earnedBadges.containsKey(badge.id)) {
          
          earnedBadges[badge.id] = Timestamp.now();
          badgesUpdated = true;
          
          print('User $userId earned badge: ${badge.name}');
        }
      }
      
      // Update user badges in Firestore if changes were made
      if (badgesUpdated) {
        await _userBadgesCollection.doc(userId).set({
          'earnedBadges': earnedBadges,
          'lastUpdated': Timestamp.now(),
        }, SetOptions(merge: true));
      }
      
      // Return updated badges with earned status
      return _applyEarnedStatus(allBadges, earnedBadges);
    } catch (e) {
      print('Error updating user badges: $e');
      return [];
    }
  }
  
  // Update current user's badges based on their activity points
  Future<List<models.Badge>> updateCurrentUserBadges(int activityPoints) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No authenticated user');
      return [];
    }
    
    return updateUserBadges(user.uid, activityPoints);
  }
  
  // Get the highest earned badge for a user
  Future<models.Badge?> getHighestEarnedBadge(String userId) async {
    try {
      final badges = await getUserBadges(userId);
      
      // Filter earned badges and sort by points required (highest first)
      final earnedBadges = badges
          .where((badge) => badge.isEarned)
          .toList()
        ..sort((a, b) => b.pointsRequired.compareTo(a.pointsRequired));
      
      if (earnedBadges.isNotEmpty) {
        return earnedBadges.first;
      }
      
      return null;
    } catch (e) {
      print('Error getting highest earned badge: $e');
      return null;
    }
  }
  
  // Get the next badge a user can earn
  Future<models.Badge?> getNextBadgeToEarn(String userId, int activityPoints) async {
    try {
      final badges = await getUserBadges(userId);
      
      // Find unearned badges that require more points than the user has
      final nextBadges = badges
          .where((badge) => !badge.isEarned && badge.pointsRequired > activityPoints)
          .toList()
        ..sort((a, b) => a.pointsRequired.compareTo(b.pointsRequired));
      
      if (nextBadges.isNotEmpty) {
        return nextBadges.first;
      }
      
      return null;
    } catch (e) {
      print('Error getting next badge to earn: $e');
      return null;
    }
  }
  
  // Validate and update badges - ensures badges match current activity points
  Future<List<models.Badge>> validateAndUpdateUserBadges(String userId, int activityPoints) async {
    try {
      // Get all available badges
      final allBadges = await getAllBadges();
      
      // Get user's current badges
      final userBadgesDoc = await _userBadgesCollection.doc(userId).get();
      Map<String, dynamic> earnedBadges = {};
      
      if (userBadgesDoc.exists) {
        final userData = userBadgesDoc.data() as Map<String, dynamic>;
        earnedBadges = userData['earnedBadges'] as Map<String, dynamic>? ?? {};
      } else {
        // Ensure user has newcomer badge
        earnedBadges = {'newcomer': Timestamp.now()};
      }
      
      // Map to track changes
      Map<String, dynamic> updatedEarnedBadges = Map.from(earnedBadges);
      bool badgesUpdated = false;
      
      // Check each badge against activity points
      for (var badge in allBadges) {
        final hasBadge = updatedEarnedBadges.containsKey(badge.id);
        final qualifiesForBadge = activityPoints >= badge.pointsRequired;
        
        // Always keep the newcomer badge once earned
        if (badge.id == 'newcomer' && !hasBadge) {
          updatedEarnedBadges['newcomer'] = Timestamp.now();
          badgesUpdated = true;
          print('User $userId was missing Newcomer badge - added');
        }
        // Remove badges user no longer qualifies for (except newcomer)
        else if (hasBadge && !qualifiesForBadge && badge.id != 'newcomer') {
          updatedEarnedBadges.remove(badge.id);
          badgesUpdated = true;
          print('User $userId lost badge: ${badge.name} (insufficient points)');
        }
        // Add badges user now qualifies for but doesn't have
        else if (!hasBadge && qualifiesForBadge) {
          updatedEarnedBadges[badge.id] = Timestamp.now();
          badgesUpdated = true;
          print('User $userId earned badge: ${badge.name}');
        }
      }
      
      // Update user badges in Firestore if changes were made
      if (badgesUpdated) {
        await _userBadgesCollection.doc(userId).set({
          'earnedBadges': updatedEarnedBadges,
          'lastUpdated': Timestamp.now(),
        }, SetOptions(merge: true));
        
        print('Updated badges for user $userId with activity points: $activityPoints');
      }
      
      // Return updated badges with earned status
      return _applyEarnedStatus(allBadges, updatedEarnedBadges);
    } catch (e) {
      print('Error validating user badges: $e');
      return [];
    }
  }
} 