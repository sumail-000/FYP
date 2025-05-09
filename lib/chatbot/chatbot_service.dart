import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

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

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) {
    return ChatbotResponse(
      text: json['text'] as String,
      fileUrl: json['fileUrl'] as String?,
      fileType: json['fileType'] as String?,
      suggestions:
          json['suggestions'] != null
              ? List<String>.from(json['suggestions'])
              : null,
    );
  }
}

class ChatbotIntent {
  final String intent;
  final List<String> patterns;
  final List<ChatbotResponse> responses;

  ChatbotIntent({
    required this.intent,
    required this.patterns,
    required this.responses,
  });

  factory ChatbotIntent.fromJson(Map<String, dynamic> json) {
    return ChatbotIntent(
      intent: json['intent'] as String,
      patterns: List<String>.from(json['patterns']),
      responses:
          (json['responses'] as List)
              .map((response) => ChatbotResponse.fromJson(response))
              .toList(),
    );
  }
}

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  List<ChatbotIntent> _intents = [];
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load conversation data from assets
      final String jsonData = await rootBundle.loadString(
        'assets/chatbot_data.json',
      );
      final Map<String, dynamic> data = json.decode(jsonData);

      _intents =
          (data['intents'] as List)
              .map((intent) => ChatbotIntent.fromJson(intent))
              .toList();

      _isInitialized = true;
      developer.log(
        'Chatbot service initialized with ${_intents.length} intents',
        name: 'ChatbotService',
      );
    } catch (e) {
      developer.log('Error initializing chatbot: $e', name: 'ChatbotService');
      // Fallback to basic intents if file loading fails
      _setupBasicIntents();
    }
  }

  void _setupBasicIntents() {
    _intents = [
      ChatbotIntent(
        intent: 'greeting',
        patterns: ['hello', 'hi', 'hey', 'greetings'],
        responses: [
          ChatbotResponse(
            text:
                'Hello! Ask me anything about journalism, media, or news reporting.',
          ),
        ],
      ),
      ChatbotIntent(
        intent: 'news_reporting',
        patterns: [
          'what is news reporting',
          'news reporting',
          'reporting news',
        ],
        responses: [
          ChatbotResponse(
            text:
                'News reporting means gathering information about events and presenting it to the public through media',
            fileUrl: 'news_reporting.pdf',
            fileType: 'pdf',
          ),
        ],
      ),
      ChatbotIntent(
        intent: 'challenges',
        patterns: [
          'challenges in news reporting',
          'reporting challenges',
          'news challenges',
        ],
        responses: [
          ChatbotResponse(
            text:
                'Lack of access to reliable sources.\nSafety in conflict areas.\nRisk of fake news.',
            fileUrl: 'challenges.pdf',
            fileType: 'pdf',
          ),
        ],
      ),
      ChatbotIntent(
        intent: 'thanks',
        patterns: ['thank you', 'thanks', 'appreciate it'],
        responses: [
          ChatbotResponse(
            text: 'You\'re welcome! Is there anything else you want to know?',
            suggestions: [
              'What is news reporting?',
              'Challenges in News Reporting',
            ],
          ),
        ],
      ),
      ChatbotIntent(
        intent: 'fallback',
        patterns: [],
        responses: [
          ChatbotResponse(
            text:
                'I\'m not sure about that. You can ask me about "news reporting" or "challenges in news reporting".',
            suggestions: [
              'What is news reporting?',
              'Challenges in News Reporting',
            ],
          ),
        ],
      ),
    ];

    _isInitialized = true;
    developer.log(
      'Chatbot service initialized with basic intents',
      name: 'ChatbotService',
    );
  }

  Future<ChatbotResponse> getResponse(String userInput) async {
    if (!_isInitialized) {
      await initialize();
    }

    final String normalizedInput = userInput.toLowerCase().trim();

    // Find matching intent
    for (final intent in _intents) {
      for (final pattern in intent.patterns) {
        if (normalizedInput.contains(pattern.toLowerCase())) {
          // Return a random response from the matching intent
          final responses = intent.responses;
          final randomIndex =
              (DateTime.now().millisecondsSinceEpoch % responses.length)
                  .toInt();
          return responses[randomIndex];
        }
      }
    }

    // Return fallback response if no match found
    final fallbackIntent = _intents.firstWhere(
      (intent) => intent.intent == 'fallback',
    );
    final responses = fallbackIntent.responses;
    final randomIndex =
        (DateTime.now().millisecondsSinceEpoch % responses.length).toInt();
    return responses[randomIndex];
  }
}
