import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/auth_service.dart';
import '../upload/cloudinary_service.dart';
import '../services/activity_points_service.dart';
import '../services/badge_service.dart';
import '../model/activity_points_model.dart';
import '../model/badge_model.dart' as models;
import '../widgets/badge_widget.dart';
import 'activity_points_screen.dart';
import 'dart:developer' as developer;
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import '../about/about_app_screen.dart';
import '../help/help_and_faqs_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityPointsService _activityPointsService = ActivityPointsService();
  final BadgeService _badgeService = BadgeService();
  
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoadingPoints = true;
  bool _isLoadingBadges = true;
  String _userName = '';
  String _userEmail = '';
  String _userUniversity = '';
  String _userRole = '';
  String _userBio = '';
  String? _profileImageUrl;
  ActivityPointsModel? _activityPoints;
  
  // Badge data
  List<models.Badge> _userBadges = [];
  models.Badge? _primaryBadge;
  
  // Controllers for edit profile
  final TextEditingController _nameController = TextEditingController();
  
  File? _imageFile;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadActivityPoints();
    _loadUserBadges();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserBadges() async {
    setState(() => _isLoadingBadges = true);
    
    try {
      // Get current user ID
      final user = _authService.currentUser;
      if (user != null) {
        // Get user's activity points to determine badge eligibility
        final activityPointsDoc = await _firestore.collection('activity_points').doc(user.uid).get();
        int activityPoints = 0;
        
        if (activityPointsDoc.exists) {
          final data = activityPointsDoc.data() as Map<String, dynamic>;
          activityPoints = data['totalPoints'] ?? 0;
        }
        
        // Get user badges and update based on activity points
        _userBadges = await _badgeService.updateUserBadges(user.uid, activityPoints);
        
        // Get primary badge (highest earned)
        _primaryBadge = await _badgeService.getHighestEarnedBadge(user.uid);
      }
    } catch (e) {
      developer.log('Error loading user badges: $e', name: 'ProfileScreen');
    } finally {
      setState(() => _isLoadingBadges = false);
    }
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
            _userBio = data['bio'] ?? '';
            
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
  
  Future<void> _loadActivityPoints() async {
    setState(() => _isLoadingPoints = true);
    
    try {
      final pointsModel = await _activityPointsService.getUserActivityPoints();
      setState(() {
        _activityPoints = pointsModel;
      });
    } catch (e) {
      developer.log('Error loading activity points: $e', name: 'ProfileScreen');
    } finally {
      setState(() => _isLoadingPoints = false);
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
    final Color orangeColor = Color(0xFFf06517);
    
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
                          if (_userBio.isNotEmpty) ...[
                            SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.symmetric(horizontal: 24),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _userBio,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[700],
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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
                          SizedBox(height: 16),
                          
                          // Activity Points badge
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: orangeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: orangeColor.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 20,
                                  color: orangeColor,
                                ),
                                SizedBox(width: 8),
                                _isLoadingPoints
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(orangeColor),
                                      ),
                                    )
                                  : Text(
                                      'Activity Points: ${_activityPoints?.totalPoints ?? 0}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: orangeColor,
                                      ),
                                    ),
                              ],
                            ),
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
                          icon: Icons.star_border,
                          title: 'Activity Points',
                          subtitle: 'View your earned points',
                          color: orangeColor,
                          onTap: _showActivityPointsDetails,
                        ),
                        _buildListItem(
                          icon: Icons.edit,
                          title: 'Edit Bio',
                          color: blueColor,
                          onTap: _showEditProfileDialog,
                        ),
                        _buildListItem(
                          icon: Icons.key,
                          title: 'Change Password',
                          color: blueColor,
                          onTap: _navigateToChangePassword,
                        ),
                        
                        // About section
                        _buildSectionHeader('About'),
                        _buildListItem(
                          icon: Icons.info,
                          title: 'About App',
                          color: blueColor,
                          onTap: _navigateToAboutApp,
                        ),
                        _buildListItem(
                          icon: Icons.help,
                          title: 'Help & FAQs',
                          color: blueColor,
                          onTap: _navigateToHelpAndFaqs,
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
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.2),
                color.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        subtitle: subtitle != null 
            ? Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ) 
            : null,
        trailing: Container(
      decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Padding(
          padding: EdgeInsets.all(8),
            child: Icon(
              Icons.chevron_right,
              color: color,
              size: 22,
            ),
          ),
        ),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  

  
  // Show Activity Points Details Screen
  void _showActivityPointsDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ActivityPointsScreen(
          activityPoints: _activityPoints,
          isLoading: _isLoadingPoints,
        ),
      ),
    );
  }
  
  // Activity Points Screen
  Widget _buildActivityPointsSection() {
    if (_isLoadingPoints) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_activityPoints == null) {
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
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('No activity points data found'),
        ),
      );
    }
    
    return Column(
      children: [
        _buildActivityItem(
          'Profile Completion',
          ActivityPointsService.PROFILE_COMPLETION_POINTS,
          _activityPoints!.oneTimeActivities[ActivityType.profileCompletion] ?? false,
          Icons.person_outline,
        ),
        _buildActivityItem(
          'University Email Verification',
          ActivityPointsService.UNIVERSITY_EMAIL_POINTS,
          _activityPoints!.oneTimeActivities[ActivityType.universityEmail] ?? false,
          Icons.email_outlined,
        ),
        _buildActivityItem(
          'First Login',
          ActivityPointsService.FIRST_LOGIN_POINTS,
          _activityPoints!.oneTimeActivities[ActivityType.firstLogin] ?? false,
          Icons.login_outlined,
        ),
        Container(
          margin: EdgeInsets.only(top: 8, bottom: 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.orange,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Keep earning points by uploading academic resources and logging in daily!',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildActivityItem(String title, int points, bool completed, IconData icon) {
    final Color itemColor = completed ? Colors.green : Colors.grey;
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: itemColor.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: itemColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                itemColor.withOpacity(0.2),
                itemColor.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: itemColor.withOpacity(0.1),
                blurRadius: 4,
                spreadRadius: 1,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            completed ? Icons.check_circle : icon,
            color: itemColor,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            color: completed ? Colors.black87 : Colors.grey[700],
            fontWeight: completed ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                completed ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                completed ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: completed ? Colors.green.withOpacity(0.1) : Colors.transparent,
                blurRadius: 4,
                spreadRadius: 0,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            '+$points',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: completed ? Colors.green : Colors.grey,
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  // Build badges section to display user's earned badges
  Widget _buildBadgesSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF2D6DA8).withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: Color(0xFF2D6DA8).withOpacity(0.1),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2D6DA8).withOpacity(0.2),
                        Color(0xFF2D6DA8).withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                  Icons.workspace_premium,
                  color: Color(0xFF2D6DA8),
                    size: 24,
                ),
                ),
                SizedBox(width: 12),
                Text(
                  'My Badges',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D6DA8),
                  ),
                ),
                Spacer(),
                if (!_isLoadingBadges && _userBadges.where((b) => b.isEarned).isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFf06517).withOpacity(0.2),
                          Color(0xFFf06517).withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: GestureDetector(
                    onTap: () {
                      // Navigate to badge details screen or show more badges
                      if (_activityPoints != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityPointsScreen(
                              activityPoints: _activityPoints!,
                            ),
                          ),
                        );
                      }
                    },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFFf06517),
                        fontWeight: FontWeight.bold,
                              fontSize: 14,
                      ),
                    ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFFf06517),
                            size: 12,
                  ),
              ],
            ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 20),
            _isLoadingBadges
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2D6DA8)),
                    ),
                  )
                : _userBadges.where((b) => b.isEarned).isEmpty
                    ? Center(
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                              Icons.emoji_events_outlined,
                              size: 60,
                              color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No badges earned yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Keep contributing to earn badges!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      )
                    : BadgesRow(
                        badges: _userBadges,
                        size: 70,
                        onBadgeTap: (badge) {
                          // Show badge details
                          _showBadgeDetails(badge);
                        },
                      ),
          ],
        ),
      ),
    );
  }
  
  // Show badge details in a dialog
  void _showBadgeDetails(models.Badge badge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge header with color
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: badge.color.withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  BadgeWidget(
                    badge: badge,
                    size: 60,
                    showUnearned: true,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: badge.color,
                          ),
                        ),
                        if (badge.isEarned) ...[
                          SizedBox(height: 4),
                          Text(
                            'Earned: ${_formatTimestamp(badge.earnedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ] else ...[
                          SizedBox(height: 4),
                          Text(
                            'Required: ${badge.pointsRequired} points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Badge description
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20),
                  // Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Color(0xFF2D6DA8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to format timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  // Add this method to build profile header with badge
  Widget _buildProfileHeader() {
    final avatarSize = 100.0;
    
    return Stack(
      children: [
        // Profile image
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: _profileImageUrl != null
            ? ClipOval(
                child: Image.network(
                  _profileImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Color(0xFF2D6DA8),
                          fontWeight: FontWeight.bold,
                          fontSize: 36,
                        ),
                      ),
                    );
                  },
                ),
              )
            : Center(
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Color(0xFF2D6DA8),
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
              ),
        ),
        
        // Badge overlay (if earned)
        if (_primaryBadge != null && !_isLoadingBadges)
          ProfileBadgeOverlay(
            badge: _primaryBadge!,
            avatarSize: avatarSize,
          ),
      ],
    );
  }

  // Replace the existing _showChangePasswordDialog method with this one
  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChangePasswordScreen(),
      ),
    );
  }

  void _showEditProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          initialProfileImageUrl: _profileImageUrl,
          initialName: _userName,
          initialEmail: _userEmail,
          initialBio: _userBio,
        ),
      ),
    ).then((_) {
      // Refresh user data when returning from edit screen
      _loadUserData();
    });
  }

  void _navigateToAboutApp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutAppScreen(),
      ),
    );
  }

  void _navigateToHelpAndFaqs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HelpAndFaqsScreen(),
      ),
    );
  }
} 