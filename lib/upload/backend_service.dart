import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class BackendService {
  static const String _backendUrlKey = 'backend_upload_url';
  String? _backendUrl;
  bool _isInitialized = false;

  // Singleton instance
  static final BackendService _instance = BackendService._internal();

  factory BackendService() {
    return _instance;
  }

  BackendService._internal();

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _backendUrl = prefs.getString(_backendUrlKey);
      _isInitialized = true;
    } catch (e) {
      print('Error initializing BackendService: $e');
    }
  }

  // Check if backend is configured
  bool get isConfigured => _backendUrl != null && _backendUrl!.isNotEmpty;

  // Get the backend URL
  String? get backendUrl => _backendUrl;

  // Set the backend URL
  Future<void> setBackendUrl(String url) async {
    try {
      // Validate URL format
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Remove trailing slash
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_backendUrlKey, url);

      // Update instance variable
      _backendUrl = url;

      print('Backend URL set to: $_backendUrl');
    } catch (e) {
      print('Error setting backend URL: $e');
      throw Exception('Failed to save backend URL: $e');
    }
  }

  // Configure backend URL with prompt
  Future<bool> configureBackendUrl(BuildContext context) async {
    await initialize();

    if (isConfigured) {
      return true;
    }

    // Prompt user for backend URL
    final TextEditingController controller = TextEditingController();

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Text('Backend Server Configuration'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Please enter the URL of your document processing backend:',
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'https://yourserver.ngrok.io',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Skip'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.isNotEmpty) {
                        try {
                          await setBackendUrl(controller.text);
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: Text('Save'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // Upload document to backend
  Future<Map<String, dynamic>> uploadDocument(
    String filePath,
    Map<String, dynamic> metadata, {
    Function(double)? progressCallback,
  }) async {
    await initialize();

    if (!isConfigured) {
      return {'success': false, 'message': 'Backend not configured'};
    }

    try {
      // Create the upload URL
      final uploadUrl = '$_backendUrl/upload';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Add file to request
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('File does not exist: $filePath');
      }

      // Add file
      final fileStream = http.ByteStream(file.openRead());
      final fileLength = await file.length();

      final multipartFile = http.MultipartFile(
        'file',
        fileStream,
        fileLength,
        filename: path.basename(filePath),
      );

      request.files.add(multipartFile);

      // Add metadata fields to request
      metadata.forEach((key, value) {
        if (value != null) {
          request.fields[key] = value.toString();
        }
      });

      // Track upload progress
      int bytesSent = 0;
      final streamedResponse = await request.send();

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Document uploaded to backend: ${responseData['document_id']}');
        return {
          'success': true,
          'message': 'Document uploaded successfully',
          'document_id': responseData['document_id'],
          'status_url': responseData['status_url'],
        };
      } else {
        print(
          'Error uploading document to backend: ${response.statusCode} ${response.body}',
        );
        return {
          'success': false,
          'message':
              'Failed to upload document: ${response.statusCode} ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      print('Exception uploading document to backend: $e');
      return {'success': false, 'message': 'Exception uploading document: $e'};
    }
  }

  // Check document processing status
  Future<Map<String, dynamic>> checkDocumentStatus(String documentId) async {
    await initialize();

    if (!isConfigured) {
      return {
        'success': false,
        'status': 'unknown',
        'message': 'Backend not configured',
      };
    }

    try {
      final statusUrl = '$_backendUrl/document_status/$documentId';
      final response = await http.get(Uri.parse(statusUrl));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'status': responseData['status'],
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'status': 'error',
          'message':
              'Failed to check status: ${response.statusCode} ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'status': 'error',
        'message': 'Exception checking status: $e',
      };
    }
  }
}
