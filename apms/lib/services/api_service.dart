import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_store.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Config {
  static String gatewayHost = '127.0.0.1';
  static int gatewayPort = 4000;

  static Uri uri(String path) {
    final url = 'http://$gatewayHost:$gatewayPort$path';
    return Uri.parse(url);
  }

  static const Duration timeout = Duration(seconds: 30);
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class RateLimitException implements Exception {
  final int retryAfterSeconds;
  const RateLimitException(this.retryAfterSeconds);
}

class NetworkException implements Exception {
  final String message;
  final bool isOffline;
  const NetworkException(this.message, {this.isOffline = false});
  @override
  String toString() => message;
}

class _Client {
  static Future<Map<String, String>> _headers() async {
    final token = await TokenStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String path) async {
    try {
      final resp = await http.get(_Config.uri(path), headers: await _headers()).timeout(_Config.timeout);
      return _parse(resp);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const NetworkException('Request timed out.', isOffline: true);
    } catch (e) {
      throw NetworkException(e.toString(), isOffline: true);
    }
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http.post(_Config.uri(path), headers: await _headers(), body: jsonEncode(body)).timeout(_Config.timeout);
      return _parse(resp);
    } catch (e) {
      throw NetworkException(e.toString(), isOffline: true);
    }
  }

  static Future<dynamic> postAnonymous(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http.post(_Config.uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body)).timeout(_Config.timeout);
      return _parse(resp);
    } catch (e) {
      throw NetworkException(e.toString());
    }
  }

  static Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http.patch(_Config.uri(path), headers: await _headers(), body: jsonEncode(body)).timeout(_Config.timeout);
      return _parse(resp);
    } catch (e) {
      throw NetworkException(e.toString(), isOffline: true);
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final resp = await http.delete(_Config.uri(path), headers: await _headers()).timeout(_Config.timeout);
      return _parse(resp);
    } catch (e) {
      throw NetworkException(e.toString(), isOffline: true);
    }
  }

  static dynamic _parse(http.Response resp) {
    switch (resp.statusCode) {
      case 200:
      case 201:
        if (resp.body.isEmpty) return null;
        return jsonDecode(resp.body);
      case 422:
        final body = jsonDecode(resp.body);
        throw ApiException(422, body['message'] ?? 'Validation error');
      case 429:
        final retryAfter = int.tryParse(resp.headers['retry-after'] ?? '60') ?? 60;
        throw RateLimitException(retryAfter);
      case 503:
        throw const ApiException(503, 'Service unavailable');
      default:
        String msg = 'HTTP ${resp.statusCode}';
        try {
          final body = jsonDecode(resp.body);
          msg = body['message'] ?? body['error'] ?? msg;
        } catch (_) {}
        throw ApiException(resp.statusCode, msg);
    }
  }
}

class DashboardMetricsDto {
  final Map<String, dynamic> kpis;
  final List<dynamic> activityLogs;
  final List<dynamic> purchases;
  final List<dynamic> salesData;
  final List<double> dailyRevenue;
  final List<dynamic> pendingPrescriptions; 
  final int robotIssues;
  final List<dynamic> lowStockItems;
  final List<dynamic> expiringItems;
  final List<dynamic> frequentItems;

  DashboardMetricsDto.fromJson(Map<String, dynamic> j)
    : kpis = j['kpis'] is Map ? j['kpis'] : <String, dynamic>{},
      
      // 🌟 FULLY BULLETPROOF LIST CASTING (Prevents Type Null crashes completely)
      activityLogs = j['activityLogs'] is List ? List<dynamic>.from(j['activityLogs']) : [],
      purchases = j['purchases'] is List ? List<dynamic>.from(j['purchases']) : [],
      salesData = j['salesData'] is List ? List<dynamic>.from(j['salesData']) : [],
      dailyRevenue = j['dailyRevenue'] is List 
          ? (j['dailyRevenue'] as List).map((e) => (e as num).toDouble()).toList() 
          : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      pendingPrescriptions = j['pendingPrescriptions'] is List ? List<dynamic>.from(j['pendingPrescriptions']) : [],
      robotIssues = int.tryParse(j['kpis']?['robotIssues']?.toString() ?? '0') ?? 0,
      lowStockItems = j['lowStockItems'] is List ? List<dynamic>.from(j['lowStockItems']) : [],
      expiringItems = j['expiringItems'] is List ? List<dynamic>.from(j['expiringItems']) : [],
      frequentItems = j['frequentItems'] is List ? List<dynamic>.from(j['frequentItems']) : []; 
}

