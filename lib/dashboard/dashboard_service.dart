import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../upload/upload_screen.dart';
import '../profile/profile_screen.dart';
import '../chatbot/chatbot_screen.dart';

class DashboardService {
  // Navigate to the upload screen
  static void navigateToUploadScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UploadScreen()),
    );
  }

  // Navigate to the profile screen
  static void navigateToProfileScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  // Navigate to the chatbot screen
  static void navigateToChatbotScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotScreen()),
    );
  }

  // Show feature not available message
  static void showFeatureNotAvailable(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature is coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Return the icon for a file type
  static IconData getIconForFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  // Download document to device and open it
  static Future<void> downloadDocument(
    BuildContext context,
    String url,
    String fileName,
    String extension,
  ) async {
    // Show a message that downloads are not supported on Cloudinary's free plan
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cloudinary does not support direct downloads on the free plan.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        backgroundColor: Colors.red[700],
      ),
    );
  }
}

