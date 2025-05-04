import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Wrong password provided.';
      } else {
        throw e.message ?? 'An unknown error occurred.';
      }
    } catch (e) {
      throw 'An error occurred: $e';
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
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If sign in was aborted
      if (googleUser == null) {
        throw 'Google sign in was aborted';
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create user document in Firestore
      await _createUserDocumentIfNotExists(userCredential.user);
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'An error occurred during Google sign in.';
    } catch (e) {
      throw 'An error occurred: $e';
    }
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