class AnalyticsDto {
  final double totalRevenue, totalProfit, wasteValue;
  final int unitsDispensed;
  final List<dynamic> topMedicines, topSuppliers, expiryRisk, mostPrescribed;

  AnalyticsDto.fromJson(Map<String, dynamic> j)
    : totalRevenue = (j['totalRevenue'] ?? 0).toDouble(),
      totalProfit = (j['totalProfit'] ?? 0).toDouble(),
      unitsDispensed = j['unitsDispensed'] ?? 0,
      wasteValue = (j['wasteValue'] ?? 0).toDouble(),
      topMedicines = j['topMedicines'] is List ? List<dynamic>.from(j['topMedicines']) : [],
      topSuppliers = j['topSuppliers'] is List ? List<dynamic>.from(j['topSuppliers']) : [],
      expiryRisk = j['expiryRisk'] is List ? List<dynamic>.from(j['expiryRisk']) : [],
      mostPrescribed = j['mostPrescribed'] is List ? List<dynamic>.from(j['mostPrescribed']) : [];
}

class ApiService {
  static final ocr = OcrApi();
  static final gAi = PythonDashboardApi();
  static final auth = _AuthApi();
  static final medicines = _MedicinesApi();
  static final invoices = _InvoicesApi();
  static final prescriptions = _PrescriptionsApi();
  static final robot = _RobotApi();
  static final reports = _ReportsApi();
  final String baseUrl = 'http://localhost:4000';
  static final shifts = _ShiftsApi();

  static void setGatewayHost(String host) => _Config.gatewayHost = host;
  static String get gatewayHost => _Config.gatewayHost;

  static Future<List<dynamic>> getPendingPrescriptions() async {
    try {
      final response = await _Client.get('/api/prescriptions?status=PENDING');
      
      if (response == null) return [];
      if (response is List) return response;
      if (response is Map && response['data'] is List) {
        return List<dynamic>.from(response['data']); 
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  static Future<String> testGatewayConnection() async {
    try {
      final uri = _Config.uri('/api/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) return 'Gateway is reachable and responding.';
      if (resp.statusCode == 404) {
        try {
          final testResp = await http
              .get(
                _Config.uri('/api/medicines'),
                headers: {'Authorization': 'Bearer test'},
              )
              .timeout(const Duration(seconds: 5));
          if (testResp.statusCode >= 200 && testResp.statusCode < 500)
            return 'Gateway is reachable at ${_Config.gatewayHost}:${_Config.gatewayPort}';
        } catch (_) {}
        throw const NetworkException(
          'Gateway not reachable. Verify host and port.',
          isOffline: true,
        );
      }
      throw NetworkException(
        'Gateway returned status ${resp.statusCode}. Is it running?',
        isOffline: true,
      );
    } on TimeoutException {
      throw const NetworkException(
        'Connection timed out. Gateway may be down.',
        isOffline: true,
      );
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw NetworkException('Failed to connect: $e', isOffline: true);
    }
  }
  // Add these inside your ApiService class

  Future<Map<String, dynamic>> fetchAiOverview() async {
    final response = await http.get(Uri.parse('$baseUrl/api/ai/overview'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load AI overview stats');
    }
  }

  Future<Map<String, dynamic>> fetchExpiryRisk() async {
    final response = await http.get(Uri.parse('$baseUrl/api/ai/expiry-risk'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load AI expiry risk');
    }
  }

  Future<Map<String, dynamic>> fetchSmartReorder() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ai/smart-reorder'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load smart reorder points');
    }
  }
}

class _ReportsApi {
  Future<DashboardMetricsDto> getDashboardMetrics() async {
    final json = await _Client.get('/api/reports/dashboard');
    return DashboardMetricsDto.fromJson(json as Map<String, dynamic>? ?? {});
  }

  Future<AnalyticsDto> getAnalytics() async {
    final json = await _Client.get('/api/reports/analytics');
    return AnalyticsDto.fromJson(json as Map<String, dynamic>? ?? {});
  }
}

class OcrApi {
  static const String _ocrBaseUrl = 'http://127.0.0.1:5001';

  Future<List<dynamic>> extractMedicines(String imagePath) async {
    final uri = Uri.parse('$_ocrBaseUrl/upload'); 
    final request = http.MultipartRequest('POST', uri);
    request.headers['ngrok-skip-browser-warning'] = 'true';
    request.files.add(await http.MultipartFile.fromPath('file', imagePath));
    final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      dynamic data = jsonDecode(response.body);
      if (data is String) data = jsonDecode(data);
      if (data['medicine_names'] is List) return List<dynamic>.from(data['medicine_names']);
      return [];
    } else {
      throw ApiException(response.statusCode, 'AI Server error: ${response.statusCode}');
    }
  }
}




class LoginResponse {
  final String token;
  final int userId;
  final String name;
  final String email;
  final String role;

  const LoginResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>;
    return LoginResponse(
      token: j['token'] as String,
      userId: (u['user_id'] as num).toInt(),
      name: u['full_name'] as String,
      email: u['email'] as String,
      role: u['role'] as String,
    );
  }
}

class MedicineDto {
  final int id;
  final String barcode;
  final String? serialNumber;
  final String tradeName;
  final String activeSubstance;
  final int? companyId;
  final String companyName;
  final int quantityOnHand;
  final int reorderLevel;
  final int maxStock;
  final double unitCost;
  final double payRate;
  final double discountPct;
  final String expirationDate;
  final int daysToExpiry;
  final String? storageLocation;
  final bool requiresRefrigeration;
  final bool isArchived;

