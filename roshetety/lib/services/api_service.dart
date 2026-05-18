// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NetworkException implements Exception {
  final String message;
  final bool isOffline;
  const NetworkException(this.message, {this.isOffline = false});
  @override String toString() => message;
}

class RoshettyApi {

   static const _base = 'http://127.0.0.1:4000/api';
    static const _timeout = Duration(seconds: 8);

  static Future<Map<String,dynamic>> checkPrescription({
    required List<Map<String,dynamic>> medicines,
    String? roshettaCode,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/public/check-prescription'), 
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // سطر تخطي صفحة التحذير بتاعة نجروك
        },
        body: jsonEncode({
          'medicines': medicines,
          if (roshettaCode != null) 'roshetta_code': roshettaCode,
        }),
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String,dynamic>;
      } else if (resp.statusCode == 429) {
        throw const NetworkException('Too many requests — please wait a moment');
      } else {
        throw NetworkException('Server error: ${resp.statusCode}');
      }
    } on TimeoutException {
      throw const NetworkException(
        'Connection timed out — make sure you are on the pharmacy network',
        isOffline: true);
    } catch (e) {
      if (e is NetworkException) rethrow;
      final msg = e.toString();
      final offline = msg.contains('SocketException') ||
                      msg.contains('Connection refused') ||
                      msg.contains('OS Error');
      throw NetworkException(
        offline ? 'Cannot reach pharmacy server' : msg,
        isOffline: offline);
    }
  }

  // إرسال الطلب لقاعدة البيانات
  static Future<int?> placeOrder({
    required List<Map<String, dynamic>> cartItems,
    String? patientName,
  }) async {
    try {
      final formattedItems = cartItems.map((item) => {
        'medicine_id': item['medicine_id'], 
        'quantity_prescribed': item['quantity'] ?? 1,
        'requested_name': item['requested'] ?? item['trade_name'] ?? item['name'],    
      }).toList();

      final resp = await http.post(
        Uri.parse('$_base/prescriptions'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // سطر تخطي صفحة التحذير مهم جداً هنا
        },
        body: jsonEncode({
          'patient_name': patientName ?? 'App User',
          'notes': 'Submitted via Roshetty App',
          'items': formattedItems,
        }),
      ).timeout(_timeout);

      if (resp.statusCode == 201 || resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['prescription_id'] as int?;
      } else {
        print("APMS Server Error: ${resp.statusCode} - ${resp.body}");
        throw NetworkException('Server rejected order: ${resp.statusCode}');
      }
    } catch (e) {
      print("Connection Error: $e");
      throw NetworkException('Failed to connect to APMS');
    }
  }
}