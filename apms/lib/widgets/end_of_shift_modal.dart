import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart'; 

void showEndOfShiftModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: AC.ink900.withOpacity(0.4),
    builder: (context) => const _EndOfShiftDialog(),
  );
}

class _EndOfShiftDialog extends StatefulWidget {
  const _EndOfShiftDialog(); 

  @override
  State<_EndOfShiftDialog> createState() => _EndOfShiftDialogState();
}

class _EndOfShiftDialogState extends State<_EndOfShiftDialog> {
  final _cashCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingStats = true;

  // أرقام وهمية مؤقتة لحد ما نربطها بـ API بيجيب إحصائيات الشيفت الفعلي
  int _rxCount = 0;
  int _otcCount = 0;

  @override
  void initState() {
    super.initState();
    _loadShiftStats();
  }

  // 🌟 سحب الإحصائيات الحقيقية من السيرفر
  Future<void> _loadShiftStats() async {
    try {
      final stats = await ApiService.shifts.getStats();
      if (mounted) {
        setState(() {
          _rxCount = stats['rx_count'] ?? 0;
          _otcCount = stats['otc_count'] ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load shift stats'), backgroundColor: AC.redFg)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.white,
          borderRadius: AR.r14,
          border: Border.all(color: AC.blueXlt, width: 3), 
          boxShadow: [
            BoxShadow(color: AC.blue500.withOpacity(0.15), blurRadius: 30, spreadRadius: 5)
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 Header
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AC.blueXlt, shape: BoxShape.circle),
              child: const Icon(Icons.wb_twilight_rounded, color: AC.blue500, size: 32),
            ),
            const SizedBox(height: 20),
            
            const Text('Great work today!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.ink900)),
            const SizedBox(height: 8),
            const Text(
              'Your shift is almost over. Here is a quick summary of what you accomplished.', 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 13, color: AC.ink400, height: 1.5)
            ),
            const SizedBox(height: 24),

            // 🌟 Shift Summary Stats (Psychological Reward)
            if (_isLoadingStats)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(strokeWidth: 2, color: AC.blue500),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AC.white,
                  borderRadius: AR.r10,
                  border: Border.all(color: AC.border, width: 0.5),
                  boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))]
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _statItem(Icons.receipt_long_rounded, 'Prescriptions', '$_rxCount'),
                    ),
                    Container(height: 40, width: 1, color: AC.border),
                    Expanded(
                      child: _statItem(Icons.point_of_sale_rounded, 'Walk-in Sales', '$_otcCount'),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 28),
            const Divider(color: AC.border),
            const SizedBox(height: 16),

            // 🌟 Blind Cash Reconciliation (Fraud Prevention)
            const Text('Final Step: Count the drawer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900)),
            const SizedBox(height: 12),
            
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F8FB), 
                borderRadius: AR.r10,
              ),
              child: TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AC.blue500),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: AC.ink200),
                  prefixText: 'EGP ',
                  prefixStyle: TextStyle(fontSize: 16, color: AC.ink300, fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 🌟 Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: AC.ink400, fontWeight: FontWeight.w600)),
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AC.blue500,
                      foregroundColor: AC.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(borderRadius: AR.r10),
                    ),
                    onPressed: _isSubmitting ? null : () async {
                       if (_cashCtrl.text.isEmpty) return;
                       
                       setState(() => _isSubmitting = true);
                       
                       try {
                         // بنبعت الفلوس للـ Backend والموديل يقارنها سرياً
                         await ApiService.shifts.reconcile(double.parse(_cashCtrl.text));

                         if(mounted) {
                           Navigator.pop(context);
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(
                               content: Text('Shift closed successfully! See you tomorrow 🌸'), 
                               backgroundColor: AC.greenFg
                             )
                           );
                         }
                       } catch (e) {
                         if(mounted) {
                           setState(() => _isSubmitting = false);
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text('Error closing shift: $e'), backgroundColor: AC.redFg)
                           );
                         }
                       }
                    },
                    child: _isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AC.white, strokeWidth: 2.5))
                      : const Text('Close Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                )
              ],
            )
          ],
        )
      )
    );
  }

  // Helper عشان نرسم الإحصائيات بشكل شيك
  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AC.blue500, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AC.ink900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AC.ink400)),
      ],
    );
  }
}