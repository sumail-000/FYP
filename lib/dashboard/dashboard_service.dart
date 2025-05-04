import 'package:flutter/material.dart';
import '../upload/upload_screen.dart';

class DashboardService {
  // Navigate to the upload screen
  static void navigateToUploadScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UploadScreen()),
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
} 