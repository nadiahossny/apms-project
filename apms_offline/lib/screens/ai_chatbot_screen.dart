import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
class AiMessage {
  final String text;
  final bool isUser;
  final String? sqlQuery; // Optional, just to show the magic to the manager!

  AiMessage({required this.text, required this.isUser, this.sqlQuery});
}

class AiChatbotScreen extends StatefulWidget {
  const AiChatbotScreen({super.key});

  @override
  _AiChatbotScreenState createState() => _AiChatbotScreenState();
}

class _AiChatbotScreenState extends State<AiChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<AiMessage> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _voiceEnabled = false;

  // Assuming FastAPI runs locally on port 8000
  // Adjust host for Android Emulator if needed (10.0.2.2) or iOS/Desktop (127.0.0.1)
  String get _fastApiBaseUrl => 'http://${ApiService.gatewayHost}:8000';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initTts();
    // Welcome message
    _messages.add(
      AiMessage(
        text: 'Hello! I am your AI Pharmacy Assistant.\n\nAsk me anything about your inventory, sales, or prescriptions in plain English. For example:\n\n"What are the top 5 selling medicines this month?"',
        isUser: false,
      ),
    );
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _controller.text = val.recognizedWords;
          }),
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_controller.text.isNotEmpty) {
        _sendMessage();
      }
    }
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
        final answerText = data['answer'] ?? 'No answer provided.';
        setState(() {
          _messages.add(AiMessage(
            text: answerText,
            isUser: false,
            sqlQuery: data['sql_query'],
          ));
        });
        if (_voiceEnabled) _flutterTts.speak(answerText);
      } else {
        final errorText = 'I encountered an error connecting to my brain (Error ${response.statusCode}).';
        setState(() {
          _messages.add(AiMessage(
            text: errorText,
            isUser: false,
          ));
        });
        if (_voiceEnabled) _flutterTts.speak(errorText);
      }
    } catch (e) {
      const catchText = 'Oops! Cannot connect to the AI Service. Is the FastAPI server running?';
      setState(() {
        _messages.add(AiMessage(
          text: catchText,
          isUser: false,
        ));
      });
      if (_voiceEnabled) _flutterTts.speak(catchText);
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Widget _buildMessageBubble(AiMessage message) {
    final isUser = message.isUser;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AC.blue500,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AC.blue500.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AC.white, size: 20),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? AC.blue500 : AC.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AC.blue500.withOpacity(0.2)
                        : const Color(0x0A000000),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                border: isUser ? null : Border.all(color: AC.border, width: 1.0),
              ),
              child: isUser 
                  ? Text(
                      message.text,
                      style: const TextStyle(
                        color: AC.white,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : MarkdownBody(
                      data: message.text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: AC.ink900, fontSize: 15, height: 1.5),
                        strong: const TextStyle(color: AC.ink900, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(color: AC.blue500),
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AC.blueLt,
                child: Icon(Icons.person, color: AC.blue500, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.page,
      appBar: AppBar(
        backgroundColor: AC.white,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AC.blueLt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: AC.blue500, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'PharmaAI Assistant',
              style: TextStyle(
                color: AC.ink900, 
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: AC.ink900),
        actions: [
          IconButton(
            icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off),
            color: AC.blue500,
            onPressed: () {
              setState(() {
                _voiceEnabled = !_voiceEnabled;
                if (!_voiceEnabled) _flutterTts.stop();
              });
            },
          ),
        ],
      ),
      body: Container(
        color: AC.page,
        child: Column(
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
                            color: AC.blue500,
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
              decoration: const BoxDecoration(
                color: AC.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: AS.card,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPromptChip('Top 5 medicines'),
                          _buildPromptChip('Low stock items'),
                          _buildPromptChip('Daily revenue'),
                          _buildPromptChip('Recent prescriptions'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AC.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AC.borderMd, width: 1),
                            ),
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              style: const TextStyle(color: AC.ink900),
                              decoration: const InputDecoration(
                                hintText: 'Ask your assistant...',
                                hintStyle: TextStyle(color: AC.ink400),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _listen,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isListening ? Colors.redAccent : AC.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: _isListening ? Colors.redAccent : AC.borderMd, width: 1),
                              boxShadow: AS.button,
                            ),
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none, 
                              color: _isListening ? AC.white : AC.blue500, 
                              size: 22
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isLoading ? null : _sendMessage,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isLoading ? AC.ink200 : AC.blue500,
                              shape: BoxShape.circle,
                              boxShadow: AS.button,
                            ),
                            child: const Icon(Icons.send_rounded, color: AC.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 10.0),
      child: ActionChip(
        elevation: 0,
        pressElevation: 0,
        backgroundColor: AC.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AC.borderMd, width: 1),
        ),
        labelStyle: const TextStyle(
          color: AC.blue500, 
          fontSize: 13, 
          fontWeight: FontWeight.w600,
        ),
        label: Text(text),
        onPressed: () {
          _controller.text = text;
          _sendMessage();
        },
      ),
    );
  }
}
