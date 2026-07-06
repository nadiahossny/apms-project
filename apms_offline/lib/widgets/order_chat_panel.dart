import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';

class OrderChatPanel extends StatefulWidget {
  final int prescriptionId;

  const OrderChatPanel({super.key, required this.prescriptionId});

  @override
  _OrderChatPanelState createState() => _OrderChatPanelState();
}

class _OrderChatPanelState extends State<OrderChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  late WebSocketChannel _channel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _connectWebSocket();
  }

  Future<void> _fetchMessages() async {
    try {
      final url = Uri.parse('http://${ApiService.gatewayHost}:4000/api/prescriptions/${widget.prescriptionId}/chat');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _messages.addAll(data.map((e) => e as Map<String, dynamic>).toList());
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error fetching messages: $e');
    }
  }

  void _connectWebSocket() {
    final wsUrl = Uri.parse('ws://${ApiService.gatewayHost}:4000');
    _channel = WebSocketChannel.connect(wsUrl);
    _channel.stream.listen((message) {
      final decoded = jsonDecode(message);
      if (decoded['type'] == 'chat_message') {
        final payload = decoded['payload'];
        if (payload['prescription_id'] == widget.prescriptionId) {
          setState(() {
            _messages.add(payload);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    
    final message = _controller.text.trim();
    _controller.clear();

    final url = Uri.parse('http://${ApiService.gatewayHost}:4000/api/prescriptions/${widget.prescriptionId}/chat');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_type': 'MANAGER',
          'message': message,
        }),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF), // Alice Blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF89CFF0).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF89CFF0), // Baby Blue header
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Order #${widget.prescriptionId} Chat',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isManager = msg['sender_type'] == 'MANAGER';
                return Align(
                  alignment: isManager ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isManager ? const Color(0xFF89CFF0) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        )
                      ]
                    ),
                    child: Text(
                      msg['message'] ?? '',
                      style: TextStyle(
                        color: isManager ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                backgroundColor: const Color(0xFFEBF4FF),
                labelStyle: const TextStyle(color: Color(0xFF89CFF0), fontWeight: FontWeight.bold, fontSize: 12),
                label: const Text('Send: Order is Ready!'),
                onPressed: () {
                  _controller.text = 'Your order is ready for pickup or delivery!';
                  _sendMessage();
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.blueGrey[300]),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF89CFF0),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
