import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../auth/auth_service.dart';
import '../services/presence_service.dart';
import 'chatbot_service.dart';

class ChatbotMessage {
  final String text;
  final bool isUserMessage;
  final String? fileUrl;
  final String? fileType;
  final List<String>? suggestions;

  ChatbotMessage({
    required this.text,
    required this.isUserMessage,
    this.fileUrl,
    this.fileType,
    this.suggestions,
  });
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final PresenceService _presenceService = PresenceService();
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isSendingMessage = false;
  bool _isCheckingConnection = false;
  List<ChatbotMessage> _messages = [];
  String _currentApiUrl = '';
  bool _isAutoUpdateEnabled = true;

  // App colors
  final Color blueColor = const Color(0xFF2D6DA8);
  final Color purpleColor = const Color(0xFFE6D5E8); // Purple for user messages
  final Color orangeColor = const Color(0xFFf06517);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChatbot();
    _updatePresence(true);
    developer.log('ChatbotScreen initialized', name: 'Chatbot');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _apiUrlController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
      // Try to auto-update the API URL when app is resumed
      if (_isAutoUpdateEnabled) {
        _checkAndUpdateApiUrl();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _updatePresence(false);
    }
  }

  Future<void> _updatePresence(bool isOnline) async {
    await _presenceService.updatePresence(
      isOnline: isOnline,
      screen: 'chatbot',
    );
  }

  Future<void> _initializeChatbot() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _chatbotService.initialize();

      // Get the current API URL for display
      _currentApiUrl = 'https://your-ngrok-url.ngrok.io/chat';
      _apiUrlController.text = _currentApiUrl;

      setState(() {
        _messages = [
          ChatbotMessage(
            text:
                "Hello! I'm your AI assistant. I'll try to automatically connect to the Flask API. If I can't connect, please set the API URL manually by clicking the settings icon in the top-right corner.",
            isUserMessage: false,
          ),
        ];
        _isLoading = false;
      });
      
      // Try to auto-update the API URL
      if (_isAutoUpdateEnabled) {
        _checkAndUpdateApiUrl();
      }
    } catch (e) {
      developer.log('Error initializing chatbot: $e', name: 'Chatbot');
      setState(() {
        _messages = [
          ChatbotMessage(
            text:
                "Error initializing the chatbot service. Please try again by clicking the settings icon and setting the API URL.",
            isUserMessage: false,
          ),
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndUpdateApiUrl() async {
    if (_isCheckingConnection) return;
    
    setState(() {
      _isCheckingConnection = true;
    });
    
    try {
      final updated = await _chatbotService.autoUpdateApiUrl();
      if (updated) {
        // If URL was updated, update the UI
        setState(() {
          _currentApiUrl = _apiUrlController.text;
          _messages.add(
            ChatbotMessage(
              text: "Connected to a new API endpoint automatically.",
              isUserMessage: false,
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      developer.log('Error checking API URL: $e', name: 'Chatbot');
    } finally {
      setState(() {
        _isCheckingConnection = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _updateApiUrl() async {
    final newUrl = _apiUrlController.text.trim();
    if (newUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('API URL cannot be empty')));
      return;
    }

    if (!newUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API URL must start with http:// or https://')),
      );
      return;
    }

    setState(() {
      _currentApiUrl = newUrl;
    });

    await _chatbotService.updateApiUrl(newUrl);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('API URL updated successfully')));

    Navigator.pop(context); // Close dialog

    // Add a system message
    setState(() {
      _messages.add(
        ChatbotMessage(text: "Connected to API: $newUrl", isUserMessage: false),
      );
    });

    // Reset the conversation in the service
    _chatbotService.resetConversation();
  }

  void _showApiUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.api_rounded,
                      color: blueColor,
                      size: 28,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'API Connection',
                        style: TextStyle(
                          color: blueColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Enter your ngrok URL for the AI Assistant:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _apiUrlController,
                    decoration: InputDecoration(
                      hintText: 'https://your-ngrok-url.ngrok.io/chat',
                      prefixIcon: Icon(Icons.link, color: blueColor),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 15,
                      ),
                    ),
                    onSubmitted: (_) => _updateApiUrl(),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: _isAutoUpdateEnabled,
                          activeColor: blueColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _isAutoUpdateEnabled = value ?? true;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Auto-update URL when possible',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: orangeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: orangeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Icon(
                          Icons.info_outline,
                          color: orangeColor,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This URL comes from your Colab notebook and changes each time you restart it.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _updateApiUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'CONNECT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _resetConversation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Reset Conversation'),
            content: Text('This will clear all messages. Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _messages.clear();
                    _messages.add(
                      ChatbotMessage(
                        text:
                            "Conversation has been reset. You can start a new chat now.",
                        isUserMessage: false,
                      ),
                    );
                  });
                  _chatbotService.resetConversation();
                },
                child: Text('RESET'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check if API URL is set
    if (_currentApiUrl.isEmpty ||
        _currentApiUrl == 'https://your-ngrok-url.ngrok.io/chat') {
      
      // Try to auto-update first
      if (_isAutoUpdateEnabled) {
        setState(() {
          _isCheckingConnection = true;
          _messages.add(
            ChatbotMessage(
              text: "Trying to connect to the AI service...",
              isUserMessage: false,
            ),
          );
        });
        
        bool updated = await _chatbotService.autoUpdateApiUrl();
        setState(() {
          _isCheckingConnection = false;
        });
        
        if (!updated) {
          // If auto-update failed, show dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please set the API URL first')),
          );
          _showApiUrlDialog();
          return;
        }
      } else {
        // If auto-update is disabled, show dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please set the API URL first')),
        );
        _showApiUrlDialog();
        return;
      }
    }

    // Add user message
    setState(() {
      _messages.add(ChatbotMessage(text: text, isUserMessage: true));
      _isSendingMessage = true;
    });

    // Clear text field
    _messageController.clear();

    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), _scrollToBottom);

    try {
      // Get response from chatbot service
      final response = await _chatbotService.getResponse(text);

      setState(() {
        _messages.add(
          ChatbotMessage(
            text: response.text,
            isUserMessage: false,
            fileUrl: response.fileUrl,
            fileType: response.fileType,
            suggestions: response.suggestions,
          ),
        );
        _isSendingMessage = false;
      });
    } catch (e) {
      developer.log('Error getting chatbot response: $e', name: 'Chatbot');
      setState(() {
        _messages.add(
          ChatbotMessage(
            text:
                "Sorry, I couldn't connect to the AI service. Please check your API URL and internet connection.",
            isUserMessage: false,
          ),
        );
        _isSendingMessage = false;
      });
      
      // Try to auto-update if connection failed
      if (_isAutoUpdateEnabled) {
        _checkAndUpdateApiUrl();
      }
    } finally {
      // Scroll to bottom after response
      Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: blueColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'AI Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isCheckingConnection)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Checking connection...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _resetConversation,
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: Colors.white),
                    onPressed: _showApiUrlDialog,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child:
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: blueColor))
                    : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(_messages[index]);
                      },
                    ),
          ),

          // Message input
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: blueColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed:
                        _isSendingMessage || _isCheckingConnection
                            ? null
                            : () => _sendMessage(_messageController.text),
                    icon:
                        _isSendingMessage || _isCheckingConnection
                            ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatbotMessage message) {
    Widget content;

    if (message.isUserMessage) {
      // User message (right side) - purple bubble
      content = Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: EdgeInsets.only(left: 80, bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: purpleColor, // Purple color from screenshot
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(message.text, style: TextStyle(fontSize: 16)),
        ),
      );
    } else {
      // Bot message (left side) - light blue bubble with bot icon
      content = Align(
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(right: 8, top: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: blueColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(right: 80, bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  // Show suggestions if available
                  if (message.suggestions != null &&
                      message.suggestions!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: message.suggestions!
                          .map(
                            (suggestion) => GestureDetector(
                              onTap: () => _sendMessage(suggestion),
                              child: Container(
                                margin: EdgeInsets.only(bottom: 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  suggestion,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: blueColor,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return content;
  }
}
