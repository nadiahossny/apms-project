// ═══════════════════════════════════════════════════════════════════════════
// medicine_scanner_screen.dart  — APMS Single Medicine Barcode Scanner
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'theme/tokens.dart';
import 'widgets/medicine_form_dialog.dart'; // Adjust path if needed

class MedicineScannerScreen extends StatefulWidget {
  const MedicineScannerScreen({super.key});

  @override
  State<MedicineScannerScreen> createState() => _MedicineScannerScreenState();
}

class _MedicineScannerScreenState extends State<MedicineScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late AnimationController _animationController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Controls the scanning "laser" animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String scannedCode = barcodes.first.rawValue!;
      
      // FIX: Use the variable by printing it to the debug console
      // This clears the warning and lets you verify the scanner works
      debugPrint('💊 Successfully scanned APMS barcode: $scannedCode');
      
      setState(() {
        _isProcessing = true;
      });

      // Pause the camera so it doesn't keep scanning while the dialog is open
      await _cameraController.pause();

      if (!mounted) return;

      // TODO: Connect this to your actual medicine lookup
      // Future workflow: 
      // final existingMed = await ApiService.medicines.getByBarcode(scannedCode);
      // final result = await showMedicineDialog(context, existing: existingMed);
      
      final result = await showMedicineDialog(context); 

      if (!mounted) return;

      if (result != null) {
        // Medicine was saved/updated successfully, return true to inventory screen
        Navigator.of(context).pop(true);
      } else {
        // User cancelled the dialog, resume scanning
        setState(() {
          _isProcessing = false;
        });
        await _cameraController.start();
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.of(context).size.center(Offset.zero),
      width: 280,
      height: 180,
    );

    return Scaffold(
      backgroundColor: AC.ink900,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. The Camera Feed
          // 1. The Camera Feed
          MobileScanner(
            controller: _cameraController,
            scanWindow: scanWindow,
            onDetect: _handleBarcodeDetected,
            // FIX: Removed 'child' parameter
            errorBuilder: (context, error) => Center(
              child: Text(
                'Camera error: ${error.errorCode}',
                style: const TextStyle(color: AC.redFg),
              ),
            ),
          ),

          // 2. The Dark Overlay with the transparent cutout
          CustomPaint(
            painter: _ScannerOverlayPainter(scanWindow: scanWindow),
          ),

          // 3. The Animated Scan Line
          if (!_isProcessing)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final topOffset = scanWindow.top + (scanWindow.height * _animationController.value);
                return Positioned(
                  top: topOffset,
                  left: scanWindow.left,
                  width: scanWindow.width,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: AC.blue500,
                      boxShadow: [
                        BoxShadow(
                          color: AC.blue500.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                );
              },
            ),

          // 4. Loading Overlay (When processing a scan)
          if (_isProcessing)
            Container(
              color: AC.ink900.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AC.blue500),
                    SizedBox(height: 16),
                    Text('Processing barcode...', style: TextStyle(color: AC.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          // 5. Top Navigation Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: AR.r10,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AC.ink900.withOpacity(0.5),
                          borderRadius: AR.r10,
                          border: Border.all(color: AC.white.withOpacity(0.2)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, color: AC.white, size: 20),
                      ),
                    ),
                    
                    const Text(
                      'Scan Barcode',
                      style: TextStyle(color: AC.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    
                    // Flashlight Toggle
                    ValueListenableBuilder(
                      // FIX: Listen to the controller itself, not .torchState
                      valueListenable: _cameraController, 
                      builder: (context, state, child) {
                        // FIX: Access torchState through the updated state object
                        final isOn = state.torchState == TorchState.on; 
                        return InkWell(
                          onTap: () => _cameraController.toggleTorch(),
                          borderRadius: AR.r10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isOn ? AC.blue500 : AC.ink900.withOpacity(0.5),
                              borderRadius: AR.r10,
                              border: Border.all(color: isOn ? AC.blue500 : AC.white.withOpacity(0.2)),
                            ),
                            child: Icon(
                              isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: AC.white,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Bottom Instructions
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: AC.white, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'Align the barcode within the frame to scan',
                  style: TextStyle(color: AC.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    // Fallback if scanning fails
                    Navigator.of(context).pop();
                    showMedicineDialog(context); 
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AC.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: AC.ink900.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: AR.r10,
                      side: BorderSide(color: AC.white.withOpacity(0.2)),
                    ),
                  ),
                  child: const Text('Enter Manually'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Creates a semi-transparent dark overlay with a clear rounded rectangle cutout in the center
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;

  _ScannerOverlayPainter({required this.scanWindow});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      );

    // Subtract the cutout from the background
    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(finalPath, paint);

    // Draw the framing corners
    final borderPaint = Paint()
      ..color = AC.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 20.0;
    
    // Top Left
    canvas.drawLine(scanWindow.topLeft, scanWindow.topLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(scanWindow.topLeft, scanWindow.topLeft + Offset(0, cornerLength), borderPaint);
    
    // Top Right
    canvas.drawLine(scanWindow.topRight, scanWindow.topRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(scanWindow.topRight, scanWindow.topRight + Offset(0, cornerLength), borderPaint);
    
    // Bottom Left
    canvas.drawLine(scanWindow.bottomLeft, scanWindow.bottomLeft + Offset(cornerLength, 0), borderPaint);
    canvas.drawLine(scanWindow.bottomLeft, scanWindow.bottomLeft + Offset(0, -cornerLength), borderPaint);
    
    // Bottom Right
    canvas.drawLine(scanWindow.bottomRight, scanWindow.bottomRight + Offset(-cornerLength, 0), borderPaint);
    canvas.drawLine(scanWindow.bottomRight, scanWindow.bottomRight + Offset(0, -cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow;
  }
}