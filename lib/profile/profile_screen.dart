import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../upload/cloudinary_service.dart';
import 'dart:developer' as developer;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  bool _isUpdating = false;
  String _userName = '';
  String _userEmail = '';
  String _userUniversity = '';
  String _userRole = '';
  String? _profileImageUrl;
  
  // Controllers for edit profile
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  File? _imageFile;
  bool _isDarkTheme = false;
  bool _notificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Get user data from Firestore
        final userData = await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists) {
          final data = userData.data() as Map<String, dynamic>;
          
          // Get profile image data from profiles collection
          final profileData = await _firestore.collection('profiles').doc(user.uid).get();
          
          setState(() {
            _userName = data['name'] ?? user.displayName ?? user.email?.split('@')[0] ?? 'User';
            _userEmail = user.email ?? 'No email';
            _userUniversity = data['university'] ?? 'Not specified';
            _userRole = data['role'] ?? 'Student';
            
            // First try to get profile image from profiles collection
            if (profileData.exists) {
              final profileMap = profileData.data() as Map<String, dynamic>;
              _profileImageUrl = profileMap['secureUrl'] as String?;
              developer.log('Loaded profile image from profiles collection', name: 'ProfileScreen');
            } else {
              // Fall back to user document if not found in profiles collection
              _profileImageUrl = data['profileImageUrl'];
              developer.log('Loaded profile image from users collection', name: 'ProfileScreen');
            }
            
            // Set controller values
            _nameController.text = _userName;
            
            // Load theme preference (in a real app, you might use shared preferences)
            _isDarkTheme = data['darkTheme'] ?? false;
            _notificationsEnabled = data['notificationsEnabled'] ?? true;
          });
        }
      }
    } catch (e) {
      developer.log('Error loading user data: $e', name: 'ProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile data')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _pickAndUploadImage() async {
    try {
      // Pick image
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile == null) return;
      
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUpdating = true;
      });
      
      // Upload to Cloudinary
      final response = await _cloudinaryService.uploadFile(
        pickedFile.path,
        folder: 'user_profiles',
        progressCallback: (progress) {
          // Update progress if needed
          developer.log('Upload progress: ${(progress * 100).toStringAsFixed(2)}%', name: 'ProfileScreen');
        },
      );
      
      // Get the current user
      final user = _authService.currentUser;
      if (user != null) {
        // Get user data for additional profile metadata
        final userData = await _firestore.collection('users').doc(user.uid).get();
        final userDataMap = userData.exists ? userData.data() as Map<String, dynamic> : {};
        
        // Create profile data with Cloudinary information and user metadata
        final profileData = {
          'userId': user.uid,
          'publicId': response.publicId,
          'secureUrl': response.secureUrl,
          'updatedAt': FieldValue.serverTimestamp(),
          'userName': _userName,
          'userEmail': user.email,
          'university': userDataMap['university'] ?? _userUniversity,
          'role': userDataMap['role'] ?? _userRole,
          'lastUpdatedBy': user.uid,
        };
        
        // Check if a profile document already exists
        final profileDocRef = _firestore.collection('profiles').doc(user.uid);
        final profileDoc = await profileDocRef.get();
        
        if (profileDoc.exists) {
          // Update existing profile
          await profileDocRef.update(profileData);
          developer.log('Updated existing profile document', name: 'ProfileScreen');
        } else {
          // Create new profile document
          profileData['createdAt'] = FieldValue.serverTimestamp();
          profileData['createdBy'] = user.uid;
          await profileDocRef.set(profileData);
          developer.log('Created new profile document', name: 'ProfileScreen');
        }
        
        // Also update the user document with a reference to the profile image for quick access
        await _firestore.collection('users').doc(user.uid).update({
          'profileImageUrl': response.secureUrl,
          'hasProfileImage': true,
          'lastProfileUpdate': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _profileImageUrl = response.secureUrl;
        });
        
        developer.log('Profile image saved in profiles collection with ID: ${user.uid}', name: 'ProfileScreen');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture updated successfully')),
        );
      }
    } catch (e) {
      developer.log('Error uploading profile image: $e', name: 'ProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile picture')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    
    setState(() => _isUpdating = true);
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text.trim(),
        });
        
        // Update Firebase Auth display name
        await user.updateDisplayName(_nameController.text.trim());
        
        setState(() => _userName = _nameController.text.trim());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
        
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      developer.log('Error updating profile: $e', name: 'ProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  Future<void> _changePassword() async {
    // Validate inputs
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('All fields are required')),
      );
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    
    setState(() => _isUpdating = true);
    
    try {
      final user = _authService.currentUser;
      if (user != null && user.email != null) {
        // Reauthenticate user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Change password
        await user.updatePassword(_newPasswordController.text);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password changed successfully')),
        );
        
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        
        Navigator.pop(context); // Close dialog
      }
    } on FirebaseAuthException catch (e) {
      String message = 'An error occurred';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      developer.log('Error changing password: $e', name: 'ProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change password')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Change Password',
          style: TextStyle(
            color: Color(0xFF2D6DA8),
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        content: Container(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon at top
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF2D6DA8).withOpacity(0.1),
                    child: Icon(
                      Icons.lock,
                      color: Color(0xFF2D6DA8),
                      size: 30,
                    ),
                  ),
                ),
                
                // Current password field
                TextField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(color: Color(0xFF2D6DA8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Color(0xFF2D6DA8),
                        width: 2.0,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: Color(0xFF2D6DA8),
                    ),
                  ),
                  obscureText: true,
                ),
                
                SizedBox(height: 16),
                
                // New password field
                TextField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(color: Color(0xFF2D6DA8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Color(0xFF2D6DA8),
                        width: 2.0,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.lock_open,
                      color: Color(0xFF2D6DA8),
                    ),
                    helperText: 'Password must be at least 6 characters',
                    helperStyle: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  obscureText: true,
                ),
                
                SizedBox(height: 16),
                
                // Confirm new password field
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(color: Color(0xFF2D6DA8)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Color(0xFF2D6DA8),
                        width: 2.0,
                      ),
                    ),
                    prefixIcon: Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF2D6DA8),
                    ),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Change password button
          ElevatedButton(
            onPressed: _isUpdating ? null : _changePassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2D6DA8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isUpdating 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Update Password',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
  
  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF2D6DA8),
            fontWeight: FontWeight.bold,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile image at the top (optional)
              if (_profileImageUrl != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(_profileImageUrl!),
                  ),
                ),
              
              // Username field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Color(0xFF2D6DA8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Color(0xFF2D6DA8),
                      width: 2.0,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.person, 
                    color: Color(0xFF2D6DA8),
                  ),
                ),
              ),
              
              SizedBox(height: 8),
              
              // Email display (read-only)
              TextField(
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.grey),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  prefixIcon: Icon(Icons.email, color: Colors.grey),
                  hintText: _userEmail,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Save button
          ElevatedButton(
            onPressed: _isUpdating ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF2D6DA8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isUpdating 
                ? SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTheme(bool value) async {
    setState(() => _isDarkTheme = value);
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'darkTheme': value,
        });
      }
    } catch (e) {
      developer.log('Error updating theme preference: $e', name: 'ProfileScreen');
    }
  }
  
  Future<void> _updateNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'notificationsEnabled': value,
        });
      }
    } catch (e) {
      developer.log('Error updating notification preference: $e', name: 'ProfileScreen');
    }
  }
  
  Future<void> _deleteProfilePicture() async {
    try {
      setState(() => _isUpdating = true);
      
      final user = _authService.currentUser;
      if (user != null) {
        // Get the profile document to retrieve the Cloudinary public ID
        final profileDocRef = _firestore.collection('profiles').doc(user.uid);
        final profileDoc = await profileDocRef.get();
        
        if (profileDoc.exists) {
          final profileData = profileDoc.data() as Map<String, dynamic>;
          final publicId = profileData['publicId'];
          
          developer.log('Retrieved publicId from profile: $publicId', name: 'ProfileScreen');
          developer.log('Profile data: ${profileData.toString()}', name: 'ProfileScreen');
          
          // Delete the image from Cloudinary if we have a publicId
          if (publicId != null) {
            developer.log('Attempting to delete from Cloudinary with publicId: $publicId', name: 'ProfileScreen');
            
            // Check if Cloudinary service is properly configured
            final isConfigured = _cloudinaryService.isConfigured;
            developer.log('CloudinaryService is configured: $isConfigured', name: 'ProfileScreen');
            
            // Debug Cloudinary credentials
            _cloudinaryService.debugCredentials();
            
            final deleted = await _cloudinaryService.deleteFile(publicId);
            if (deleted) {
              developer.log('Successfully deleted image from Cloudinary: $publicId', name: 'ProfileScreen');
            } else {
              developer.log('Failed to delete image from Cloudinary: $publicId', name: 'ProfileScreen');
            }
          } else {
            developer.log('No publicId found in profile data', name: 'ProfileScreen');
          }
          
          // Update the profile document
          await profileDocRef.update({
            'publicId': FieldValue.delete(),
            'secureUrl': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
            'deletedAt': FieldValue.serverTimestamp(),
          });
        } else {
          developer.log('Profile document does not exist', name: 'ProfileScreen');
        }
        
        // Update the user document
        await _firestore.collection('users').doc(user.uid).update({
          'profileImageUrl': FieldValue.delete(),
          'hasProfileImage': false,
          'lastProfileUpdate': FieldValue.serverTimestamp(),
        });
        
        setState(() {
          _profileImageUrl = null;
          _imageFile = null;
        });
        
        developer.log('Profile picture deleted', name: 'ProfileScreen');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      developer.log('Error deleting profile image: $e', name: 'ProfileScreen');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove profile picture')),
      );
    } finally {
      setState(() => _isUpdating = false);
    }
  }
  
  void _showProfileImageOptions() {
    if (_profileImageUrl == null && _imageFile == null) {
      _pickAndUploadImage();
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D6DA8),
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF2D6DA8).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library,
                  color: Color(0xFF2D6DA8),
                ),
              ),
              title: Text('Change Picture'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete,
                  color: Colors.red,
                ),
              ),
              title: Text('Remove Picture'),
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Remove Profile Picture',
          style: TextStyle(
            color: Color(0xFF2D6DA8),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to remove your profile picture?',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfilePicture();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final Color blueColor = Color(0xFF2D6DA8);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: blueColor,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: blueColor))
          : SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile header with image
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(25),
                        bottomRight: Radius.circular(25),
                      ),
                    ),
                    padding: EdgeInsets.only(top: 24, bottom: 30, left: 16, right: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              // Profile image
                              GestureDetector(
                                onTap: _showProfileImageOptions,
                                onLongPress: () {
                                  // Show tooltip on long press
                                  if (_profileImageUrl != null || _imageFile != null) {
                                    HapticFeedback.mediumImpact();
                                    _showProfileImageOptions();
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Color(0xFF2D6DA8),
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: _imageFile != null 
                                        ? FileImage(_imageFile!) 
                                        : (_profileImageUrl != null 
                                            ? NetworkImage(_profileImageUrl!) as ImageProvider
                                            : null),
                                    child: (_profileImageUrl == null && _imageFile == null) 
                                        ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                                        : null,
                                  ),
                                ),
                              ),
                              
                              // Camera icon overlay
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _showProfileImageOptions,
                                  child: Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFf06517),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _profileImageUrl != null || _imageFile != null
                                          ? Icons.edit
                                          : Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Loading indicator during upload
                              if (_isUpdating)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _userEmail,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D6DA8).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.school,
                                      size: 16,
                                      color: const Color(0xFF2D6DA8),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _userRole,
                                      style: TextStyle(
                                        color: const Color(0xFF2D6DA8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFf06517).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: const Color(0xFFf06517),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _userUniversity.length > 20
                                          ? '${_userUniversity.substring(0, 20)}...'
                                          : _userUniversity,
                                      style: TextStyle(
                                        color: const Color(0xFFf06517),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Main content area
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        // Account section
                        _buildSectionHeader('Account'),
                        _buildListItem(
                          icon: Icons.edit,
                          title: 'Edit Profile',
                          color: blueColor,
                          onTap: _showEditProfileDialog,
                        ),
                        _buildListItem(
                          icon: Icons.key,
                          title: 'Change Password',
                          color: blueColor,
                          onTap: _showChangePasswordDialog,
                        ),
                        
                        // Preferences section
                        _buildSectionHeader('Preferences'),
                        _buildSwitchItem(
                          icon: Icons.dark_mode,
                          title: 'Theme',
                          subtitle: _isDarkTheme ? 'Dark' : 'Light',
                          color: blueColor,
                          value: _isDarkTheme,
                          onChanged: _updateTheme,
                        ),
                        _buildSwitchItem(
                          icon: Icons.notifications,
                          title: 'Notifications',
                          color: blueColor,
                          value: _notificationsEnabled,
                          onChanged: _updateNotifications,
                        ),
                        
                        // About section
                        _buildSectionHeader('About'),
                        _buildListItem(
                          icon: Icons.info,
                          title: 'About App',
                          color: blueColor,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Academia Hub v1.0')),
                            );
                          },
                        ),
                        _buildListItem(
                          icon: Icons.help,
                          title: 'Help & Support',
                          color: blueColor,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Support coming soon')),
                            );
                          },
                        ),
                        _buildListItem(
                          icon: Icons.privacy_tip,
                          title: 'Privacy Policy',
                          color: blueColor,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Privacy policy coming soon')),
                            );
                          },
                        ),
                        
                        SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2D6DA8),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildListItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Icon(
          Icons.chevron_right,
          color: color.withOpacity(0.7),
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: color,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey[300],
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 