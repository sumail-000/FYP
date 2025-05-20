import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import '../chatbot/chatbot_service.dart'; // Import ChatbotService to reuse the URL

class BackendService {
  static const String _backendUrlKey = 'backend_upload_url';
  String? _backendUrl;
  bool _isInitialized = false;
  bool _isAutomaticUrlDetected = false; // Track if we automatically detected the URL

  // Reference to ChatbotService for URL reuse
  final ChatbotService _chatbotService = ChatbotService();

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

      // If no URL is set, try to get it from ChatbotService
      if (_backendUrl == null || _backendUrl!.isEmpty) {
        await _tryGetUrlFromChatbot();
      }
    } catch (e) {
      print('Error initializing BackendService: $e');
    }
  }

  // Try to get the URL from ChatbotService
  Future<bool> _tryGetUrlFromChatbot() async {
    try {
      // First ensure ChatbotService is initialized
      await _chatbotService.initialize();
      
      // Get the URL from ChatbotService
      final chatbotUrl = _chatbotService.backendUrl;
      
      if (chatbotUrl != null && chatbotUrl.isNotEmpty) {
        // Convert the chatbot URL to the backend URL by replacing /chat with proper endpoint
        String baseUrl = '';
        
        // Extract the base URL (remove /chat or any other endpoint)
        if (chatbotUrl.contains('/chat')) {
          baseUrl = chatbotUrl.substring(0, chatbotUrl.lastIndexOf('/chat'));
        } else {
          // If no /chat endpoint, use as is
          baseUrl = chatbotUrl;
        }
        
        // Set the backend URL with the document processing endpoint
        _backendUrl = '$baseUrl/process_document';
        
        // Save the URL to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_backendUrlKey, _backendUrl!);
        
        _isAutomaticUrlDetected = true;
        print('Backend URL automatically set from chatbot URL: $_backendUrl');
        return true;
      }
      return false;
    } catch (e) {
      print('Error getting URL from ChatbotService: $e');
      return false;
    }
  }

  // Check if backend is configured
  bool get isConfigured => _backendUrl != null && _backendUrl!.isNotEmpty;
  
  // Check if URL was automatically detected
  bool get isAutomaticUrlDetected => _isAutomaticUrlDetected;

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
      _isAutomaticUrlDetected = false; // Reset since user manually set URL

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

    // Try to get URL from chatbot service first
    final autoDetected = await _tryGetUrlFromChatbot();
    if (autoDetected) {
      // Let user know we automatically configured it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend URL automatically configured from chatbot settings.'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    }

    // Prompt user for backend URL
    final TextEditingController controller = TextEditingController();
    
    // Status message for automatic URL detection
    String statusMessage = '';

    // Show dialog
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Backend Server Configuration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    suffixIcon: IconButton(
                      icon: Icon(Icons.refresh),
                      tooltip: 'Try to detect from chatbot settings',
                      onPressed: () async {
                        final detected = await _tryGetUrlFromChatbot();
                        if (detected) {
                          controller.text = _backendUrl ?? '';
                          setState(() {
                            statusMessage = 'URL successfully detected from chatbot settings!';
                          });
                        } else {
                          setState(() {
                            statusMessage = 'Could not detect URL from chatbot. Please enter manually.';
                          });
                        }
                      },
                    ),
                  ),
                  keyboardType: TextInputType.url,
                ),
                if (statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      statusMessage,
                      style: TextStyle(
                        color: statusMessage.contains('successfully') ? Colors.green : Colors.red,
                        fontSize: 12,
                      ),
                    ),
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
                  if (_isAutomaticUrlDetected || controller.text.isNotEmpty) {
                    try {
                      if (!_isAutomaticUrlDetected) {
                        await setBackendUrl(controller.text);
                      }
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: Text('Save'),
              ),
            ],
          );
        }
      ),
    ) ?? false;
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
      final uploadUrl = '$_backendUrl/process_document';

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

      // Send request
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
