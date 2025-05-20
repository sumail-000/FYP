import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';
import '../services/activity_points_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityPointsService _activityPointsService = ActivityPointsService();
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Profile status check
  Future<bool> isProfileComplete() async {
    User? user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return data['university'] != null && 
             data['role'] != null && 
             data['isProfileComplete'] == true;
    } catch (e) {
      return false;
    }
  }
  
  // Get user data
  Future<UserModel?> getUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName,
        );
      }
      
      return UserModel.fromDocument(doc);
    } catch (e) {
      return null;
    }
  }
  
  // Save profile data
  Future<void> completeProfile({required UserRole role, required String university}) async {
    User? user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';
    
    // Get the current user data to ensure we don't overwrite existing name
    DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
    Map<String, dynamic> existingData = {};
    
    if (doc.exists) {
      existingData = doc.data() as Map<String, dynamic>;
    }
    
    // Use existing name if available, otherwise use displayName from Auth
    String? userName = existingData['name'] ?? user.displayName;
    
    // Validate the username
    bool hasValidUsername = false;
    if (userName != null && userName.trim().length >= 3 && !RegExp(r'^[0-9]+$').hasMatch(userName.trim())) {
      hasValidUsername = true;
    }
    
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'name': hasValidUsername ? userName : null, // Only save valid usernames
      'university': university,
      'role': role.toString().split('.').last,
      'isProfileComplete': hasValidUsername, // Only mark as complete if username is valid
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // If profile is complete, award activity points
    if (hasValidUsername) {
      try {
        // Award points for profile completion
        await _activityPointsService.awardProfileCompletionPoints();
        
        // Check if user has a university email and award points if applicable
        await _activityPointsService.checkAndAwardUniversityEmailPoints();
      } catch (e) {
        print('Error awarding activity points: $e');
        // Don't throw the error to avoid disrupting the user flow
      }
    }
    
    // If username is invalid, throw an exception to trigger the username input screen
    if (!hasValidUsername) {
      throw 'Valid username required';
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check if user document exists, if not create one
      await _createUserDocumentIfNotExists(userCredential.user);
      
      // Ensure user gets activity points for existing account
      try {
        await _validateActivityPoints(userCredential.user);
      } catch (e) {
        print('Error validating activity points during login: $e');
        // Don't throw to avoid disrupting login flow
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Provide clear, user-friendly error messages
      switch (e.code) {
        case 'user-not-found':
          throw 'No account found with this email.';
        case 'wrong-password':
          throw 'Incorrect email or password.';
        case 'invalid-credential':
          throw 'Invalid login credentials.';
        case 'user-disabled':
          throw 'This account has been disabled.';
        case 'too-many-requests':
          throw 'Too many unsuccessful login attempts. Please try again later.';
        case 'invalid-email':
          throw 'Please enter a valid email address.';
        case 'network-request-failed':
          throw 'Network error. Please check your internet connection.';
        default:
          throw e.message ?? 'An error occurred during login.';
      }
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }

  // Helper method to validate activity points
  Future<void> _validateActivityPoints(User? user) async {
    if (user == null) return;
    
    // Get profile completion status
    bool profileCompleted = await isProfileComplete();
    
    // Force update points for users who completed their profile
    if (profileCompleted) {
      // First check user document
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      // Check if user has activity points document
      DocumentSnapshot pointsDoc = await _firestore.collection('activity_points').doc(user.uid).get();
      
      // Get current activity points or create
      if (!pointsDoc.exists) {
        print("Creating activity points for existing user: ${user.uid}");
        // Award login points
        await _activityPointsService.awardFirstLoginPoints();
        
        // Award profile completion 
        await _activityPointsService.awardProfileCompletionPoints();
        
        // Check for university email
        await _activityPointsService.checkAndAwardUniversityEmailPoints();
      } else {
        Map<String, dynamic> pointsData = pointsDoc.data() as Map<String, dynamic>;
        
        // Check if all one-time activities are complete
        Map<String, dynamic>? oneTimeActivities = pointsData['oneTimeActivities'] as Map<String, dynamic>?;
        
        if (oneTimeActivities == null || oneTimeActivities.isEmpty) {
          // Missing activities map, award points
          print("Fixing missing oneTimeActivities for user: ${user.uid}");
          await _activityPointsService.awardFirstLoginPoints();
          await _activityPointsService.awardProfileCompletionPoints();
          await _activityPointsService.checkAndAwardUniversityEmailPoints();
        } else {
          // Check individual activities
          if (oneTimeActivities['first_login'] != true) {
            print("Awarding missing first login points");
            await _activityPointsService.awardFirstLoginPoints();
          }
          
          if (oneTimeActivities['profile_completion'] != true) {
            print("Awarding missing profile completion points");
            await _activityPointsService.awardProfileCompletionPoints();
          }
          
          // Only check university email if not already awarded
          if (oneTimeActivities['university_email_verification'] != true) {
            await _activityPointsService.checkAndAwardUniversityEmailPoints();
          }
        }
      }
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailPassword(String email, String password, {String? username}) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore with the username if provided
      await _createUserDocumentIfNotExists(userCredential.user, username: username);
      
      // Award points for first signup
      try {
        await _activityPointsService.awardFirstLoginPoints();
        
        // Check if user has a university email and award points if applicable
        await _activityPointsService.checkAndAwardUniversityEmailPoints();
      } catch (e) {
        print('Error awarding activity points: $e');
        // Don't throw the error to avoid disrupting the user flow
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        throw 'The account already exists for that email.';
      } else {
        throw e.message ?? 'An unknown error occurred.';
      }
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }
  
  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    int maxRetries = 2; // Maximum number of retries
    int currentRetry = 0;
    int baseTimeout = 15000; // Base timeout in milliseconds (15 seconds)
    
    while (currentRetry <= maxRetries) {
      try {
        // Calculate increasing timeout for each retry
        int currentTimeout = baseTimeout + (currentRetry * 5000); // Add 5 seconds per retry
        
        // Trigger the authentication flow with timeout
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
            .timeout(Duration(milliseconds: currentTimeout), onTimeout: () {
          // On timeout, throw a specific error that we can catch
          throw 'timeout_error';
        });
        
        // If sign in was aborted by user
        if (googleUser == null) {
          throw 'Google sign in was aborted';
        }

        // Obtain the auth details from the request with timeout
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication
            .timeout(Duration(milliseconds: currentTimeout), onTimeout: () {
          throw 'timeout_error';
        });

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credential
        final userCredential = await _auth.signInWithCredential(credential)
            .timeout(Duration(milliseconds: currentTimeout), onTimeout: () {
          throw 'timeout_error';
        });
        
        // Create user document in Firestore
        await _createUserDocumentIfNotExists(userCredential.user);
        
        // Check if this is a new user (first time sign in)
        bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        
        if (isNewUser) {
          // Award points for first signup if this is a new user
          try {
            await _activityPointsService.awardFirstLoginPoints();
            
            // Check if user has a university email and award points if applicable
            await _activityPointsService.checkAndAwardUniversityEmailPoints();
          } catch (e) {
            print('Error awarding activity points: $e');
            // Don't throw the error to avoid disrupting the user flow
          }
        } else {
          // Existing user - ensure they have activity points
          try {
            await _validateActivityPoints(userCredential.user);
          } catch (e) {
            print('Error validating activity points during Google sign in: $e');
          }
        }
        
        return userCredential;
      } on FirebaseAuthException catch (e) {
        throw e.message ?? 'An error occurred during Google sign in.';
      } catch (e) {
        // Check if it's a timeout error or network error
        if (e.toString() == 'timeout_error' || 
            e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('timeout')) {
          
          currentRetry++;
          
          // If we've reached max retries, throw the error
          if (currentRetry > maxRetries) {
            throw 'Connection timed out. Please check your internet connection and try again.';
          }
          
          // Otherwise, we'll retry with a longer timeout
          print('Google sign-in attempt $currentRetry of $maxRetries failed. Retrying...');
          
          // Add a small delay before retrying to allow network recovery
          await Future.delayed(Duration(milliseconds: 1000));
          continue;
        }
        
        // For cancelled/aborted sign-in, throw immediately without retry
        if (e.toString().toLowerCase().contains('aborted') || 
            e.toString().toLowerCase().contains('cancel')) {
          throw 'Google sign in was canceled.';
        }
        
        // For other errors, throw the error message
        throw 'An error occurred: $e';
      }
    }
    
    // This should never be reached due to the max retries check above
    throw 'Failed to sign in with Google after multiple attempts.';
  }

  // Create user document if it doesn't exist
  Future<void> _createUserDocumentIfNotExists(User? user, {String? username}) async {
    if (user == null) return;
    
    // Validate username if provided
    String? validatedUsername;
    if (username != null) {
      // Username should be at least 3 characters and not only numbers
      if (username.trim().length >= 3 && !RegExp(r'^[0-9]+$').hasMatch(username.trim())) {
        validatedUsername = username.trim();
      }
    }
    
    // If Google display name is available, use it as a fallback
    String? displayName = user.displayName;
    if (displayName != null && displayName.trim().length >= 3 && !RegExp(r'^[0-9]+$').hasMatch(displayName.trim())) {
      displayName = displayName.trim();
    } else if (validatedUsername == null) {
      displayName = null; // Will be handled by profile completion
    }
    
    // Check if user document already exists
    DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
    
    if (!doc.exists) {
      // Create new user document with basic info
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'name': validatedUsername ?? displayName, // Use provided username for email signup
        'isProfileComplete': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Sign out from Google if signed in with Google
    await _googleSignIn.signOut();
    // Sign out from Firebase
    await _auth.signOut();
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An unknown error occurred.';
    }
  }
} 