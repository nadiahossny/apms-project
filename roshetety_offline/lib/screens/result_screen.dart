// roshetty/lib/screens/result_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:roshetety/services/api_service.dart';
import 'package:roshetety/screens/home_screen.dart';
import 'package:roshetety/screens/patient_order_tracking_screen.dart';

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
      final orderId = await RoshettyApi.placeOrder(cartItems: widget.meds);
      if (!mounted) return;
      _showSuccess(orderId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.arabic ? 'خطأ في الإرسال' : 'Error sending')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSuccess(int? orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(widget.arabic ? 'تم الإرسال بنجاح!' : 'Sent Successfully!', style: const TextStyle(color: Color(0xFF5A8DEE), fontWeight: FontWeight.bold)),
          content: orderId != null ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.arabic ? 'يرجى الاحتفاظ برقم الطلب لتتبعه:' : 'Please keep this Order ID to track it:', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8AB6F9).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '#$orderId',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50), letterSpacing: 2),
                ),
              ),
            ],
          ) : Text(widget.arabic ? 'تم الإرسال بنجاح' : 'Order placed successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => HomeScreen(arabic: widget.arabic)),
                (route) => false),
              child: Text(widget.arabic ? 'موافق' : 'OK'),
            ),
            if (orderId != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8DEE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomeScreen(arabic: widget.arabic)),
                    (route) => false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientOrderTrackingScreen(prescriptionId: orderId),
                    ),
                  );
                },
                child: Text(widget.arabic ? 'تتبع الآن' : 'Track Now', style: const TextStyle(color: Colors.white)),
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