import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';
import 'device_discovery_screen.dart';
import '../main/wifi_provisioning_screen.dart';

/// Device Setup Screen
/// Guides users through WiFi provisioning and device connection
class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Your Device'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            const SizedBox(height: 32),

            // Step Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Row(
            children: [
              Container(
                width: isActive ? 12 : 8,
                height: isActive ? 12 : 8,
                decoration: BoxDecoration(
                  color: isCompleted || isActive
                      ? AppColors.primary
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              if (index < 3)
                Container(
                  width: 40,
                  height: 2,
                  color: isCompleted ? AppColors.primary : Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildWelcomeStep();
      case 1:
        return _buildTurnOnDeviceStep();
      case 2:
        return _buildWiFiProvisioningStep();
      case 3:
        return _buildCompletionStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWelcomeStep() {
    return Column(
      children: [
        Icon(
          Icons.devices,
          size: 80,
          color: AppColors.primary,
        ),
        const SizedBox(height: 24),
        const Text(
          'Welcome!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: DesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Let\'s set up your Anvaya Pod to start monitoring your baby\'s vitals.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: DesignTokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        // Quick MQTT discovery shortcut
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              final added = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const DeviceDiscoveryScreen()),
              );
              if (added == true && context.mounted) {
                context.go('/dashboard');
              }
            },
            icon: const Icon(Icons.search),
            label: const Text('Scan for Already-Provisioned Device'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'OR follow the steps below to provision a new device:',
          style: TextStyle(color: DesignTokens.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          icon: Icons.wifi,
          title: 'WiFi Required',
          description: 'Make sure you have WiFi credentials ready',
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.bluetooth,
          title: 'Bluetooth',
          description: 'We\'ll use Bluetooth to configure your device',
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          icon: Icons.timer,
          title: '5 Minutes',
          description: 'Setup takes about 5 minutes',
        ),
      ],
    );
  }

  Widget _buildTurnOnDeviceStep() {
    return Column(
      children: [
        Image.asset(
          'assets/images/device_setup.png',
          height: 200,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.power_settings_new,
              size: 100,
              color: Colors.green[400],
            );
          },
        ),
        const SizedBox(height: 32),
        const Text(
          'Turn On Your Device',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: DesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Follow these steps:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DesignTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        _buildStepInstruction(1, 'Plug in the Anvaya Pod to power'),
        _buildStepInstruction(2, 'Wait for the LED to start blinking blue'),
        _buildStepInstruction(
            3, 'Make sure Bluetooth is enabled on your phone'),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'If the LED is not blinking, press and hold the reset button for 3 seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWiFiProvisioningStep() {
    return Column(
      children: [
        Icon(
          Icons.wifi_find,
          size: 100,
          color: AppColors.primary,
        ),
        const SizedBox(height: 32),
        const Text(
          'Connect to WiFi',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: DesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'We\'ll now search for your device and configure WiFi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: DesignTokens.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WiFiProvisioningScreen()),
            );
          },
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Search for Device via BLE'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'This feature requires:\n• ESP32 device with WiFi provisioning\n• Bluetooth enabled\n• WiFi credentials',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: DesignTokens.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionStep() {
    return Column(
      children: [
        Icon(
          Icons.check_circle,
          size: 100,
          color: Colors.green[400],
        ),
        const SizedBox(height: 32),
        const Text(
          'All Set!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: DesignTokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your device is connected and ready to monitor vitals.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: DesignTokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _buildSuccessCard(
          icon: Icons.wifi,
          title: 'WiFi Connected',
          description: 'Device is online',
        ),
        const SizedBox(height: 16),
        _buildSuccessCard(
          icon: Icons.sensors,
          title: 'Sensors Active',
          description: 'Monitoring started',
        ),
        const SizedBox(height: 16),
        _buildSuccessCard(
          icon: Icons.cloud_done,
          title: 'Cloud Synced',
          description: 'Data is being saved',
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: DesignTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[600], size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepInstruction(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _currentStep--);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  // Done - go back to dashboard
                  context.go('/dashboard');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_currentStep == 3 ? 'Done' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }

}
