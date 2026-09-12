import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/smart_back_button.dart';

/// Screen for scanning QR codes to accept family invitations
///
/// Flow:
/// 1. Opens camera with MobileScanner
/// 2. Scans QR code containing invite URL
/// 3. Extracts inviteId from URL
/// 4. Navigates to AcceptInviteScreen
///
/// Example QR URLs:
/// - https://babycare.app/invite/{inviteId}?code={code}
/// - https://babycare.app/accept-invite/{inviteId}
/// - babycare://invite/{inviteId}
class ScanInviteQRScreen extends StatefulWidget {
  const ScanInviteQRScreen({super.key});

  @override
  State<ScanInviteQRScreen> createState() => _ScanInviteQRScreenState();
}

class _ScanInviteQRScreenState extends State<ScanInviteQRScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    // Parse the QR code to extract inviteId
    final inviteId = _extractInviteId(code);

    if (inviteId != null) {
      // Navigate to accept invite screen
      context.go('/accept-invite/$inviteId');
    } else {
      // Invalid QR code
      _showError('Invalid invitation QR code');
      setState(() => _isProcessing = false);
    }
  }

  String? _extractInviteId(String qrData) {
    try {
      // Handle different URL formats
      final uri = Uri.parse(qrData);

      // Format 1: https://babycare.app/invite/{inviteId}
      if (uri.path.startsWith('/invite/')) {
        return uri.pathSegments.last;
      }

      // Format 2: https://babycare.app/accept-invite/{inviteId}
      if (uri.path.startsWith('/accept-invite/')) {
        return uri.pathSegments.last;
      }

      // Format 3: babycare://invite/{inviteId}
      if (uri.scheme == 'babycare' && uri.host == 'invite') {
        return uri.pathSegments.firstOrNull;
      }

      // Format 4: Query parameter ?inviteId=...
      final inviteIdParam = uri.queryParameters['inviteId'];
      if (inviteIdParam != null) {
        return inviteIdParam;
      }

      return null;
    } catch (e) {
      debugPrint('Error parsing QR code: $e');
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            setState(() => _isProcessing = false);
            cameraController.start();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: SmartBackButton(
          fallbackRoute: '/settings',
          color: Colors.white,
        ),
        title: const Text(
          'Scan Invitation QR Code',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
              cameraController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),

          // Scanning overlay
          CustomPaint(
            painter: ScannerOverlay(),
            child: Container(),
          ),

          // Instructions at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Position the QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The camera will automatically detect the code',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Manual entry option
                  TextButton.icon(
                    onPressed: () {
                      _showManualEntryDialog();
                    },
                    icon: const Icon(Icons.edit, color: Colors.white),
                    label: const Text(
                      'Enter code manually',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 8-character invite code shared by your family member:',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ABC12345',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              onChanged: (value) {
                // Auto-uppercase
                final upperValue = value.toUpperCase();
                if (value != upperValue) {
                  controller.value = controller.value.copyWith(
                    text: upperValue,
                    selection:
                        TextSelection.collapsed(offset: upperValue.length),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.length == 8) {
                Navigator.pop(context);
                // Use the invite code as inviteId
                // In production, you'd query Firestore for matching code
                context.go('/accept-invite/$code');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an 8-character code'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the scanner overlay with rounded rectangle frame
class ScannerOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final framePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    // Calculate frame dimensions
    final frameWidth = size.width * 0.7;
    final frameHeight = frameWidth; // Square frame
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2;
    final right = left + frameWidth;
    final bottom = top + frameHeight;

    // Draw semi-transparent background
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final framePath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(20),
      ));

    canvas.drawPath(
      Path.combine(PathOperation.difference, backgroundPath, framePath),
      backgroundPaint,
    );

    // Draw frame border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, top, right, bottom),
        const Radius.circular(20),
      ),
      framePaint,
    );

    // Draw corner indicators
    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(left, top + 20),
      Offset(left, top + 20 + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + 20, top),
      Offset(left + 20 + cornerLength, top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(right, top + 20),
      Offset(right, top + 20 + cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - 20, top),
      Offset(right - 20 - cornerLength, top),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, bottom - 20),
      Offset(left, bottom - 20 - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + 20, bottom),
      Offset(left + 20 + cornerLength, bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(right, bottom - 20),
      Offset(right, bottom - 20 - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - 20, bottom),
      Offset(right - 20 - cornerLength, bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
