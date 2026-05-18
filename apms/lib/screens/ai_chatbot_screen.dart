import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AiMessage {
  final String text;
  final bool isUser;
  final String? sqlQuery; // Optional, just to show the magic to the manager!

  AiMessage({required this.text, required this.isUser, this.sqlQuery});
}

class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({Key? key}) : super(key: key);

  @override
  _AiChatbotScreenState createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // Assuming FastAPI runs locally on port 8000
  // Adjust host for Android Emulator if needed (10.0.2.2) or iOS/Desktop (127.0.0.1)
  final String _fastApiBaseUrl = 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(
      AiMessage(
        text: 'Hello! I am your AI Pharmacy Assistant.\n\nAsk me anything about your inventory, sales, or prescriptions in plain English. For example:\n\n"What are the top 5 selling medicines this month?"',
        isUser: false,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _messages.add(AiMessage(text: query, isUser: true));
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_fastApiBaseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(AiMessage(
            text: data['answer'] ?? 'No answer provided.',
            isUser: false,
            sqlQuery: data['sql_query'],
          ));
        });
      } else {
        setState(() {
          _messages.add(AiMessage(
            text: 'I encountered an error connecting to my brain (Error ${response.statusCode}).',
            isUser: false,
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(AiMessage(
          text: 'Oops! Cannot connect to the AI Service. Is the FastAPI server running?',
          isUser: false,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Widget _buildMessageBubble(AiMessage message) {
    final isUser = message.isUser;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF5A8DEE) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF2C3E50),
                fontSize: 15,
                height: 1.4,
              ),
            )]
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF5A8DEE)),
            SizedBox(width: 8),
            Text(
              'AI Command Center',
              style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.w700),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2C3E50)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E9EE), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 32, top: 8, bottom: 8),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFF89CFF0),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  );
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ask the AI...',
                        hintStyle: TextStyle(color: Colors.blueGrey[300]),
                        filled: true,
                        fillColor: const Color(0xFFF3F6FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isLoading ? const Color(0xFFB0C4DE) : const Color(0xFF5A8DEE),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!_isLoading)
                            BoxShadow(
                              color: const Color(0xFF5A8DEE).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
