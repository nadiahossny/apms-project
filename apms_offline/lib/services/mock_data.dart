
class MockData {
  static const bool isDemoMode = true;
  static List<String> deletedJobs = [];
  static Map<int, int> linkedItems = {};
  static List<Map<String, dynamic>> customMedicines = [];
  static Map<int, Map<String, dynamic>> editedMedicines = {};
  static List<Map<String, dynamic>> activeJobs = [
    {
      'job_id': 'job-001',
      'status': 'COMPLETED',
      'pick_sequence': [],
      'ack_log': []
    }
  ];

  static void handleDelete(String path) {
    if (path.contains('/api/robot/jobs/')) {
      final jobId = path.split('/').last;
      deletedJobs.add(jobId);
    }
  }

  static dynamic handleGet(String path) {
    if (path.contains('/api/health')) {
      return {'status': 'ok'};
    }
    if (path.contains('/api/prescriptions')) {
      return {
        'data': [
          {
            'prescription_id': 101,
            'patient_name': 'Ahmed Ali',
            'status': 'PENDING',
            'created_at': DateTime.now().toIso8601String(),
            'items': [
              {
                'item_id': 1,
                'medicine_id': linkedItems[1],
                'requested_name': 'Panadol',
                'quantity_prescribed': 2,
                'status': linkedItems.containsKey(1) ? 'LINKED' : 'PENDING'
              }
            ]
          }
        ]
      };
    }
    if (path.contains('/api/medicines')) {
      var initialData = [
          {'medicine_id': 1, 'trade_name': 'Panadol Advance', 'active_substance': 'Paracetamol', 'quantity_on_hand': 50, 'unit_cost': 20.0, 'pay_rate': 25.0},
          {'medicine_id': 2, 'trade_name': 'Augmentin 1g', 'active_substance': 'Amoxicillin', 'quantity_on_hand': 15, 'unit_cost': 80.0, 'pay_rate': 100.0},
          {'medicine_id': 3, 'trade_name': 'Concor 5mg', 'active_substance': 'Bisoprolol', 'quantity_on_hand': 30, 'unit_cost': 35.0, 'pay_rate': 45.0},
          ...customMedicines
      ];
      final finalData = initialData.map((m) {
        final id = m['medicine_id'] as int;
        return editedMedicines.containsKey(id) ? {...m, ...editedMedicines[id]!} : m;
      }).toList();

      final match = RegExp(r'/api/medicines/(\d+)$').firstMatch(path);
      if (match != null) {
        final id = int.tryParse(match.group(1)!) ?? 1;
        return finalData.firstWhere((m) => m['medicine_id'] == id, orElse: () => finalData.first);
      }

      return {
        'data': finalData,
        'total': finalData.length
      };
    }
    if (path.contains('/api/invoices')) {
      return {
        'data': [
          {
            'invoice_id': 1,
            'fatoora_number': 'INV-2026-001',
            'total_amount': 1500.0,
            'payment_status': 'PAID',
            'invoice_date': DateTime.now().toIso8601String(),
          }
        ]
      };
    }
    if (path.contains('/api/reports/dashboard')) {
      return {
        'kpis': {
          'totalRevenue': 5400.50,
          'ordersCompleted': 120,
          'robotIssues': 0,
          'activePatients': 45
        },
        'activityLogs': [],
        'purchases': [],
        'salesData': [],
        'dailyRevenue': [100.0, 200.0, 300.0, 400.0, 500.0, 600.0],
        'pendingPrescriptions': [],
        'lowStockItems': [],
        'expiringItems': [],
        'frequentItems': []
      };
    }
    if (path.contains('/api/ai/sales-trend')) {
      return {
        'months': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
        'values': [4000, 4200, 4100, 4800, 5200, 6000]
      };
    }
    if (path.contains('/api/ai/category-distribution')) {
      return {
        'categories': ['Painkillers', 'Antibiotics', 'Vitamins', 'Cardio', 'Others'],
        'values': [35, 25, 20, 10, 10]
      };
    }
    if (path.contains('/api/ai/supplier-distribution')) {
      return {
        'suppliers': ['Pfizer', 'Novartis', 'GSK', 'Local Pharma', 'Sanofi'],
        'values': [30, 25, 20, 15, 10]
      };
    }
    if (path.contains('/api/ai/demand')) {
      return {
        'forecast_total': 1250,
        'top_demanded': [
          {'name': 'Panadol', 'units': 500},
          {'name': 'Augmentin', 'units': 300},
          {'name': 'Concor', 'units': 250},
          {'name': 'Vitamin C', 'units': 150},
          {'name': 'Omega 3', 'units': 50},
        ]
      };
    }
    if (path.contains('/api/ai/smart-reorder')) {
      return {
        'reorder_products': [
          {'product': 'Panadol Advance', 'current_stock': 12, 'avg_monthly': 300, 'days_left': 2, 'reorder_point': 100},
          {'product': 'Augmentin 1g', 'current_stock': 5, 'avg_monthly': 150, 'days_left': 1, 'reorder_point': 50},
        ]
      };
    }
    if (path.contains('/api/ai/expiry-timeline')) {
      return {
        'months': ['Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
        'values': [100, 50, 200, 300, 150, 0]
      };
    }
    if (path.contains('/api/ai/expiry-risk')) {
      return {
        'expired_list': [
          {'Product Name': 'Old Medicine A', 'Total Inventory Value': 500}
        ],
        'expiring_list': [
          {'Product Name': 'Near Expiry B', 'Days': 15, 'Lost_Value': 200}
        ],
        'promo_products': [
          {'Product Name': 'Near Expiry B', 'Days': 15, 'discount': 25}
        ]
      };
    }
    if (path.contains('/api/ai/dead-stock')) {
      return {
        'data': [
          {'Product Name': 'Obscure Cream', 'Category': 'Skincare', 'Quantity': 10, 'Stock_Value': 1500}
        ]
      };
    }
    if (path.contains('/api/ai/anomalies')) {
      return {
        'anomalies': [
          {'Shift_Name': 'Morning Shift A', 'Start Date': '2026-06-18', 'Difference': -350.5},
          {'Shift_Name': 'Night Shift B', 'Start Date': '2026-06-17', 'Difference': 12.0}
        ]
      };
    }
    if (path.contains('/api/reports/analytics')) {
      return {
        'totalRevenue': 150000.0,
        'totalProfit': 45000.0,
        'wasteValue': 1200.0,
        'unitsDispensed': 8500,
        'topMedicines': [],
        'topSuppliers': [],
        'expiryRisk': [],
        'mostPrescribed': []
      };
    }
    if (path.contains('/api/robot/jobs')) {
      return activeJobs.where((j) => !deletedJobs.contains(j['job_id'])).toList();
    }
    if (path.contains('/api/robot/status') || path.contains('/api/robot')) {
      return {
        'status': 'IDLE',
        'battery': '98%',
        'current_task': 'None',
        'last_maintenance': '2026-06-01'
      };
    }
    return {};
  }

  static dynamic handlePost(String path, Map<String, dynamic> body) {
    if (path.contains('/api/auth/login')) {
      return {
        'token': 'fake_demo_token',
        'user': {'user_id': 1, 'full_name': 'Demo Manager', 'email': 'manager@pharma.eg', 'role': 'manager'}
      };
    }
    if (path.contains('/api/robot/dispatch') || path.contains('/api/robot/dispatch-adhoc')) {
      final newJob = {
        'job_id': 'job-demo-${100 + activeJobs.length}',
        'status': 'PENDING',
        'pick_sequence': [
           {'medicine_id': body['medicine_id'] ?? 1, 'medicine_name': body['name'] ?? 'Medicine', 'qty': body['qty'] ?? 1, 'bin': body['bin'] ?? 'A-1', 'status': 'PENDING'}
        ],
        'ack_log': []
      };
      activeJobs.add(newJob);
      return newJob;
    }
    if (path.contains('/api/prescriptions/items/') && path.contains('/link')) {
      final parts = path.split('/');
      final itemIdStr = parts[parts.length - 2];
      final itemId = int.tryParse(itemIdStr) ?? 1;
      linkedItems[itemId] = body['medicine_id'] ?? 1;
      return {'success': true, 'message': 'Linked'};
    }
    if (path.contains('/api/medicines') && !path.contains('/bulk')) {
      final isUpdate = RegExp(r'/api/medicines/\d+$').hasMatch(path);
      if (isUpdate) {
        final idStr = path.split('/').last;
        final id = int.tryParse(idStr) ?? 1;
        editedMedicines[id] = {...(editedMedicines[id] ?? {}), ...body};
        
        Map<String, dynamic> base = {};
        if (id == 1) base = {'medicine_id': 1, 'trade_name': 'Panadol Advance', 'active_substance': 'Paracetamol', 'quantity_on_hand': 50, 'unit_cost': 20.0, 'pay_rate': 25.0};
        else if (id == 2) base = {'medicine_id': 2, 'trade_name': 'Augmentin 1g', 'active_substance': 'Amoxicillin', 'quantity_on_hand': 15, 'unit_cost': 80.0, 'pay_rate': 100.0};
        else if (id == 3) base = {'medicine_id': 3, 'trade_name': 'Concor 5mg', 'active_substance': 'Bisoprolol', 'quantity_on_hand': 30, 'unit_cost': 35.0, 'pay_rate': 45.0};
        else base = customMedicines.firstWhere((m) => m['medicine_id'] == id, orElse: () => {'medicine_id': id});

        return {...base, ...editedMedicines[id]!};
      } else {
        final newMed = {
          'medicine_id': 999 + customMedicines.length,
          'trade_name': body['trade_name'] ?? 'Mock Med',
          'barcode': body['barcode'] ?? '000',
          'active_substance': body['active_substance'] ?? '',
          'company_name': body['company_name'] ?? '',
          'quantity_on_hand': int.tryParse(body['quantity_on_hand']?.toString() ?? '10') ?? 10,
          'unit_cost': double.tryParse(body['unit_cost']?.toString() ?? '10') ?? 10.0,
          'pay_rate': double.tryParse(body['pay_rate']?.toString() ?? '20') ?? 20.0,
        };
        customMedicines.add(newMed);
        return newMed;
      }
    }
    // Return a generic success for all other posts (like changing status, creating invoice, etc)
    return {'success': true, 'message': 'Operation successful in Demo Mode'};
  }
}
