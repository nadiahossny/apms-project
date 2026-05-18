import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class PatientOrderTrackingScreen extends StatefulWidget {
  final int prescriptionId;

  const PatientOrderTrackingScreen({Key? key, required this.prescriptionId}) : super(key: key);

  @override
  _PatientOrderTrackingScreenState createState() => _PatientOrderTrackingScreenState();
}

class _PatientOrderTrackingScreenState extends State<PatientOrderTrackingScreen> {
  late WebSocketChannel _channel;
  bool _isLoading = true;
  bool _isReady = false;
  String _roshettaCode = '';
  
  // Use a configured host, assuming localhost for emulator/simulator 
  final String _gatewayHost = '127.0.0.1'; // Update to match your environment

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _connectWebSocket();
  }

  Future<void> _fetchStatus() async {
    try {
      final url = Uri.parse('http://$_gatewayHost:4000/api/track-order/${widget.prescriptionId}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isReady = data['is_ready'] == true;
          _roshettaCode = data['roshetta_code'] ?? 'RX-${widget.prescriptionId}';
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint('Error fetching status: $e');
    }
  }

  void _connectWebSocket() {
    final wsUrl = Uri.parse('ws://$_gatewayHost:4000');
    _channel = WebSocketChannel.connect(wsUrl);
    _channel.stream.listen((message) {
      final decoded = jsonDecode(message);
      if (decoded['type'] == 'ORDER_READY') {
        final payload = decoded['payload'];
        if (payload['prescription_id'].toString() == widget.prescriptionId.toString()) {
          setState(() {
            _isReady = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      appBar: AppBar(
        backgroundColor: _isReady ? const Color(0xFF34D399) : const Color(0xFF8AB6F9),
        elevation: 0,
        title: const Text(
          'Order Status',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: _isReady ? const Color(0xFF34D399) : const Color(0xFF8AB6F9)))
        : Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: _isReady ? const Color(0xFFD1FAE5) : const Color(0xFFE0EAFC),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _isReady ? const Color(0xFF34D399).withOpacity(0.4) : const Color(0xFF8AB6F9).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 10,
                        )
                      ]
                    ),
                    child: Center(
                      child: Icon(
                        _isReady ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
                        size: 80,
                        color: _isReady ? const Color(0xFF10B981) : const Color(0xFF5A8DEE),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Order $_roshettaCode',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isReady ? 'Your order is ready for pickup!' : 'Your order is currently being prepared.\nPlease wait...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600, 
                      color: _isReady ? const Color(0xFF10B981) : const Color(0xFF6B7280)
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
