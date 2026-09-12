import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/common/smart_back_button.dart';

/// WiFi Provisioning screen for device setup
/// Ported from React Native WiFiProvisioningScreen.tsx
class WiFiProvisioningScreen extends StatefulWidget {
  const WiFiProvisioningScreen({super.key});

  @override
  State<WiFiProvisioningScreen> createState() => _WiFiProvisioningScreenState();
}

class _WiFiProvisioningScreenState extends State<WiFiProvisioningScreen> {
  final _passwordController = TextEditingController();
  final _manualSsidController = TextEditingController();
  String? _selectedSsid;
  bool _obscurePassword = true;
  bool _manualEntry = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProvisioning());
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _manualSsidController.dispose();
    super.dispose();
  }

  Future<void> _startProvisioning() async {
    if (!mounted) return;
    final deviceProvider = context.read<DeviceProvider>();
    deviceProvider.setDemoMode(false);
    await deviceProvider.startProvisioning();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final deviceProvider = context.read<DeviceProvider>();
        await deviceProvider.cancelProvisioning();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: DesignTokens.backgroundWarm,
        appBar: AppBar(
          backgroundColor: DesignTokens.backgroundWarm,
          title: const Text('Add Device'),
          leading: SmartCloseButton(
            onPressed: () async {
              final deviceProvider = context.read<DeviceProvider>();
              await deviceProvider.cancelProvisioning();
              if (context.mounted) context.pop();
            },
          ),
        ),
        body: Consumer<DeviceProvider>(
          builder: (context, deviceProvider, child) {
            return _buildContent(deviceProvider);
          },
        ),
      ),
    );
  }

  Widget _buildContent(DeviceProvider provider) {
    switch (provider.provisioningStep) {
      case ProvisioningStep.idle:
      case ProvisioningStep.checkingPermissions:
      case ProvisioningStep.checkingBluetooth:
        return _buildLoadingState('Preparing...');

      case ProvisioningStep.scanning:
        return _buildLoadingState('Scanning for devices...');

      case ProvisioningStep.selectingDevice:
        return _buildDeviceSelection(provider);

      case ProvisioningStep.connecting:
        return _buildLoadingState('Connecting to device...');

      case ProvisioningStep.scanningWifi:
        return _buildLoadingState('Scanning WiFi networks...');

      case ProvisioningStep.selectingWifi:
        return _buildWifiSelection(provider);

      case ProvisioningStep.provisioning:
        return _buildLoadingState('Configuring WiFi...');

      case ProvisioningStep.completed:
        return _buildCompletedState();
    }
  }

  Widget _buildLoadingState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelection(DeviceProvider provider) {
    final devices = provider.discoveredDevices;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your device',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose your BabyTrack device from the list below',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Error message
          if (provider.error != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(provider.error!)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Device list
          if (devices.isEmpty)
            _buildEmptyDevices(provider)
          else
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(
                          Icons.devices,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(device.name),
                      subtitle: Text('Signal: ${device.signalPercentage}%'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => provider.selectAndConnectDevice(device),
                    ),
                  );
                },
              ),
            ),

          // Rescan button
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.rescanDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDevices(DeviceProvider provider) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No devices found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Make sure your BabyTrack device is powered on and in pairing mode',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiSelection(DeviceProvider provider) {
    final networks = provider.wifiNetworks;
    final showManual = networks.isEmpty || _manualEntry;
    final effectiveSsid = showManual
        ? (_manualSsidController.text.trim().isNotEmpty
            ? _manualSsidController.text.trim()
            : null)
        : _selectedSsid;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connect to WiFi',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            showManual
                ? 'Enter the WiFi network name and password'
                : 'Choose a WiFi network for your device',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),

          // Error banner (e.g. wrong password from a previous attempt)
          if (provider.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      provider.error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Allow switching to a different device without a full cancel
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => provider.rescanDevices(),
                icon: const Icon(Icons.bluetooth_searching, size: 16),
                label: const Text('Try a different device'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Toggle between list and manual
          Row(
            children: [
              if (networks.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _manualEntry = !_manualEntry),
                  icon: Icon(_manualEntry ? Icons.list : Icons.edit),
                  label: Text(_manualEntry ? 'Show network list' : 'Enter manually'),
                ),
              if (networks.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Network list unavailable — enter manually',
                        style: TextStyle(fontSize: 13, color: Colors.orange.shade800),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Manual SSID entry
          if (showManual) ...[
            TextField(
              controller: _manualSsidController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'WiFi Network Name (SSID)',
                hintText: 'e.g. bbrouter',
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Network list (when available and not in manual mode)
          if (!showManual)
            Expanded(
              child: ListView.builder(
                itemCount: networks.length,
                itemBuilder: (context, index) {
                  final network = networks[index];
                  final isSelected = _selectedSsid == network.ssid;
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    color: isSelected ? AppColors.primaryLight.withValues(alpha: 0.3) : null,
                    child: ListTile(
                      leading: Icon(Icons.wifi,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary),
                      title: Text(network.ssid),
                      subtitle: Row(
                        children: [
                          ...List.generate(4, (i) => Icon(
                            Icons.signal_wifi_4_bar,
                            size: 12,
                            color: i < network.signalBars ? AppColors.primary : AppColors.border,
                          )),
                          if (network.isSecure) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const Icon(Icons.lock, size: 14, color: AppColors.textMuted),
                          ],
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () => setState(() => _selectedSsid = network.ssid),
                    ),
                  );
                },
              ),
            ),

          // Password + Connect (shown once a network is selected or manual SSID entered)
          if (effectiveSsid != null || (!showManual && _selectedSsid != null)) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'WiFi Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: LoadingButton(
                onPressed: () async {
                  final ssid = effectiveSsid ?? _selectedSsid!;
                  final deviceProvider = context.read<DeviceProvider>();
                  final authProvider = context.read<AuthProvider>();
                  final userId = authProvider.currentUser?.uid ?? '';
                  final familyId =
                      authProvider.firestoreUser?.familyIds.firstOrNull ?? userId;

                  final success = await deviceProvider.provisionWifi(
                    ssid,
                    _passwordController.text,
                    familyId: familyId,
                    userId: userId,
                  );
                  if (!success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.error ?? 'Failed to connect')),
                    );
                  }
                },
                isLoading: provider.isLoading,
                child: const Text('Connect'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 48,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Device Connected!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your BabyTrack device is now connected to WiFi',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/dashboard');
                },
                child: const Text('Go to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
