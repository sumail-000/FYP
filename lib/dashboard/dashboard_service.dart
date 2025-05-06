import 'package:flutter/material.dart';
import '../upload/upload_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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

  // Open document using URL launcher
  static Future<void> openDocument(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document URL not available'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open document: ${e.toString().split(":")[0]}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
}
