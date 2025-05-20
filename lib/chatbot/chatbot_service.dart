import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatbotResponse {
  final String text;
  final String? fileUrl;
  final String? fileType;
  final List<String>? suggestions;

  ChatbotResponse({
    required this.text,
    this.fileUrl,
    this.fileType,
    this.suggestions,
  });
}

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  String _apiUrl = '';
  bool _isInitialized = false;
  final List<Map<String, String>> _conversationHistory = [];
  
  // Key for storing the API URL in SharedPreferences
  static const String _apiUrlPrefKey = 'chatbot_api_url';
  
  // Default base URL for FastChat server
  String _baseUrl = '';

  // Getter for backend URL to be used by other services
  String? get backendUrl => _baseUrl.isNotEmpty ? _baseUrl : null;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Try to load last saved API URL from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _apiUrl = prefs.getString(_apiUrlPrefKey) ?? '';
      
      // If no saved URL, use a default one
      if (_apiUrl.isEmpty) {
        _apiUrl = 'https://your-ngrok-url.ngrok.io/chat';
      }
      
      // Extract the base URL from the API URL (for auto-updating)
      _updateBaseUrl();
      
      _isInitialized = true;
      developer.log(
        'Chatbot service initialized with API URL: $_apiUrl',
        name: 'ChatbotService',
      );
      
      // Try to auto-update the URL if possible
      await autoUpdateApiUrl();
    } catch (e) {
      developer.log('Error initializing chatbot: $e', name: 'ChatbotService');
      throw Exception('Failed to initialize chatbot service: $e');
    }
  }
  
  void _updateBaseUrl() {
    // Extract base URL from the API URL (remove the "/chat" endpoint)
    if (_apiUrl.isNotEmpty) {
      final uri = Uri.parse(_apiUrl);
      _baseUrl = '${uri.scheme}://${uri.host}';
      if (uri.port != 80 && uri.port != 443) {
        _baseUrl += ':${uri.port}';
      }
    }
  }
  
  // Method to auto-update the API URL from the Flask server
  Future<bool> autoUpdateApiUrl() async {
    if (_baseUrl.isEmpty) return false;
    
    try {
      // Request the current URL from the update_api_url endpoint
      final response = await http.get(
        Uri.parse('$_baseUrl/update_api_url'),
      ).timeout(Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newUrl = data['url'];
        
        if (newUrl != null && newUrl.isNotEmpty && newUrl != _apiUrl) {
          // Update the URL
          updateApiUrl(newUrl);
          return true;
        }
      }
      return false;
    } catch (e) {
      developer.log('Failed to auto-update API URL: $e', name: 'ChatbotService');
      return false;
    }
  }

  // Method to update API URL (useful for changing ngrok URLs)
  Future<void> updateApiUrl(String newUrl) async {
    _apiUrl = newUrl;
    _updateBaseUrl();
    
    // Save to SharedPreferences for persistence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlPrefKey, newUrl);
    
    developer.log(
      'Chatbot API URL updated to: $_apiUrl',
      name: 'ChatbotService',
    );
  }

  Future<ChatbotResponse> getResponse(String userInput) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_apiUrl.isEmpty) {
      throw Exception('Chatbot API URL is not set');
    }

    try {
      // Add user message to conversation history
      _conversationHistory.add({"role": "USER", "content": userInput});

      // Prepare the request body
      final Map<String, dynamic> requestBody = {
        'message': userInput,
        'conversation_history': _conversationHistory,
      };

      developer.log(
        'Sending request to API: $_apiUrl with message: $userInput',
        name: 'ChatbotService',
      );

      // Make API call to Flask server
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(
            Duration(seconds: 60),
            onTimeout: () {
              throw Exception(
                'Request timed out. The server might be busy or starting up. Please try again later.',
              );
            },
          );

      developer.log(
        'Received response with status code: ${response.statusCode}',
        name: 'ChatbotService',
      );

      if (response.statusCode == 200) {
        // Parse the response
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Get the assistant's response text
        final String assistantResponse =
            responseData['response'] ?? 'No response from the server';

        // Add assistant response to conversation history
        _conversationHistory.add({
          "role": "ASSISTANT",
          "content": assistantResponse,
        });

        // Log response for debugging
        developer.log(
          'Received response from chatbot: $assistantResponse',
          name: 'ChatbotService',
        );

        // Return the response
        return ChatbotResponse(
          text: assistantResponse,
          // Suggestions could be added later if the API supports them
        );
      } else if (response.statusCode == 500) {
        // Try to get error message from response
        String errorMessage = 'Unknown server error';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? 'Server error occurred';
        } catch (e) {
          errorMessage = 'Server error: ${response.body}';
        }

        // Log the detailed error
        developer.log(
          'Server error (500): $errorMessage',
          name: 'ChatbotService',
        );

        throw Exception('Server error: $errorMessage');
      } else {
        // Log the error
        developer.log(
          'Error calling chatbot API: ${response.statusCode} - ${response.body}',
          name: 'ChatbotService',
        );

        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } catch (e) {
      developer.log(
        'Error getting chatbot response: $e',
        name: 'ChatbotService',
      );

      // Add a specific error message for common issues
      String errorMessage = 'Failed to communicate with chatbot';

      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        errorMessage =
            'Cannot connect to the server. Please check that the API URL is correct and the server is running.';
      } else if (e.toString().contains('timed out')) {
        errorMessage =
            'Request timed out. The server might be busy or starting up. Please try again later.';
      } else if (e.toString().contains('model_name')) {
        errorMessage =
            'The server is experiencing an internal error. The model may be loading or not configured properly.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      throw Exception(errorMessage);
    }
  }

  // Clear conversation history
  void resetConversation() {
    _conversationHistory.clear();
    developer.log(
      'Chatbot conversation history cleared',
      name: 'ChatbotService',
    );
  }
}
