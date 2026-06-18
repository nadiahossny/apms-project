import 'package:flutter/material.dart';
import 'package:roshetety/screens/ocr_screen.dart';
import 'package:roshetety/screens/patient_order_tracking_screen.dart';
import 'package:roshetety/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final bool arabic; 
  const HomeScreen({super.key, required this.arabic});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _manualInputController = TextEditingController();
  late bool _currentArabic;
  bool _isSubmitting = false;
  
  int _manualQuantity = 1; 
  int _selectedIndex = 0; // For bottom nav

  @override
  void initState() {
    super.initState();
    _currentArabic = widget.arabic;
  }

  String _t(String ar, String en) => _currentArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _currentArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F6FF), // Light blue background
        appBar: AppBar(
          backgroundColor: const Color(0xFF5A8DEE),
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.spa_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Roshetty', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Language toggle moved to a smaller button at top right/left
                Align(
                  alignment: _currentArabic ? Alignment.topLeft : Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => setState(() => _currentArabic = !_currentArabic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF5A8DEE).withOpacity(0.3)),
                      ),
                      child: Text(_currentArabic ? 'English' : 'عربي', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A8DEE), fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- Action Section: Manual Request ---
                _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Keep text field for integration but style it nicely
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F9FF),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: TextField(
                            controller: _manualInputController,
                            decoration: InputDecoration(
                              hintText: _t('اسم الدواء...', 'Medicine name...'),
                              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.medication_outlined, color: Color(0xFF5A8DEE)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // --- Quantity Selector UI ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_t('الكمية', 'Quantity'), 
                              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4B5563), fontSize: 16)),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F9FF),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Color(0xFF5A8DEE), size: 20),
                                    onPressed: () {
                                      if (_manualQuantity > 1) {
                                        setState(() => _manualQuantity--);
                                      }
                                    },
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('$_manualQuantity', 
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Color(0xFF5A8DEE), size: 20),
                                    onPressed: () => setState(() => _manualQuantity++),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildActionPill(
                          label: _t('إرسال للصيدلية', 'Send to Pharmacy'),
                          onTap: _submitManualOrder,
                          isLoading: _isSubmitting,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // --- Action Section: OCR Scan ---
                _sectionHeader(_t('مسح الروشتة', 'Scan Prescription')),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => OcrScreen(arabic: _currentArabic))
                  ),
                  child: _buildCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F9FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.document_scanner_outlined, size: 40, color: Color(0xFF5A8DEE)),
                            ),
                            const SizedBox(height: 16),
                            Text(_t('فتح الكاميرا', 'Open Camera'), 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // --- Action Section: Track Order ---
                _sectionHeader(_t('تتبع الطلب', 'Track Order')),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showTrackOrderDialog,
                  child: _buildCard(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F9FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.power_settings_new_rounded, size: 40, color: Color(0xFF5A8DEE)),
                            ),
                            const SizedBox(height: 16),
                            Text(_t('تتبع طلبك الحالي', 'Track your current order'), 
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF5A8DEE),
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => OcrScreen(arabic: _currentArabic))
              );
            } else if (index == 1) {
              _showTrackOrderDialog();
            }
          },
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.document_scanner_rounded), label: _t('تقديم الروشتة', 'Submit Prescription')),
            BottomNavigationBarItem(icon: const Icon(Icons.local_shipping_rounded), label: _t('تتبع الطلب', 'Track Order')),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _sectionHeader(String text) => Text(text, 
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)));

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5A8DEE).withOpacity(0.08), 
            blurRadius: 24, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: child,
    );
  }

  Widget _buildActionPill({required String label, required VoidCallback onTap, required bool isLoading}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF5A8DEE),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A8DEE).withOpacity(0.3), 
              blurRadius: 12, 
              offset: const Offset(0, 6)
            )
          ],
        ),
        child: Center(
          child: isLoading 
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _submitManualOrder() async {
    final text = _manualInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      // Send the medicine name and the selected quantity
      final orderId = await RoshettyApi.placeOrder(
        cartItems: [{
          'requested': text, 
          'quantity': _manualQuantity 
        }]
      );
      
      if (!mounted) return;
      _manualInputController.clear();
      setState(() => _manualQuantity = 1); 
      
      if (orderId != null) {
        _showOrderSuccessDialog(orderId);
      } else {
        _showCustomToast(_t('تم الإرسال بنجاح', 'Sent successfully'));
      }
    } catch (e) {
      _showCustomToast(_t('فشل الإرسال: ${e.toString()}', 'Failed to send: ${e.toString()}'), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showOrderSuccessDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: _currentArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(_t('تم الإرسال بنجاح!', 'Order Sent Successfully!'), style: const TextStyle(color: Color(0xFF5A8DEE), fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_t('يرجى الاحتفاظ برقم الطلب لتتبعه:', 'Please keep this Order ID to track it:'), textAlign: TextAlign.center),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('حسناً', 'OK'), style: const TextStyle(color: Color(0xFF5A8DEE))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8DEE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PatientOrderTrackingScreen(prescriptionId: orderId),
                    ),
                  );
                },
                child: Text(_t('تتبع الآن', 'Track Now'), style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }

  void _showCustomToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF8AB6F9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showTrackOrderDialog() {
    final TextEditingController trackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: _currentArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(_t('تتبع الطلب', 'Track Order'), style: const TextStyle(color: Color(0xFF5A8DEE), fontWeight: FontWeight.bold)),
            content: TextField(
              controller: trackController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: _t('أدخل رقم الطلب', 'Enter Order ID'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF5A8DEE), width: 2),
                  borderRadius: BorderRadius.circular(15)
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('إلغاء', 'Cancel'), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A8DEE),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final text = trackController.text.trim();
                  if (text.isNotEmpty) {
                    final id = int.tryParse(text);
                    if (id != null) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientOrderTrackingScreen(prescriptionId: id),
                        ),
                      );
                    }
                  }
                },
                child: Text(_t('تتبع', 'Track'), style: const TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      }
    );
  }
}