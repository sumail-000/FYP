import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/activity_points_model.dart';
import 'badge_service.dart';
import 'dart:developer' as developer;

class ActivityPointsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BadgeService _badgeService = BadgeService();
  
  // Point values for different activities
  static const int PROFILE_COMPLETION_POINTS = 50;
  static const int UNIVERSITY_EMAIL_POINTS = 100;
  static const int FIRST_LOGIN_POINTS = 20;
  static const int RESOURCE_UPLOAD_POINTS = 3;
  static const int DAILY_LOGIN_POINTS = 1;
  static const int CONNECTION_POINTS = 5;
  
  // Create or get activity points document for a user
  Future<ActivityPointsModel> _getOrCreateActivityPoints(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('activity_points').doc(userId).get();
      
      if (doc.exists) {
        return ActivityPointsModel.fromDocument(doc);
      } else {
        // Create a new activity points document
        ActivityPointsModel initialModel = ActivityPointsModel.initial(userId);
        await _firestore.collection('activity_points').doc(userId).set(initialModel.toMap());
        return initialModel;
      }
    } catch (e) {
      throw 'Error retrieving activity points: $e';
    }
  }
  
  // Get activity points for current user
  Future<ActivityPointsModel?> getUserActivityPoints() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    // Get activity points and validate for existing users
    ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
    
    // For existing users, check and award any missing one-time points they qualify for
    await _validateExistingUserPoints(user, pointsModel);
    
    // Return refreshed model
    return await _getOrCreateActivityPoints(user.uid);
  }
  
  // Validate and award missing points for existing users
  Future<void> _validateExistingUserPoints(User user, ActivityPointsModel pointsModel) async {
    try {
      // Skip validation only if all one-time activities have been awarded
      bool hasCompletedAllActivities = 
          (pointsModel.oneTimeActivities[ActivityType.profileCompletion] ?? false) &&
          (pointsModel.oneTimeActivities[ActivityType.firstLogin] ?? false);
      
      // If user has completed all basic activities, we can skip validation
      if (hasCompletedAllActivities) return;
      
      bool pointsUpdated = false;
      
      // Get user data from Firestore
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      
      // Check for profile completion
      bool isProfileComplete = userData['isProfileComplete'] ?? false;
      if (isProfileComplete && !(pointsModel.oneTimeActivities[ActivityType.profileCompletion] ?? false)) {
        pointsModel = pointsModel.addOneTimeActivity(
          ActivityType.profileCompletion, 
          PROFILE_COMPLETION_POINTS
        );
        pointsUpdated = true;
      }
      
      // Check for university email
      String email = user.email?.toLowerCase() ?? '';
      bool isUniversityEmail = email.endsWith('edu.pk');
      if (isUniversityEmail && !(pointsModel.oneTimeActivities[ActivityType.universityEmail] ?? false)) {
        pointsModel = pointsModel.addOneTimeActivity(
          ActivityType.universityEmail, 
          UNIVERSITY_EMAIL_POINTS
        );
        pointsUpdated = true;
      }
      
      // Award first login points (all existing users qualify)
      if (!(pointsModel.oneTimeActivities[ActivityType.firstLogin] ?? false)) {
        pointsModel = pointsModel.addOneTimeActivity(
          ActivityType.firstLogin, 
          FIRST_LOGIN_POINTS
        );
        pointsUpdated = true;
      }
      
      // Update activity points if any changes were made
      if (pointsUpdated) {
        await _firestore.collection('activity_points').doc(user.uid).update(pointsModel.toMap());
        developer.log('Updated activity points for user ${user.uid}. New total: ${pointsModel.totalPoints}', name: 'ActivityPoints');
        
        // Update badges based on new total points
        await _badgeService.updateUserBadges(user.uid, pointsModel.totalPoints);
      }
    } catch (e) {
      developer.log('Error validating existing user points: $e', name: 'ActivityPoints');
      // Don't throw error to avoid disrupting the user experience
    }
  }
  
  // Award points for profile completion
  Future<void> awardProfileCompletionPoints() async {
    User? user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    
    try {
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
      
      // Award points if not already awarded
      ActivityPointsModel updatedModel = pointsModel.addOneTimeActivity(
        ActivityType.profileCompletion, 
        PROFILE_COMPLETION_POINTS
      );
      
      // Only update if points were actually added
      if (updatedModel.totalPoints > pointsModel.totalPoints) {
        await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
        
        // Update badges based on new total points
        await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
      }
    } catch (e) {
      throw 'Error awarding profile completion points: $e';
    }
  }
  
  // Award points for university email verification
  Future<void> checkAndAwardUniversityEmailPoints() async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) throw 'User not authenticated or no email';
    
    try {
      String email = user.email!.toLowerCase();
      
      // Check if email ends with edu.pk domain
      bool isUniversityEmail = email.endsWith('edu.pk');
      
      if (isUniversityEmail) {
        ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
        
        // Award points if not already awarded
        ActivityPointsModel updatedModel = pointsModel.addOneTimeActivity(
          ActivityType.universityEmail, 
          UNIVERSITY_EMAIL_POINTS
        );
        
        // Only update if points were actually added
        if (updatedModel.totalPoints > pointsModel.totalPoints) {
          await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
          
          // Update badges based on new total points
          await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
        }
      }
    } catch (e) {
      throw 'Error checking university email: $e';
    }
  }
  
  // Award points for first login/signup
  Future<void> awardFirstLoginPoints() async {
    User? user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    
    try {
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
      
      // Award points if not already awarded
      ActivityPointsModel updatedModel = pointsModel.addOneTimeActivity(
        ActivityType.firstLogin, 
        FIRST_LOGIN_POINTS
      );
      
      // Only update if points were actually added
      if (updatedModel.totalPoints > pointsModel.totalPoints) {
        await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
        
        // Update badges based on new total points
        await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
      }
    } catch (e) {
      throw 'Error awarding first login points: $e';
    }
  }
  
  // Award points for document uploads
  Future<void> awardResourceUploadPoints() async {
    User? user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    
    try {
      // Get current activity points for user
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
      
      // Award points using the addActivityPoints method for recurring activities
      ActivityPointsModel updatedModel = pointsModel.addActivityPoints(
        ActivityType.resourceUpload,
        RESOURCE_UPLOAD_POINTS
      );
      
      // Save updated points
      await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
      developer.log('Awarded ${RESOURCE_UPLOAD_POINTS} points for document upload. New total: ${updatedModel.totalPoints}', name: 'ActivityPoints');
      
      // Update badges based on new total points
      await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
    } catch (e) {
      developer.log('Error awarding document upload points: $e', name: 'ActivityPoints');
      // Don't throw error to avoid disrupting the user experience if points can't be awarded
    }
  }
  
  // Award points for making a new connection
  Future<void> awardConnectionPoints() async {
    User? user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    
    try {
      // Get current activity points for user
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
      
      // Award points using the addActivityPoints method for recurring activities
      ActivityPointsModel updatedModel = pointsModel.addActivityPoints(
        ActivityType.connections,
        CONNECTION_POINTS
      );
      
      // Save updated points
      await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
      developer.log('Awarded ${CONNECTION_POINTS} points for making a new connection. New total: ${updatedModel.totalPoints}', name: 'ActivityPoints');
      
      // Update badges based on new total points
      await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
    } catch (e) {
      developer.log('Error awarding connection points: $e', name: 'ActivityPoints');
      // Don't throw error to avoid disrupting the user experience if points can't be awarded
    }
  }
  
  // Check and award daily login streak points
  Future<Map<String, dynamic>> checkAndAwardDailyLoginStreak() async {
    User? user = _auth.currentUser;
    if (user == null) {
      return {
        'success': false,
        'message': 'User not authenticated',
        'streakIncreased': false,
        'currentStreak': 0
      };
    }
    
    try {
      // Get current activity points for user
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(user.uid);
      
      // Record current streak to check if it increases
      final previousStreak = pointsModel.currentStreak;
      
      // Track daily login and award points
      ActivityPointsModel updatedModel = pointsModel.trackDailyLogin(DAILY_LOGIN_POINTS);
      
      // Only update if points were actually added (meaning it wasn't already logged in today)
      if (updatedModel.totalPoints > pointsModel.totalPoints) {
        await _firestore.collection('activity_points').doc(user.uid).update(updatedModel.toMap());
        
        // Update badges based on new total points
        await _badgeService.updateUserBadges(user.uid, updatedModel.totalPoints);
        
        // Determine if streak increased
        final streakIncreased = updatedModel.currentStreak > previousStreak;
        
        // Log the streak
        developer.log(
          'Daily login recorded. Streak: ${updatedModel.currentStreak}, '
          'Points awarded: $DAILY_LOGIN_POINTS, '
          'Total Points: ${updatedModel.totalPoints}',
          name: 'ActivityPoints'
        );
        
        return {
          'success': true,
          'message': 'Daily login recorded',
          'streakIncreased': streakIncreased,
          'currentStreak': updatedModel.currentStreak,
          'pointsAwarded': DAILY_LOGIN_POINTS
        };
      } else {
        // No points awarded, already logged in today
        return {
          'success': true,
          'message': 'Already logged in today',
          'streakIncreased': false,
          'currentStreak': updatedModel.currentStreak,
          'pointsAwarded': 0
        };
      }
    } catch (e) {
      developer.log('Error tracking daily login: $e', name: 'ActivityPoints');
      return {
        'success': false,
        'message': 'Error tracking daily login: $e',
        'streakIncreased': false,
        'currentStreak': 0
      };
    }
  }
  
  // Force update points for the current user - helpful during development
  Future<ActivityPointsModel?> forceUpdateCurrentUserPoints() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      developer.log("Starting force update for user ${user.uid}", name: 'ActivityPoints');
      
      // Get user document to check completion status
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        developer.log("User document doesn't exist", name: 'ActivityPoints');
        return null;
      }
      
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      bool isProfileComplete = userData['isProfileComplete'] ?? false;
      
      // Get current activity points document
      DocumentSnapshot pointsDoc = await _firestore.collection('activity_points').doc(user.uid).get();
      
      // Create a base points model
      ActivityPointsModel pointsModel;
      
      // If points document exists, delete it to start fresh
      if (pointsDoc.exists) {
        developer.log("Deleting existing points document", name: 'ActivityPoints');
        await _firestore.collection('activity_points').doc(user.uid).delete();
      }
      
      // Create a fresh activity points document
      pointsModel = ActivityPointsModel.initial(user.uid);
      await _firestore.collection('activity_points').doc(user.uid).set(pointsModel.toMap());
      
      developer.log("Created fresh activity points document", name: 'ActivityPoints');
      
      // Now grant appropriate points
      // 1. First login points - always grant for existing users
      pointsModel = pointsModel.addOneTimeActivity(
        ActivityType.firstLogin,
        FIRST_LOGIN_POINTS
      );
      
      // 2. Profile completion if applicable
      if (isProfileComplete) {
        pointsModel = pointsModel.addOneTimeActivity(
          ActivityType.profileCompletion,
          PROFILE_COMPLETION_POINTS
        );
      }
      
      // 3. University email if applicable
      String email = user.email?.toLowerCase() ?? '';
      if (email.endsWith('edu.pk')) {
        pointsModel = pointsModel.addOneTimeActivity(
          ActivityType.universityEmail,
          UNIVERSITY_EMAIL_POINTS
        );
      }
      
      // Update the document
      await _firestore.collection('activity_points').doc(user.uid).update(pointsModel.toMap());
      
      // Update badges based on new total points
      await _badgeService.updateUserBadges(user.uid, pointsModel.totalPoints);
      
      developer.log("Successfully updated points. New total: ${pointsModel.totalPoints}", name: 'ActivityPoints');
      return pointsModel;
      
    } catch (e) {
      developer.log("Error in force update: $e", name: 'ActivityPoints');
      return null;
    }
  }
  
  // Generic method to award points for any activity
  Future<void> awardPoints(String userId, int points, String activityDescription) async {
    if (points <= 0) return;
    
    try {
      // Get current activity points for user
      ActivityPointsModel pointsModel = await _getOrCreateActivityPoints(userId);
      
      // Create a generic activity type for custom activities
      final activityType = ActivityType.custom;
      
      // Award points using the addActivityPoints method for recurring activities
      ActivityPointsModel updatedModel = pointsModel.addActivityPoints(
        activityType,
        points
      );
      
      // Save updated points
      await _firestore.collection('activity_points').doc(userId).update(updatedModel.toMap());
      developer.log('Awarded $points points for $activityDescription. New total: ${updatedModel.totalPoints}', name: 'ActivityPoints');
      
      // Update badges based on new total points
      await _badgeService.updateUserBadges(userId, updatedModel.totalPoints);
    } catch (e) {
      developer.log('Error awarding points for $activityDescription: $e', name: 'ActivityPoints');
      // Don't throw error to avoid disrupting the user experience if points can't be awarded
    }
  }
}