  const MedicineDto({
    required this.id,
    required this.barcode,
    this.serialNumber,
    required this.tradeName,
    required this.activeSubstance,
    this.companyId,
    required this.companyName,
    required this.quantityOnHand,
    required this.reorderLevel,
    required this.maxStock,
    required this.unitCost,
    required this.payRate,
    required this.discountPct,
    required this.expirationDate,
    required this.daysToExpiry,
    this.storageLocation,
    required this.requiresRefrigeration,
    required this.isArchived,
  });

  factory MedicineDto.fromJson(Map<String, dynamic> j) {
    final companyIdValue = j['company_id'];
    return MedicineDto(
      id: j['medicine_id'] as int? ?? 0,
      barcode: j['barcode'] as String? ?? '',
      serialNumber: j['serial_number'] as String?,
      tradeName: j['trade_name'] as String? ?? '',
      activeSubstance: j['active_substance'] as String? ?? '',
      companyId: companyIdValue == null
          ? null
          : int.tryParse(companyIdValue.toString()),
      companyName:
          j['company_name'] as String? ??
          j['company']?['name'] as String? ??
          '',
      quantityOnHand:
          int.tryParse(j['quantity_on_hand']?.toString() ?? '0') ?? 0,
      reorderLevel: int.tryParse(j['reorder_level']?.toString() ?? '10') ?? 10,
      maxStock: int.tryParse(j['max_stock']?.toString() ?? '100') ?? 100,
      unitCost: double.tryParse(j['unit_cost']?.toString() ?? '0') ?? 0.0,
      payRate: double.tryParse(j['pay_rate']?.toString() ?? '0') ?? 0.0,
      discountPct: double.tryParse(j['discount_pct']?.toString() ?? '0') ?? 0.0,
      expirationDate: j['expiration_date'] as String? ?? '',
      daysToExpiry: int.tryParse(j['days_to_expiry']?.toString() ?? '0') ?? 0,
      storageLocation: j['storage_location'] as String?,
      requiresRefrigeration: j['requires_refrigeration'] as bool? ?? false,
      isArchived: j['is_archived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'serial_number': serialNumber,
    'trade_name': tradeName,
    'active_substance': activeSubstance,
    'company_id': companyId,
    'company_name': companyName,
    'quantity_on_hand': quantityOnHand,
    'reorder_level': reorderLevel,
    'max_stock': maxStock,
    'unit_cost': unitCost,
    'pay_rate': payRate,
    'discount_pct': discountPct,
    'expiration_date': expirationDate,
    'storage_location': storageLocation,
    'requires_refrigeration': requiresRefrigeration,
  };

  double get profitMarginPct =>
      payRate > 0 ? ((payRate - unitCost) / payRate) * 100 : 0;
}

class MedicineListResponse {
  final List<MedicineDto> items;
  final int total;
  const MedicineListResponse({required this.items, required this.total});
}

class InvoiceDto {
  final int id;
  final String fatooraNumber, companyName, invoiceDate, paymentStatus;
  final double totalAmount, totalDiscount, netPayable;
  final String? paymentDueDate, notes;
  final List<dynamic> items; // <-- ADD THIS

  const InvoiceDto({
    required this.id,
    required this.fatooraNumber,
    required this.companyName,
    required this.invoiceDate,
    required this.totalAmount,
    required this.totalDiscount,
    required this.netPayable,
    required this.paymentStatus,
    this.paymentDueDate,
    this.notes,
    required this.items, // <-- ADD THIS
  });

  factory InvoiceDto.fromJson(Map<String, dynamic> j) => InvoiceDto(
    id: j['invoice_id'] as int,
    fatooraNumber: j['fatoora_number'] as String,
    companyName: j['company']?['name'] as String? ?? '',
    invoiceDate: j['invoice_date'] as String,
    totalAmount: double.tryParse(j['total_amount']?.toString() ?? '0') ?? 0.0,
    totalDiscount:
        double.tryParse(j['total_discount']?.toString() ?? '0') ?? 0.0,
    netPayable: double.tryParse(j['net_payable']?.toString() ?? '0') ?? 0.0,
    paymentStatus: j['payment_status'] as String,
    paymentDueDate: j['payment_due_date'] as String?,
    notes: j['notes'] as String?,
    items: j['items'] as List? ?? [], // <-- ADD THIS
  );
}

class PrescriptionDto {
  final int id;
  final String? roshettaCode, patientName, doctorName;
  final String status, createdAt;
  final List<PrescriptionItemDto> items;

  const PrescriptionDto({
    required this.id,
    this.roshettaCode,
    this.patientName,
    this.doctorName,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory PrescriptionDto.fromJson(Map<String, dynamic> j) => PrescriptionDto(
    id: j['prescription_id'] as int,
    roshettaCode: j['roshetta_code'] as String?,
    patientName: j['patient_name'] as String?,
    doctorName: j['doctor_name'] as String?,
    status: j['status'] as String,
    createdAt: j['created_at'] as String,
    items: (j['items'] as List? ?? [])
        .map((i) => PrescriptionItemDto.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}

class PrescriptionItemDto {
  final int id, medicineId, quantityPrescribed, quantityDispensed;
  final String tradeName, status, requestedName;

  const PrescriptionItemDto({
    required this.id,
    required this.medicineId,
    required this.tradeName,
    required this.quantityPrescribed,
    required this.quantityDispensed,
    required this.status,
    required this.requestedName,
  });

  factory PrescriptionItemDto.fromJson(Map<String, dynamic> j) =>
      PrescriptionItemDto(
        id: j['pitem_id'] as int? ?? j['item_id'] as int? ?? 0,
        medicineId: j['medicine_id'] as int? ?? 0,
        tradeName: j['medicine']?['trade_name'] as String? ?? '',
        requestedName: j['requested_name'] as String? ?? '',
        quantityPrescribed:
            int.tryParse(j['quantity_prescribed']?.toString() ?? '0') ?? 0,
        quantityDispensed:
            int.tryParse(j['quantity_dispensed']?.toString() ?? '0') ?? 0,
        status: j['status'] as String? ?? 'PENDING',
      );
}

class RobotJobDto {
  final String jobId, status;
  final int? prescriptionId;
  final List<Map<String, dynamic>> pickSequence;
  final List<Map<String, dynamic>> ackLog;
  final String? startedAt, completedAt;

  const RobotJobDto({
    required this.jobId,
    this.prescriptionId,
    required this.status,
    required this.pickSequence,
    required this.ackLog,
    this.startedAt,
    this.completedAt,
  });

  factory RobotJobDto.fromJson(Map<String, dynamic> j) => RobotJobDto(
    jobId: j['job_id'] as String,
    prescriptionId: j['prescription_id'] as int?,
    status: j['status'] as String,
    pickSequence: (j['pick_sequence'] as List).cast<Map<String, dynamic>>(),
    ackLog: (j['ack_log'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    startedAt: j['started_at'] as String?,
    completedAt: j['completed_at'] as String?,
  );
}

class AiQueryResponse {
  final String sql, answer;
  final List<String> columns;
  final List<List<String>> rows;
  final List<AiHighlight> highlights;
  final bool fromCache;
  final int rateLimitRemaining;

  const AiQueryResponse({
    required this.sql,
    required this.columns,
    required this.rows,
    required this.answer,
    required this.highlights,
    required this.fromCache,
    required this.rateLimitRemaining,
  });

  factory AiQueryResponse.fromJson(Map<String, dynamic> j, int remaining) =>
      AiQueryResponse(
        sql: j['sql'] as String,
        columns: (j['columns'] as List).cast<String>(),
        rows: (j['rows'] as List)
            .map((r) => (r as List).map((v) => v.toString()).toList())
            .toList(),
        answer: j['answer'] as String,
        highlights: (j['highlights'] as List? ?? [])
            .map((h) => AiHighlight.fromJson(h as Map<String, dynamic>))
            .toList(),
        fromCache: j['from_cache'] as bool? ?? false,
        rateLimitRemaining: remaining,
      );
}

class AiHighlight {
  final String text, type;
  const AiHighlight({required this.text, required this.type});
  factory AiHighlight.fromJson(Map<String, dynamic> j) =>
      AiHighlight(text: j['text'] as String, type: j['type'] as String);
}

class _AuthApi {
  Future<LoginResponse> login({
    required String email,
    required String password,
    required String role,
    required String deviceId,
  }) async {
    final json = await _Client.postAnonymous('/api/auth/login', {
      'email': email,
      'password': password,
      'role': role,
      'device_id': deviceId,
    });
    return LoginResponse.fromJson(json as Map<String, dynamic>);
  }

  // FIX: Added the missing register connection
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    await _Client.post('/api/auth/register', {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': role,
    });
  }

  Future<void> logout() async {
    try {
      await _Client.post('/api/auth/logout', {});
    } catch (_) {}
    await TokenStore.clearSession();
  }
}

class _MedicinesApi {
  Future<MedicineListResponse> getAll({
    String? query,
    String? filter,
    String sort = 'trade_name',
    String order = 'asc',
    int page = 1,
    int limit = 50,
  }) async {
    final params = {
      if (query != null && query.isNotEmpty) 'q': query,
      if (filter != null && filter.isNotEmpty) 'filter': filter,
      'sort': sort,
      'order': order,
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final uri = Uri.parse(
      'http://${_Config.gatewayHost}:${_Config.gatewayPort}/api/medicines',
    ).replace(queryParameters: params);
    final headers = await _authHeaders();
    final resp = await http.get(uri, headers: headers).timeout(_Config.timeout);
    final json = _Client._parse(resp) as Map<String, dynamic>;
    return MedicineListResponse(
      items: (json['data'] as List)
          .map((m) => MedicineDto.fromJson(m as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }

  Future<MedicineDto> getById(int id) async {
    final json = await _Client.get('/api/medicines/$id');
    return MedicineDto.fromJson(json as Map<String, dynamic>);
  }

  Future<MedicineDto> create(Map<String, dynamic> data) async {
    final json = await _Client.post('/api/medicines', data);
    return MedicineDto.fromJson(json as Map<String, dynamic>);
  }

  Future<MedicineDto> update(int id, Map<String, dynamic> data) async {
    final json = await _Client.patch('/api/medicines/$id', data);
    return MedicineDto.fromJson(json as Map<String, dynamic>);
  }

  Future<void> adjustStock(int id, int delta) async {
    await _Client.post('/api/medicines/$id/adjust-stock', {'delta': delta});
  }

  Future<List<MedicineDto>> getExpiryAlerts({int days = 30}) async {
    final json = await _Client.get('/api/medicines/expiry-alerts?days=$days');
    return (json as List)
        .map((m) => MedicineDto.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> archive(int id) async {
    await _Client.delete('/api/medicines/$id');
  }

  Future<void> cleanUnknown() async {
    await _Client.delete('/api/medicines/bulk/unknown');
  }

  Future<void> deleteMedicine(int id) async {
    await _Client.delete('/api/medicines/$id');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStore.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> importExcel(List<int> fileBytes, String filename) async {
    final uri = Uri.parse(
      'http://${_Config.gatewayHost}:${_Config.gatewayPort}/api/medicines/import',
    );
    final headers = await _authHeaders();

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    final streamedResponse = await request.send().timeout(_Config.timeout);
    final resp = await http.Response.fromStream(streamedResponse);
    _Client._parse(resp); // Uses your excellent existing error handler!
  }
}

class _InvoicesApi {
  Future<List<InvoiceDto>> getAll({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final q = [
      if (status != null) 'status=$status',
      'page=$page',
      'limit=$limit',
    ].join('&');
    final json = await _Client.get('/api/invoices?$q');
    final list = (json as Map<String, dynamic>)['data'] as List;
    return list
        .map((i) => InvoiceDto.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<InvoiceDto> getById(int id) async {
    final json = await _Client.get('/api/invoices/$id');
    return InvoiceDto.fromJson(json as Map<String, dynamic>);
  }

  Future<InvoiceDto> create(Map<String, dynamic> data) async {
    final json = await _Client.post('/api/invoices', data);
    return InvoiceDto.fromJson(json as Map<String, dynamic>);
  }

  // FIX: Permanently updates the invoice status via the backend
  Future<void> updatePaymentStatus(int id, String status) async {
    await _Client.patch('/api/invoices/$id/payment-status', {
      'payment_status': status,
    });
  }

  Future<void> delete(int id) async =>
      await _Client.delete('/api/invoices/$id');

  Future<Map<String, dynamic>> importExcel(List<int> fileBytes, String filename, {String? companyName, String? fatooraNumber}) async {
    final uri = Uri.parse(
      'http://${_Config.gatewayHost}:${_Config.gatewayPort}/api/invoices/import-excel',
    );
    final token = await TokenStore.getToken();
    final headers = {
      'Authorization': 'Bearer $token',
    };

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    if (companyName != null && companyName.isNotEmpty) {
      request.fields['company_name'] = companyName;
    }
    if (fatooraNumber != null && fatooraNumber.isNotEmpty) {
      request.fields['fatoora_number'] = fatooraNumber;
    }
    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: filename),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamedResponse);
    return _Client._parse(resp) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadInvoiceImage(String imagePath) async {
    final uri = Uri.parse(
      'http://${_Config.gatewayHost}:${_Config.gatewayPort}/api/invoices/upload-image',
    );
    final token = await TokenStore.getToken();
    final headers = {
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };

    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(headers);
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamedResponse);
    return _Client._parse(resp) as Map<String, dynamic>;
  }
}

class _PrescriptionsApi {
  Future<List<PrescriptionDto>> getAll({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final q = [
      if (status != null) 'status=$status',
      'page=$page',
      'limit=$limit',
    ].join('&');
    final json = await _Client.get('/api/prescriptions?$q');
    final list = (json as Map<String, dynamic>)['data'] as List;
    return list
        .map((p) => PrescriptionDto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PrescriptionDto> getById(int id) async {
    final json = await _Client.get('/api/prescriptions/$id');
    return PrescriptionDto.fromJson(json as Map<String, dynamic>);
  }

  Future<PrescriptionDto> create(Map<String, dynamic> data) async {
    final json = await _Client.post('/api/prescriptions', data);
    return PrescriptionDto.fromJson(json as Map<String, dynamic>);
  }

  Future<void> updateStatus(int id, String status) async {
    await _Client.patch('/api/prescriptions/$id/status', {'status': status});
  }

  Future<void> checkout(int id) async {
    // This hits your new backend logic to deduct stock and calculate revenue!
    await _Client.post('/api/prescriptions/$id/checkout', {});
  }

  Future<void> linkMedicine(int itemId, int medicineId) async {
    await _Client.patch('/api/prescriptions/items/$itemId/link', {
      'medicine_id': medicineId,
    });
  }

  Future<void> delete(int id) async =>
      await _Client.delete('/api/prescriptions/$id');
  Future<void> createOtcSale(List<Map<String, dynamic>> items) async {
    await _Client.post('/api/prescriptions/otc-sale', {'items': items});
  }
}

class _RobotApi {
  Future<RobotJobDto> dispatch(int prescriptionId) async {
    final json = await _Client.post('/api/robot/dispatch', {
      'prescription_id': prescriptionId,
    });
    return RobotJobDto.fromJson(json as Map<String, dynamic>);
  }

  // FIX: Connection for the UI retry button
  Future<void> retryJob(String jobId) async {
    await _Client.post('/api/robot/retry/$jobId', {});
  }

  Future<void> dispatchAdHoc({
    required int medicineId,
    required String name,
    required int qty,
    required String bin,
  }) async {
    await _Client.post('/api/robot/dispatch-adhoc', {
      'medicine_id': medicineId,
      'name': name,
      'qty': qty,
      'bin': bin,
    });
  }

  Future<void> abort(String jobId) async {
    await _Client.post('/api/robot/abort/$jobId', {});
  }

  Future<List<RobotJobDto>> getJobs({String? status, int limit = 20}) async {
    final q = [if (status != null) 'status=$status', 'limit=$limit'].join('&');
    final json = await _Client.get('/api/robot/jobs?$q');
    return (json as List)
        .map((j) => RobotJobDto.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<RobotJobDto> getJob(String jobId) async {
    final json = await _Client.get('/api/robot/jobs/$jobId');
    return RobotJobDto.fromJson(json as Map<String, dynamic>);
  }

  Future<void> deleteJob(String jobId) async =>
      await _Client.delete('/api/robot/jobs/$jobId');
}


class RobotWebSocket {
  WebSocketChannel? _channel;
  final void Function(Map<String, dynamic> event) onEvent;
  final void Function(String error) onError;
  final void Function() onDone;

  RobotWebSocket({
    required this.onEvent,
    required this.onError,
    required this.onDone,
  });

  void connect() {
    final uri = Uri.parse('ws://${_Config.gatewayHost}:${_Config.gatewayPort}');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final json = jsonDecode(raw as String) as Map<String, dynamic>;
          onEvent(json);
        } catch (_) {}
      },
      onError: (e) => onError(e.toString()),
      onDone: () {
        onDone();
        Future.delayed(const Duration(seconds: 3), () {
          if (_channel == null) connect();
        });
      },
      cancelOnError: false,
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  bool get isConnected => _channel != null;
}

class _ShiftsApi {
  // 🌟 دالة تقفيل الشيفت
  Future<Map<String, dynamic>> reconcile(double actualAmount) async {
    final json = await _Client.post('/api/shifts/reconcile', {
      'actualAmount': actualAmount,
    });
    return json as Map<String, dynamic>;
  }

  // 🌟 دالة سحب إحصائيات الشيفت (عشان التقرير ميبقاش وهمي)
  Future<Map<String, dynamic>> getStats() async {
    final json = await _Client.get('/api/shifts/stats');
    return json as Map<String, dynamic>;
  }
}

class PythonDashboardApi {
  // 🌟 Everything is now a pure GET request to the Node Gateway
  Future<Map<String, dynamic>> getOverviewStats() async => await _Client.get('/api/ai/overview');
  Future<Map<String, dynamic>> getSuggestDiscounts() async => await _Client.get('/api/ai/expiry-risk');
  Future<Map<String, dynamic>> getDeadStock() async => await _Client.get('/api/ai/dead-stock');
  Future<Map<String, dynamic>> getDemandForecast() async => await _Client.get('/api/ai/demand');
  Future<Map<String, dynamic>> getSmartReorder() async => await _Client.get('/api/ai/smart-reorder');

  Future<Map<String, dynamic>> getSalesTrend() async => await _Client.get('/api/ai/sales-trend');
  Future<Map<String, dynamic>> getCategoryDistribution() async => await _Client.get('/api/ai/category-distribution');
  Future<Map<String, dynamic>> getSupplierDistribution() async => await _Client.get('/api/ai/supplier-distribution');
  Future<Map<String, dynamic>> getAnomalies() async => await _Client.get('/api/ai/anomalies');
  Future<Map<String, dynamic>> getExpiryTimeline() async => await _Client.get('/api/ai/expiry-timeline');
}