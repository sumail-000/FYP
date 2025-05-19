import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

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

  // URL should be updated with your actual ngrok URL from Colab
  // This is a placeholder and should be replaced with your actual endpoint
  String _apiUrl = '';
  bool _isInitialized = false;
  final List<Map<String, String>> _conversationHistory = [];

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // You could fetch the API URL from your server or a config file
      // For now, we'll hardcode it or provide a method to set it
      _apiUrl =
          'https://150c-34-143-236-37.ngrok-free.app/chat'; // Replace with your actual ngrok URL

      _isInitialized = true;
      developer.log(
        'Chatbot service initialized with API URL: $_apiUrl',
        name: 'ChatbotService',
      );
    } catch (e) {
      developer.log('Error initializing chatbot: $e', name: 'ChatbotService');
      throw Exception('Failed to initialize chatbot service: $e');
    }
  }

  // Method to update API URL (useful for changing ngrok URLs)
  void updateApiUrl(String newUrl) {
    _apiUrl = newUrl;
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

      // Make API call to FastChat server
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
