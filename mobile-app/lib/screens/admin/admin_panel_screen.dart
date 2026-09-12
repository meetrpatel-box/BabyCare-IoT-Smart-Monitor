import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../theme/design_tokens.dart';

/// Admin panel for managing cry detection model configuration and A/B testing.
///
/// Requires admin authentication. Access via Settings > Admin Panel.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  late final AdminService _adminService;
  ModelConfig? _config;
  ModelPerformanceStats? _performance;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _adminService.getModelConfig(),
        _adminService.getModelPerformance(),
      ]);

      if (mounted) {
        setState(() {
          _config = results[0] as ModelConfig;
          _performance = results[1] as ModelPerformanceStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        title: const Text('Admin Panel'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(DesignTokens.spaceLg),
                    children: [
                      _buildModelConfigSection(),
                      const SizedBox(height: DesignTokens.spaceXl),
                      _buildABTestSection(),
                      const SizedBox(height: DesignTokens.spaceXl),
                      _buildPerformanceSection(),
                      const SizedBox(height: DesignTokens.spaceXl),
                      _buildQuickActions(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings,
                size: 48, color: DesignTokens.statusCritical),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'Admin Access Required',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXl,
                fontWeight: DesignTokens.fontWeightBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceXl),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Model Config Section ==========

  Widget _buildModelConfigSection() {
    final config = _config!;
    return _buildCard(
      title: 'Model Configuration',
      icon: Icons.tune,
      children: [
        _buildConfigRow('Active Version', config.activeVersion),
        _buildConfigRow('Backend', config.backend.label),
        if (config.storagePath != null)
          _buildConfigRow('Storage Path', config.storagePath!),
        if (config.vertexEndpointId != null)
          _buildConfigRow('Vertex Endpoint', config.vertexEndpointId!),
        const SizedBox(height: DesignTokens.spaceMd),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showChangeBackendDialog(),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change Backend'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========== A/B Test Section ==========

  Widget _buildABTestSection() {
    final abTest = _config?.abTest;
    final abStats = _performance?.abTestStats;

    return _buildCard(
      title: 'A/B Testing',
      icon: Icons.science,
      children: [
        if (abTest == null) ...[
          const Text(
            'No A/B test active',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeMd,
              color: DesignTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          ElevatedButton.icon(
            onPressed: () => _showCreateABTestDialog(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Start A/B Test'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primaryTeal,
              foregroundColor: DesignTokens.textOnPrimary,
            ),
          ),
        ] else ...[
          _buildConfigRow('Challenger', abTest.challengerVersion),
          _buildConfigRow('Backend', abTest.challengerBackend.label),
          _buildConfigRow('Traffic', '${abTest.trafficPercent}%'),
          if (abStats != null) ...[
            const Divider(height: DesignTokens.spaceXl),
            _buildComparisonRow(
              'Primary',
              '${(abStats.primaryAccuracy * 100).toStringAsFixed(1)}%',
              '${abStats.primaryCount} samples',
            ),
            _buildComparisonRow(
              'Challenger',
              '${(abStats.challengerAccuracy * 100).toStringAsFixed(1)}%',
              '${abStats.challengerCount} samples',
            ),
          ],
          const SizedBox(height: DesignTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditTrafficDialog(abTest),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Adjust Traffic'),
                ),
              ),
              const SizedBox(width: DesignTokens.spaceSm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _disableABTest(),
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop Test'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.statusCritical,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ========== Performance Section ==========

  Widget _buildPerformanceSection() {
    final perf = _performance!;
    return _buildCard(
      title: 'Model Performance',
      icon: Icons.analytics,
      children: [
        Row(
          children: [
            _buildStatBadge(
              'Cloud Accuracy',
              '${(perf.cloudAccuracy * 100).toStringAsFixed(1)}%',
              DesignTokens.accentBlue,
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            _buildStatBadge(
              'Edge Accuracy',
              '${(perf.edgeAccuracy * 100).toStringAsFixed(1)}%',
              DesignTokens.accentPurple,
            ),
            const SizedBox(width: DesignTokens.spaceSm),
            _buildStatBadge(
              'Avg Latency',
              '${perf.avgProcessingTimeMs}ms',
              DesignTokens.accentGreen,
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spaceLg),
        _buildConfigRow('Total Classified', '${perf.totalClassified}'),
        _buildConfigRow('With Ground Truth', '${perf.totalWithGroundTruth}'),
        if (perf.classificationBreakdown.isNotEmpty) ...[
          const Divider(height: DesignTokens.spaceXl),
          const Text(
            'Classification Distribution',
            style: TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: DesignTokens.textMuted,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceSm),
          ...perf.classificationBreakdown.entries.map(
            (e) => _buildDistributionBar(e.key, e.value, perf.totalClassified),
          ),
        ],
      ],
    );
  }

  // ========== Quick Actions ==========

  Widget _buildQuickActions() {
    return _buildCard(
      title: 'Quick Actions',
      icon: Icons.flash_on,
      children: [
        _buildActionTile(
          icon: Icons.file_download,
          title: 'Export Training Data',
          subtitle: 'Export labeled events for model retraining',
          onTap: () => _exportTrainingData(),
        ),
        _buildActionTile(
          icon: Icons.person_add,
          title: 'Manage Admin Access',
          subtitle: 'Grant or revoke admin privileges',
          onTap: () => _showAdminAccessDialog(),
        ),
      ],
    );
  }

  // ========== Shared Widgets ==========

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceWhite,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        boxShadow: [DesignTokens.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: DesignTokens.primaryTeal),
              const SizedBox(width: DesignTokens.spaceSm),
              Text(
                title,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceLg),
          ...children,
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeMd,
              color: DesignTokens.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeMd,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: DesignTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String accuracy, String samples) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeMd,
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
          Text(
            accuracy,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeLg,
              fontWeight: DesignTokens.fontWeightBold,
              color: DesignTokens.textPrimary,
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          Text(
            samples,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeXs,
              color: DesignTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightBold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                color: DesignTokens.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionBar(String label, int count, int total) {
    final ratio = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: DesignTokens.surfaceGray,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    DesignTokens.primaryTeal),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.spaceSm),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXs,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DesignTokens.spaceMd),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignTokens.surfaceGray,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              ),
              child: Icon(icon, size: 20, color: DesignTokens.primaryTeal),
            ),
            const SizedBox(width: DesignTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeMd,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeXs,
                      color: DesignTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: DesignTokens.textMuted),
          ],
        ),
      ),
    );
  }

  // ========== Dialogs ==========

  void _showChangeBackendDialog() {
    final backends = ModelBackend.values;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: backends.map((backend) {
            return ListTile(
              title: Text(backend.label),
              leading: Radio<ModelBackend>(
                value: backend,
                groupValue: _config?.backend,
                onChanged: (value) async {
                  Navigator.of(ctx).pop();
                  if (value != null) {
                    await _updateConfig(backend: value);
                  }
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateABTestDialog() {
    final versionController = TextEditingController();
    final trafficController = TextEditingController(text: '10');
    ModelBackend selectedBackend = ModelBackend.heuristic;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Start A/B Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: versionController,
                decoration: const InputDecoration(
                  labelText: 'Challenger Version',
                  hintText: 'e.g., yamnet-v2.0-beta',
                ),
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              DropdownButtonFormField<ModelBackend>(
                value: selectedBackend,
                decoration:
                    const InputDecoration(labelText: 'Challenger Backend'),
                items: ModelBackend.values
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedBackend = v);
                  }
                },
              ),
              const SizedBox(height: DesignTokens.spaceMd),
              TextField(
                controller: trafficController,
                decoration: const InputDecoration(
                  labelText: 'Traffic %',
                  hintText: '0-100',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final traffic =
                    int.tryParse(trafficController.text) ?? 10;
                await _updateConfig(
                  abTest: ABTestConfig(
                    challengerVersion: versionController.text,
                    challengerBackend: selectedBackend,
                    trafficPercent: traffic.clamp(0, 100),
                  ),
                );
              },
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTrafficDialog(ABTestConfig currentTest) {
    final controller =
        TextEditingController(text: '${currentTest.trafficPercent}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adjust Traffic Split'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Challenger Traffic %',
            hintText: '0-100',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final traffic = int.tryParse(controller.text) ?? 10;
              await _updateConfig(
                abTest: ABTestConfig(
                  challengerVersion: currentTest.challengerVersion,
                  challengerBackend: currentTest.challengerBackend,
                  challengerStoragePath: currentTest.challengerStoragePath,
                  trafficPercent: traffic.clamp(0, 100),
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showAdminAccessDialog() {
    final uidController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manage Admin Access'),
        content: TextField(
          controller: uidController,
          decoration: const InputDecoration(
            labelText: 'User UID',
            hintText: 'Enter the user\'s Firebase UID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _setAdmin(uidController.text, false);
            },
            child: const Text('Revoke Admin'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _setAdmin(uidController.text, true);
            },
            child: const Text('Grant Admin'),
          ),
        ],
      ),
    );
  }

  // ========== Actions ==========

  Future<void> _updateConfig({
    ModelBackend? backend,
    ABTestConfig? abTest,
    bool disableAbTest = false,
  }) async {
    try {
      await _adminService.updateModelConfig(
        backend: backend,
        abTest: abTest,
        disableAbTest: disableAbTest,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuration updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _disableABTest() async {
    await _updateConfig(disableAbTest: true);
  }

  Future<void> _exportTrainingData() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training data export started...')),
      );
    }
  }

  Future<void> _setAdmin(String uid, bool isAdmin) async {
    if (uid.isEmpty) return;
    try {
      await _adminService.setAdminClaim(
        targetUid: uid,
        isAdmin: isAdmin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isAdmin ? 'Admin granted to $uid' : 'Admin revoked from $uid'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
