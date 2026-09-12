import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/device_activation_model.dart';
import '../../services/device_activation_service.dart';
import '../../theme/app_colors.dart';

/// Device Activation Screen
/// Allows users to activate device via QR code, activation code, or email
class DeviceActivationScreen extends StatefulWidget {
  const DeviceActivationScreen({super.key});

  @override
  State<DeviceActivationScreen> createState() => _DeviceActivationScreenState();
}

class _DeviceActivationScreenState extends State<DeviceActivationScreen> {
  final DeviceActivationService _activationService = DeviceActivationService();
  final TextEditingController _codeController = TextEditingController();
  
  int _selectedIndex = 0; // 0: QR, 1: Code, 2: Email
  bool _isActivating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activate Your Anavaya Device'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Activation method selector
          _buildMethodSelector(),
          
          // Content based on selected method
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMethodTab(
            index: 0,
            icon: Icons.qr_code_scanner,
            label: 'Scan QR',
          ),
          _buildMethodTab(
            index: 1,
            icon: Icons.pin,
            label: 'Enter Code',
          ),
          _buildMethodTab(
            index: 2,
            icon: Icons.email,
            label: 'Use Email',
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: isSelected ? AppColors.primary : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 40,
              color: AppColors.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildQRScanner();
      case 1:
        return _buildCodeEntry();
      case 2:
        return _buildEmailActivation();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQRScanner() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Scan the QR code on your Anavaya device box',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && !_isActivating) {
                    final qrCode = barcodes.first.rawValue;
                    if (qrCode != null) {
                      _activateViaQR(qrCode);
                    }
                  }
                },
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Position the QR code within the frame',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeEntry() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Enter the 6-digit activation code',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can find this code on the back of your device',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActivating ? null : _activateViaCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isActivating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Activate Device',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailActivation() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 64, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Check your email for activation link',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'If your device was registered by a salesperson, we\'ve sent you an activation email.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActivating ? null : _checkEmailActivation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isActivating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Check for Pre-registered Device',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Open email app
              // TODO: Implement deep link to email app
            },
            child: const Text('Open Email App'),
          ),
        ],
      ),
    );
  }

  Future<void> _activateViaQR(String qrCode) async {
    setState(() => _isActivating = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    final userEmail = authProvider.currentUser?.email;

    if (userId == null || userEmail == null) {
      _showError('Please sign in first');
      setState(() => _isActivating = false);
      return;
    }

    final result = await _activationService.activateViaQRCode(
      qrCode,
      userId,
      userEmail,
    );

    setState(() => _isActivating = false);

    if (result.success) {
      _showSuccessAndNavigate(result);
    } else {
      _showError(result.error ?? 'Activation failed');
    }
  }

  Future<void> _activateViaCode() async {
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      _showError('Please enter a 6-digit code');
      return;
    }

    setState(() => _isActivating = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    final userEmail = authProvider.currentUser?.email;

    if (userId == null || userEmail == null) {
      _showError('Please sign in first');
      setState(() => _isActivating = false);
      return;
    }

    final result = await _activationService.activateViaCode(
      code,
      userId,
      userEmail,
    );

    setState(() => _isActivating = false);

    if (result.success) {
      _showSuccessAndNavigate(result);
    } else {
      _showError(result.error ?? 'Activation failed');
    }
  }

  Future<void> _checkEmailActivation() async {
    setState(() => _isActivating = true);

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.uid;
    final userEmail = authProvider.currentUser?.email;

    if (userId == null || userEmail == null) {
      _showError('Please sign in first');
      setState(() => _isActivating = false);
      return;
    }

    final result = await _activationService.claimPreregisteredDevice(
      userId,
      userEmail,
    );

    setState(() => _isActivating = false);

    if (result.success) {
      _showSuccessAndNavigate(result);
    } else {
      _showError(result.error ?? 'No pre-registered device found');
    }
  }

  void _showSuccessAndNavigate(ActivationResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Success!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result.message ?? 'Device activated successfully!'),
            const SizedBox(height: 12),
            Text(
              'Device ID: ${result.deviceId}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to previous screen
              // Navigate to WiFi provisioning
              Navigator.of(context).pushNamed(
                '/device-provisioning',
                arguments: result.deviceId,
              );
            },
            child: const Text('Continue Setup'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
