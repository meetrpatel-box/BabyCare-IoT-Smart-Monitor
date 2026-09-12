import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/cloud_webrtc_service.dart';
import '../../config/relay_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/baby_provider.dart';
import '../../providers/mqtt_provider.dart';
import '../../models/mqtt_device_model.dart';
import '../../services/live_speak_service.dart';
import '../../services/audio_udp_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

/// Studio Dashboard - Main home screen
/// Exact port from React Native DashboardScreen_Studio.tsx
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<QuerySnapshot>? _vitalSignsSubscription;

  // Latest vital signs data
  double? _latestTemp;
  double? _latestHumidity;
  double? _latestHeartRate;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _initMqtt();
    });
  }

  Future<void> _initMqtt() async {
    if (!mounted) return;
    final mqttProvider = context.read<DeviceMqttProvider>();
    await mqttProvider.initialize();
  }

  @override
  void dispose() {
    _vitalSignsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final babyProvider = context.read<BabyProvider>();

    if (authProvider.userId != null) {
      await babyProvider.loadBabiesForParent(authProvider.userId!);
      if (mounted && babyProvider.selectedBaby != null) {
        babyProvider.subscribeToBaby(babyProvider.selectedBaby!.id);
        _subscribeToVitalSigns(babyProvider.selectedBaby!.id);
      }
    }
  }

  void _subscribeToVitalSigns(String babyId) {
    _vitalSignsSubscription?.cancel();

    _vitalSignsSubscription = FirebaseFirestore.instance
        .collection('vital_signs')
        .where('babyId', isEqualTo: babyId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty && mounted) {
        // Sort manually to get the latest
        final sortedDocs = snapshot.docs.toList()
          ..sort((a, b) {
            final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ??
                DateTime(2000);
            return bTime.compareTo(aTime); // descending
          });

        if (sortedDocs.isNotEmpty) {
          final data = sortedDocs.first.data();
          setState(() {
            _latestTemp = (data['bodyTemperature'] as num?)?.toDouble();
            _latestHumidity = (data['humidity'] as num?)?.toDouble();
            _latestHeartRate = (data['heartRate'] as num?)?.toDouble();
            _lastUpdated = (data['timestamp'] as Timestamp?)?.toDate();
          });
        }
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${weekdays[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}';
  }

  String _getTimeSince(DateTime time) {
    final difference = DateTime.now().difference(time);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm, // Global background
      body: SafeArea(
        child: Consumer<BabyProvider>(
          builder: (context, babyProvider, _) {
            if (babyProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeader(babyProvider),
                    const SizedBox(height: 32),
                    _buildStatusCard(babyProvider),
                    const SizedBox(height: 24),
                    _buildDeviceSection(),
                    const SizedBox(height: 24),
                    _buildDailyMoments(),
                    const SizedBox(height: 24),
                    _buildSmartTools(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                    const SizedBox(height: 24),
                    _buildTimeline(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BabyProvider babyProvider) {
    final baby = babyProvider.selectedBaby;
    final userName =
        context.read<AuthProvider>().currentUser?.displayName ?? 'Parent';

    // Handle case when no baby is selected
    if (baby == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getFormattedDate()} 📅',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foregroundSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_getGreeting()}, $userName 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.card_giftcard,
                          size: 14, color: Color(0xFF4338CA)),
                      const SizedBox(width: 6),
                      Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - Date & Greeting
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getFormattedDate()} 📅',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.foregroundSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_getGreeting()}, $userName 👋',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              // Age pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.card_giftcard,
                        size: 14, color: Color(0xFF4338CA)),
                    const SizedBox(width: 6),
                    Text(
                      baby != null
                          ? '${baby.ageInMonths} months old'
                          : 'Welcome',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4338CA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right side - Action buttons
        Row(
          children: [
            // WiFi/Connect Device button
            GestureDetector(
              onTap: () => context.push('/wifi-provisioning'),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child:
                    const Icon(Icons.wifi, color: Color(0xFF0284C7), size: 20),
              ),
            ),
            const SizedBox(width: 12),
            // User avatar
            GestureDetector(
              onTap: () => context.go('/settings'),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(BabyProvider babyProvider) {
    final baby = babyProvider.selectedBaby;
    const isAsleep = true;

    return Consumer<DeviceMqttProvider>(
      builder: (ctx, mqttProvider, _) {
        // Prefer live MQTT vitals from board; fall back to Firestore snapshot.
        final mqttVitals = mqttProvider.firstOnlineVitals;
        final displayTemp = mqttVitals?.bodyTemperature ?? _latestTemp;
        final displayHumidity =
            mqttVitals?.humidity.toDouble() ?? _latestHumidity;
        final displayHR = mqttVitals?.heartRate.toDouble() ?? _latestHeartRate;
        final displayUpdated = mqttVitals?.timestamp ?? _lastUpdated;
        final isMqttLive = mqttVitals != null;

        return _buildStatusCardContent(
          baby: baby,
          babyProvider: babyProvider,
          isAsleep: isAsleep,
          latestTemp: displayTemp,
          latestHumidity: displayHumidity,
          latestHeartRate: displayHR,
          lastUpdated: displayUpdated,
          isMqttLive: isMqttLive,
        );
      },
    );
  }

  Widget _buildStatusCardContent({
    required dynamic baby,
    required BabyProvider babyProvider,
    required bool isAsleep,
    double? latestTemp,
    double? latestHumidity,
    double? latestHeartRate,
    DateTime? lastUpdated,
    bool isMqttLive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      baby?.name ?? 'Baby',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAsleep
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        isAsleep ? 'Sleeping 😴' : 'Awake 👶',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAsleep
                              ? const Color(0xFF4338CA)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sleeping soundly for 2h 15m',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.foregroundSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // Data source indicator
                Row(
                  children: [
                    Icon(
                      lastUpdated != null
                          ? (isMqttLive ? Icons.sensors : Icons.cloud_queue)
                          : Icons.cloud_off_outlined,
                      size: 14,
                      color: lastUpdated != null
                          ? AppColors.success
                          : AppColors.foregroundTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lastUpdated != null
                          ? (isMqttLive
                              ? 'Live from Board • ${_getTimeSince(lastUpdated!)}'
                              : 'Live via Cloud • ${_getTimeSince(lastUpdated!)}')
                          : 'Waiting for data...',
                      style: TextStyle(
                        fontSize: 12,
                        color: lastUpdated != null
                            ? AppColors.success
                            : AppColors.foregroundTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Vitals Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildVitalItem(
                    Icons.thermostat_outlined,
                    latestTemp != null
                        ? '${latestTemp.toStringAsFixed(1)}°C'
                        : '--',
                    'Temp'),
                _buildVitalDivider(),
                _buildVitalItem(
                    Icons.water_drop_outlined,
                    latestHumidity != null
                        ? '${latestHumidity.toInt()}%'
                        : '--',
                    'Humidity'),
                _buildVitalDivider(),
                _buildVitalItem(
                    Icons.favorite_outline,
                    latestHeartRate != null
                        ? '${latestHeartRate.toInt()}'
                        : '--',
                    'BPM'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Vital reassurance - Child Psychology guideline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4), // Gentle green bg
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'All vitals within healthy range',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // View Live Stream button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // View Vitals button (new)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final babyId = babyProvider.selectedBaby?.id;
                      if (babyId != null) {
                        context.push('/vitals/$babyId');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.favorite, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Live Vitals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Live Stream button — opens camera source picker
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showStreamSourcePicker(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.video_camera_front, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Live Stream',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.foregroundSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.border.withOpacity(0.5),
    );
  }

  Widget _buildDailyMoments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Moments 📸',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1519689680058-324335c77eba?w=800&q=80',
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Captured Today',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '10:30 AM • Nursery Cam',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartTools() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Smart Tools',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/smart-tools'),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push('/cry-analyzer'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text('🎙️', style: TextStyle(fontSize: 30)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cry Analyzer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C2D12),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Record or upload a baby cry for AI analysis',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF97316),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF7C2D12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildSmartToolCard(
              onTap: () => context.push('/sleep-analysis'),
              icon: '🛏️',
              value: '85',
              title: 'Sleep Score',
              subtitle: 'Excellent',
              bgColor: const Color(0xFFF5F3FF),
              titleColor: const Color(0xFF312E81),
              valueColor: const Color(0xFF4338CA),
              subtitleColor: const Color(0xFF6366F1),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSmartToolCard(
              onTap: () => context.push('/vitals-history'),
              icon: '📊',
              title: 'Vitals History',
              subtitle: 'View Trends',
              bgColor: const Color(0xFFFEF3C7),
              titleColor: const Color(0xFF78350F),
              subtitleColor: const Color(0xFFF59E0B),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildSmartToolCard(
              onTap: () => context.push('/ai-insights'),
              icon: '✨',
              title: 'AI Insights',
              subtitle: '3 New Updates',
              bgColor: const Color(0xFFF0FDF4),
              titleColor: const Color(0xFF14532D),
              subtitleColor: const Color(0xFF22C55E),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _buildSmartToolCard(
              onTap: () => context.push('/music-player'),
              icon: '🎵',
              title: 'Sounds',
              subtitle: 'Currently Off',
              bgColor: const Color(0xFFFFF7ED),
              titleColor: const Color(0xFF7C2D12),
              subtitleColor: const Color(0xFFF97316),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Consumer<BabyProvider>(
          builder: (context, babyProvider, _) {
            final babyId = babyProvider.selectedBaby?.id ?? '';
            return Row(
              children: [
                Expanded(
                    child: _buildSmartToolCard(
                  onTap: babyId.isEmpty
                      ? null
                      : () => context.push('/cry-history/$babyId'),
                  icon: '😢',
                  title: 'Cry History',
                  subtitle: 'Detection Log',
                  bgColor: const Color(0xFFFFF1F2),
                  titleColor: const Color(0xFF881337),
                  subtitleColor: const Color(0xFFE11D48),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildSmartToolCard(
                  onTap: () => context.push('/cry-consent'),
                  icon: '🔔',
                  title: 'Cry Alerts',
                  subtitle: 'Data Settings',
                  bgColor: const Color(0xFFF0F9FF),
                  titleColor: const Color(0xFF0C4A6E),
                  subtitleColor: const Color(0xFF0284C7),
                )),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSmartToolCard({
    VoidCallback? onTap,
    required String icon,
    String? value,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color titleColor,
    Color? valueColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: valueColor,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions ⚡',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickActionItem('🍼', 'Feed', const Color(0xFFFFF7ED)),
              _buildQuickActionItem('📌', 'Diaper', const Color(0xFFF0FDF4)),
              _buildQuickActionItem('🌙', 'Sleep', const Color(0xFFF5F3FF)),
              _buildQuickActionItem('⚖️', 'Weight', const Color(0xFFEFF6FF)),
              _buildQuickActionItem('📷', 'Photo', const Color(0xFFFFF1F2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(String emoji, String label, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          final babyProvider = context.read<BabyProvider>();
          if (label == 'Photo' && babyProvider.selectedBaby != null) {
            context.push('/photos/${babyProvider.selectedBaby!.id}');
          }
          // TODO: Add navigation for other quick actions
        },
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF94A3B8).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Timeline",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
            GestureDetector(
              onTap: () => context.push('/vitals-history'),
              child: Text(
                'View History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTimelineItem('10:30 am', 'Sleeping 😴',
                  'Detected deep sleep cycle', AppColors.border, true),
              _buildTimelineItem('08:15 am', 'Feeding 🍼', 'Bottle, 150ml',
                  AppColors.primary, true),
              _buildTimelineItem('07:00 am', 'Woke Up ☀️', 'Good mood',
                  AppColors.warning, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
      String time, String event, String detail, Color dotColor, bool showLine) {
    return SizedBox(
      height: 70,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.foregroundSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1,
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.foregroundSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Connected Devices',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<DeviceMqttProvider>(
          builder: (context, mqttProvider, _) {
            final devices = mqttProvider.devices;
            if (devices.isEmpty) {
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.devices_other, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'No devices connected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              itemBuilder: (ctx, idx) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _buildDeviceCard(devices[idx], mqttProvider),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeviceCard(
    MqttDeviceModel device,
    DeviceMqttProvider provider,
  ) {
    final vitals = device.latestVitals;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: device.isOnline ? AppColors.primary : Colors.grey[300]!,
          width: device.isOnline ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.deviceName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: device.isOnline ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.isOnline ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (device.isOnline ? Colors.green : Colors.red)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device.status.value.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: device.isOnline ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),

          // Live vitals mini-row (shown when board sends data)
          if (vitals != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniVital(
                      '🌡️', '${vitals.bodyTemperature.toStringAsFixed(1)}°C'),
                  _buildMiniVital('💧', '${vitals.humidity}%'),
                  _buildMiniVital('❤️', '${vitals.heartRate} bpm'),
                  _buildMiniVital('🫁', '${vitals.respiratoryRate} /min'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Row 1: Reconnect | Disconnect
          Consumer<DeviceMqttProvider>(
            builder: (ctx, mqtt, _) => Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: mqtt.isCommandInProgress(device.deviceId)
                        ? null
                        : () async {
                            final result =
                                await mqtt.reconnectDevice(device.deviceId);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(result
                                    ? 'Reconnecting…'
                                    : 'Reconnect failed'),
                                duration: const Duration(seconds: 2),
                              ));
                            }
                          },
                    icon: mqtt.isCommandInProgress(device.deviceId)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_protected_setup, size: 16),
                    label: const Text('Reconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: mqtt.isCommandInProgress(device.deviceId)
                        ? null
                        : () async {
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('Disconnect Device'),
                                content: const Text(
                                  'This will clear the saved WiFi '
                                  'credentials and put the device back '
                                  'into pairing mode.\n\nContinue?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogCtx, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('Disconnect'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await mqtt.disconnectDevice(device.deviceId);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Device disconnected — use Add Device to reconnect'),
                                    duration: Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                    icon: mqtt.isCommandInProgress(device.deviceId)
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_off, size: 16),
                    label: const Text('Disconnect'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Row 2: Speak + Camera
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: device.isOnline
                      ? () => _showSpeakSheet(context, device.deviceId)
                      : null,
                  icon: const Icon(Icons.record_voice_over, size: 18),
                  label: const Text('Speak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (device.isOnline && device.deviceIp != null)
                      ? () => _showCameraSheet(context, device)
                      : null,
                  icon: const Icon(Icons.videocam, size: 18),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniVital(String emoji, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF166534)),
        ),
      ],
    );
  }

  void _showSpeakSheet(BuildContext context, String deviceId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SpeakBottomSheet(deviceId: deviceId),
    );
  }

  void _showCameraSheet(BuildContext context, MqttDeviceModel device) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _CameraBottomSheet(device: device),
    );
  }

  void _showStreamSourcePicker(BuildContext context) {
    final mqttProvider = context.read<DeviceMqttProvider>();
    final matches =
        mqttProvider.devices.where((d) => d.isOnline && d.deviceIp != null);
    final boardDevice = matches.isEmpty ? null : matches.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _StreamSourcePickerSheet(
        boardDevice: boardDevice,
        onPhoneCamera: () {
          Navigator.pop(sheetCtx);
          // WebRTC relay server not yet deployed — show informational message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Phone camera streaming requires a relay server (coming soon). '
                'Use the board camera for live monitoring.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        },
        onBoardCamera: boardDevice != null
            ? () {
                Navigator.pop(sheetCtx);
                _showCameraSheet(context, boardDevice);
              }
            : null,
      ),
    );
  }
}

// ── Speak bottom sheet ─────────────────────────────────────────────────────

class _SpeakBottomSheet extends StatefulWidget {
  final String deviceId;
  const _SpeakBottomSheet({required this.deviceId});

  @override
  State<_SpeakBottomSheet> createState() => _SpeakBottomSheetState();
}

class _SpeakBottomSheetState extends State<_SpeakBottomSheet> {
  late final LiveSpeakService _speakService;
  late final AudioUdpService _audioWsService;

  @override
  void initState() {
    super.initState();
    final mqttProvider = context.read<DeviceMqttProvider>();
    
    _audioWsService = AudioUdpService();
    final matches = mqttProvider.devices.where((d) => d.deviceId == widget.deviceId);
    if (matches.isNotEmpty && matches.first.deviceIp != null) {
      _audioWsService.connect(matches.first.deviceIp!);
    }
    
    _speakService = LiveSpeakService(_audioWsService);
  }

  @override
  void dispose() {
    _speakService.stopSpeaking(widget.deviceId);
    _speakService.dispose();
    _audioWsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _speakService,
      builder: (ctx, _) {
        final isSpeaking = _speakService.isSpeaking;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Speak to Baby',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Voice plays through the device speaker',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 28),
                // Big mic button
                GestureDetector(
                  onTap: () async {
                    if (isSpeaking) {
                      await _speakService.stopSpeaking(widget.deviceId);
                    } else {
                      final mqttProvider = context.read<DeviceMqttProvider>();
                      final matches = mqttProvider.devices.where((d) => d.deviceId == widget.deviceId);
                      final deviceIp = matches.isNotEmpty ? matches.first.deviceIp : null;
                      final ok =
                          await _speakService.startSpeaking(widget.deviceId, deviceIp: deviceIp);
                      if (!ok && ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Failed to start. Check mic permission and device connection.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSpeaking ? Colors.red : const Color(0xFF7C3AED),
                      boxShadow: [
                        BoxShadow(
                          color: (isSpeaking
                                  ? Colors.red
                                  : const Color(0xFF7C3AED))
                              .withOpacity(0.35),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      isSpeaking ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isSpeaking ? 'Tap to stop' : 'Tap to start speaking',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stream source picker sheet ─────────────────────────────────────────────

class _StreamSourcePickerSheet extends StatelessWidget {
  final MqttDeviceModel? boardDevice;
  final VoidCallback onPhoneCamera;
  final VoidCallback? onBoardCamera;

  const _StreamSourcePickerSheet({
    required this.boardDevice,
    required this.onPhoneCamera,
    this.onBoardCamera,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Camera',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Select the camera source for live stream',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildOption(
              icon: Icons.smartphone,
              iconBg: const Color(0xFFEDE9FE),
              iconColor: const Color(0xFF7C3AED),
              title: 'Phone Camera',
              subtitle: 'Use your device front or back camera',
              badgeText: 'Default',
              badgeColor: const Color(0xFF7C3AED),
              enabled: true,
              onTap: onPhoneCamera,
            ),
            const SizedBox(height: 12),
            _buildOption(
              icon: Icons.videocam,
              iconBg: boardDevice != null
                  ? const Color(0xFFCCFBF1)
                  : Colors.grey[100]!,
              iconColor:
                  boardDevice != null ? const Color(0xFF0F766E) : Colors.grey,
              title: 'Board Camera',
              subtitle: boardDevice != null
                  ? 'ESP32 · ${boardDevice!.deviceName} · ${boardDevice!.deviceIp}'
                  : 'No device online with camera',
              badgeText: boardDevice != null ? 'Live' : 'Offline',
              badgeColor:
                  boardDevice != null ? const Color(0xFF0F766E) : Colors.grey,
              enabled: boardDevice != null,
              onTap: onBoardCamera,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled ? badgeColor.withOpacity(0.3) : Colors.grey[200]!,
            width: 1.5,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: enabled ? const Color(0xFF1E293B) : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera bottom sheet (Cloud WebRTC + Local Fallback) ──────────────────────────

class _CameraBottomSheet extends StatefulWidget {
  final MqttDeviceModel device;
  const _CameraBottomSheet({required this.device});

  @override
  State<_CameraBottomSheet> createState() => _CameraBottomSheetState();
}

class _CameraBottomSheetState extends State<_CameraBottomSheet> {
  // Cloud WebRTC Service
  late final CloudWebRTCService _webrtcService;
  bool _useWebRTC = true;
  bool _isLocalMode = false;
  bool _isProbing = true;

  // Local MJPEG stream
  Uint8List? _frame;
  bool _running = false;
  http.Client? _client;
  
  // Audio streaming service (Local UDP + Cloud Relay speak)
  final AudioUdpService _audioService = AudioUdpService();
  late final LiveSpeakService _speakService;

  @override
  void initState() {
    super.initState();
    _speakService = LiveSpeakService(_audioService);
    _webrtcService = CloudWebRTCService();
    _initStreams();
  }

  Future<bool> _probeLocalDevice(String ip) async {
    try {
      final socket = await Socket.connect(ip, 81, timeout: const Duration(milliseconds: 1200));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initStreams() async {
    final ip = widget.device.deviceIp;
    bool localReachable = false;

    if (ip != null && ip.isNotEmpty) {
      debugPrint('[Stream] Probing local network reachability at $ip:81...');
      localReachable = await _probeLocalDevice(ip);
    }

    if (!mounted) return;

    if (localReachable) {
      debugPrint('[Stream] Device reachable on same local network! Using direct local mode (low latency).');
      setState(() {
        _isLocalMode = true;
        _useWebRTC = false;
        _isProbing = false;
      });
      _startLocalStream();
    } else {
      debugPrint('[Stream] Device not on same local network. Connecting to Cloud WebRTC relay...');
      setState(() {
        _isLocalMode = false;
        _useWebRTC = true;
        _isProbing = false;
      });
      await _webrtcService.initialize();
      await _webrtcService.connect(widget.device.effectiveStreamId);
      _webrtcService.setAudioEnabled(true);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _running = false;
    _speakService.dispose();
    _client?.close();
    _audioService.disconnect();
    _webrtcService.dispose();
    super.dispose();
  }

  Future<void> _startLocalStream() async {
    final ip = widget.device.deviceIp;
    if (ip == null) return;
    
    _audioService.connect(ip);
    final url = 'http://$ip:81/stream';

    setState(() {
      _running = true;
    });

    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await _client!.send(request).timeout(
            const Duration(seconds: 4),
            onTimeout: () => throw Exception('Local connection timed out'),
          );

      if (response.statusCode != 200) {
        throw Exception('Non-200 HTTP response: ${response.statusCode}');
      }

      final List<int> buf = [];
      await for (final chunk in response.stream) {
        if (!_running) break;
        buf.addAll(chunk);

        int soiIdx = -1;
        for (int i = 0; i < buf.length - 1; i++) {
          if (buf[i] == 0xFF && buf[i + 1] == 0xD8) {
            soiIdx = i;
            break;
          }
        }
        if (soiIdx < 0) {
          if (buf.length > 8192) buf.clear();
          continue;
        }

        int eoiIdx = -1;
        for (int i = soiIdx + 2; i < buf.length - 1; i++) {
          if (buf[i] == 0xFF && buf[i + 1] == 0xD9) {
            eoiIdx = i + 1;
            break;
          }
        }
        if (eoiIdx < 0) continue;

        final frame = Uint8List.fromList(buf.sublist(soiIdx, eoiIdx + 1));
        if (mounted) setState(() => _frame = frame);
        buf.removeRange(0, eoiIdx + 1);
      }
    } catch (err) {
      debugPrint('[Stream] Local stream disconnected: $err');
      if (_running && mounted) {
        debugPrint('[Stream] Auto-switching to Cloud WebRTC relay...');
        setState(() {
          _isLocalMode = false;
          _useWebRTC = true;
        });
        await _webrtcService.initialize();
        await _webrtcService.connect(widget.device.effectiveStreamId);
        _webrtcService.setAudioEnabled(true);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _webrtcService,
      builder: (context, _) {
        final isCloudActive = _useWebRTC && _webrtcService.isConnected;

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle + title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Live Monitor (${widget.device.effectiveStreamId})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Video stream container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child: isCloudActive
                                ? RotatedBox(
                                    quarterTurns: -1,
                                    child: RTCVideoView(
                                      _webrtcService.remoteRenderer,
                                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                    ),
                                  )
                                : (_webrtcService.isConnecting && _useWebRTC)
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircularProgressIndicator(color: Colors.teal),
                                            SizedBox(height: 12),
                                            Text('Connecting to Cloud WebRTC...',
                                                style: TextStyle(color: Colors.white70, fontSize: 13)),
                                          ],
                                        ),
                                      )
                                    : _frame != null
                                        ? RotatedBox(
                                            quarterTurns: -1,
                                            child: Image.memory(_frame!,
                                                fit: BoxFit.contain, gaplessPlayback: true),
                                          )
                                        : Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.videocam_off, color: Colors.white38, size: 36),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _webrtcService.error ?? 'Camera stream connecting...',
                                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),
                                                TextButton.icon(
                                                  onPressed: () {
                                                    _webrtcService.connect(widget.device.effectiveStreamId);
                                                    _startLocalStream();
                                                  },
                                                  icon: const Icon(Icons.refresh, size: 16, color: Colors.teal),
                                                  label: const Text('Retry', style: TextStyle(color: Colors.teal)),
                                                ),
                                              ],
                                            ),
                                          ),
                          ),

                          // Top-left Cloud/Local Mode Badge
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isLocalMode
                                    ? const Color(0xFF047857).withOpacity(0.9)
                                    : (isCloudActive ? Colors.teal[800]!.withOpacity(0.85) : Colors.black54),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isLocalMode ? Icons.home_filled : (isCloudActive ? Icons.cloud_done : Icons.wifi),
                                    color: _isLocalMode ? Colors.white : (isCloudActive ? Colors.greenAccent : Colors.orangeAccent),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isLocalMode
                                        ? (_frame != null ? "Local LAN Direct (Low Latency)" : "Connecting Local...")
                                        : (isCloudActive ? "Cloud 30fps WebRTC" : (_isProbing ? "Checking Network..." : "Connecting")),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Top-right Audio RX Live Indicator & Quick Mute/Unmute
                          Positioned(
                            top: 12,
                            right: 12,
                            child: ListenableBuilder(
                              listenable: _webrtcService,
                              builder: (ctx, _) {
                                final isAudioActive = _webrtcService.isAudioEnabled || _audioService.isConnected;
                                return GestureDetector(
                                  onTap: () {
                                    if (isCloudActive) {
                                      _webrtcService.setAudioEnabled(!_webrtcService.isAudioEnabled);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAudioActive ? Colors.green[700] : Colors.grey[800],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAudioActive ? Icons.volume_up : Icons.volume_off,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isCloudActive
                                              ? (_webrtcService.isAudioEnabled ? "Audio On" : "Audio Muted")
                                              : (_audioService.isConnected ? "UDP Audio" : "Audio Muted"),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Full-Duplex Two-Way Voice Call Button
                ListenableBuilder(
                  listenable: _speakService,
                  builder: (ctx, _) {
                    final isSpeaking = _speakService.isSpeaking;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (isSpeaking) {
                              await _speakService.stopSpeaking(widget.device.deviceId);
                            } else {
                              if (_isLocalMode) {
                                // Direct Local LAN UDP (bypasses cloud relay!)
                                await _speakService.startSpeaking(
                                  widget.device.deviceId,
                                  deviceIp: widget.device.deviceIp,
                                  cloudStreamId: null,
                                );
                              } else {
                                // Cloud Relay WebRTC + Talkback WebSocket
                                await _speakService.startSpeaking(
                                  widget.device.deviceId,
                                  deviceIp: null,
                                  cloudStreamId: widget.device.effectiveStreamId,
                                );
                              }
                            }
                          },
                          onLongPress: () {
                            if (!isSpeaking) {
                              if (_isLocalMode) {
                                _speakService.startSpeaking(
                                  widget.device.deviceId,
                                  deviceIp: widget.device.deviceIp,
                                  cloudStreamId: null,
                                );
                              } else {
                                _webrtcService.setAudioEnabled(true);
                                _speakService.startSpeaking(
                                  widget.device.deviceId,
                                  deviceIp: null,
                                  cloudStreamId: widget.device.effectiveStreamId,
                                );
                              }
                            }
                          },
                          onLongPressEnd: (_) {
                            _speakService.stopSpeaking(widget.device.deviceId);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isSpeaking ? const Color(0xFF10B981) : const Color(0xFF0F766E))
                                      .withOpacity(isSpeaking ? 0.6 : 0.35),
                                  blurRadius: isSpeaking ? 24 : 12,
                                  spreadRadius: isSpeaking ? 4 : 1,
                                ),
                              ],
                              border: Border.all(
                                color: isSpeaking ? Colors.greenAccent : Colors.white24,
                                width: isSpeaking ? 3 : 1.5,
                              ),
                            ),
                            child: Icon(
                              isSpeaking ? Icons.phone_in_talk : Icons.phone,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isSpeaking ? 'Call Active • Speaking & Listening' : 'Tap to Start 2-Way Call',
                          style: TextStyle(
                            color: isSpeaking ? Colors.greenAccent : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSpeaking
                              ? 'Full-Duplex Active • Both Hear Each Other'
                              : 'Continuous Audio On • Tap to Speak',
                          style: TextStyle(
                            color: isSpeaking ? Colors.white70 : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 14),
                
                // Motor Controls (D-Pad)
                const Text('Pan / Tilt Controls', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: () {
                        context.read<DeviceMqttProvider>().sendCommand(widget.device.deviceId, 'motor', {'direction': 'left'});
                      },
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 30),
                          onPressed: () {
                            context.read<DeviceMqttProvider>().sendCommand(widget.device.deviceId, 'motor', {'direction': 'up'});
                          },
                        ),
                        const SizedBox(height: 12),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 30),
                          onPressed: () {
                            context.read<DeviceMqttProvider>().sendCommand(widget.device.deviceId, 'motor', {'direction': 'down'});
                          },
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 30),
                      onPressed: () {
                        context.read<DeviceMqttProvider>().sendCommand(widget.device.deviceId, 'motor', {'direction': 'right'});
                      },
                    ),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Worldwide IoT Relay: ${RelayConfig.host} (${widget.device.effectiveStreamId})',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
