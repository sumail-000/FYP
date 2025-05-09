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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  List<ChatbotMessage> _messages = [];

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
    _scrollController.dispose();
    _focusNode.dispose();
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
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

      // Get initial greeting from chatbot
      final response = await _chatbotService.getResponse('hello');

      setState(() {
        _messages = [
          ChatbotMessage(
            text: response.text,
            isUserMessage: false,
            suggestions: response.suggestions,
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      developer.log('Error initializing chatbot: $e', name: 'Chatbot');
      setState(() {
        _messages = [
          ChatbotMessage(
            text: 'Hello! Ask me anything about Academia Hub.',
            isUserMessage: false,
            suggestions: [
              'Tell me about courses',
              'How to use the chat feature',
              'How to add friends',
            ],
          ),
        ];
        _isLoading = false;
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    // Add user message
    setState(() {
      _messages.add(ChatbotMessage(text: text, isUserMessage: true));
      _isLoading = true;
    });

    // Clear text field
    _messageController.clear();

    // Scroll to bottom
    Future.delayed(Duration(milliseconds: 100), _scrollToBottom);

    // Get response from chatbot service
    _chatbotService
        .getResponse(text)
        .then((response) {
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
            _isLoading = false;
          });

          // Scroll to bottom after response
          Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
        })
        .catchError((error) {
          developer.log(
            'Error getting chatbot response: $error',
            name: 'Chatbot',
          );
          setState(() {
            _messages.add(
              ChatbotMessage(
                text: 'Sorry, I encountered an error. Please try again later.',
                isUserMessage: false,
              ),
            );
            _isLoading = false;
          });
          Future.delayed(Duration(milliseconds: 100), _scrollToBottom);
        });
  }

  void _useSuggestion(String suggestion) {
    _messageController.text = suggestion;
    _sendMessage(suggestion);
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
                    child: Center(
                      child: Text(
                        'Chatbot',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      // Menu functionality can be added later
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Show loading indicator
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.only(right: 80, bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: blueColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: blueColor,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Thinking...',
                            style: TextStyle(color: blueColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final message = _messages[index];
                return _buildMessageItem(message);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type something...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Material(
                  color: blueColor,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.arrow_forward, color: Colors.white),
                    ),
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
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy, color: blueColor),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(
                      right: 80,
                      bottom:
                          (message.fileUrl != null ||
                                  message.suggestions != null)
                              ? 8
                              : 12,
                    ),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: blueColor.withOpacity(
                        0.2,
                      ), // Light blue from screenshot
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(message.text, style: TextStyle(fontSize: 16)),
                  ),
                  if (message.fileUrl != null)
                    Container(
                      margin: EdgeInsets.only(
                        right: 80,
                        bottom: message.suggestions != null ? 8 : 12,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.fileType == 'pdf'
                                ? Icons.picture_as_pdf
                                : Icons.insert_drive_file,
                            color: Colors.red,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            message.fileUrl!,
                            style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: blueColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Download",
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.suggestions != null &&
                      message.suggestions!.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(right: 80, bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            message.suggestions!.map((suggestion) {
                              return GestureDetector(
                                onTap: () => _useSuggestion(suggestion),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: blueColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    suggestion,
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
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
