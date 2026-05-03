// roshetty/lib/screens/result_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:roshetety/services/api_service.dart';
import 'package:roshetety/screens/home_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> meds;
  final bool arabic;
  const ResultScreen({super.key, required this.meds, required this.arabic});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSending = false;

  Future<void> _confirmAndSend() async {
    setState(() => _isSending = true);
    try {
      // Sends list to APMS: [{ 'requested_name': name, 'quantity_prescribed': 1 }]
      await RoshettyApi.placeOrder(cartItems: widget.meds);
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.arabic ? 'خطأ في الإرسال' : 'Error sending')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(widget.arabic ? 'تم الإرسال' : 'Sent!'),
          actions: [
            // Inside ResultScreen -> _showSuccess()
TextButton(
  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => HomeScreen(arabic: widget.arabic)), // Fixed parameter
    (route) => false),
  child: Text(widget.arabic ? 'موافق' : 'OK'),
)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.arabic ? 'مراجعة الطلب' : 'Review Order')),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: widget.meds.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.medication),
                  title: Text(widget.meds[i]['name'] ?? ''),
                ),
              ),
            ),
            // Update inside building ResultScreen
Padding(
  padding: const EdgeInsets.all(24.0),
  child: GestureDetector(
    onTap: _isSending ? null : _confirmAndSend,
    child: Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF5A8DEE),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8DEE).withOpacity(0.2), 
            blurRadius: 12, 
            offset: const Offset(0, 6)
          )
        ],
      ),
      child: Center(
        child: _isSending 
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(
              widget.arabic ? 'تأكيد وإرسال' : 'Confirm & Send',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
      ),
    ),
  ),
)
          ],
        ),
      ),
    );
  }
}