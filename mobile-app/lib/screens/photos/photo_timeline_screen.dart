import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/photo_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/photo_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/smart_back_button.dart';
import '../../widgets/photos/photo_card.dart';

/// Photo timeline screen displaying all baby photos
///
/// Features:
/// - Infinite scroll with pagination
/// - "On This Day" memories section
/// - Quick filters (mood, activity, date)
/// - Upload FAB
class PhotoTimelineScreen extends StatefulWidget {
  final String babyId;

  const PhotoTimelineScreen({
    super.key,
    required this.babyId,
  });

  @override
  State<PhotoTimelineScreen> createState() => _PhotoTimelineScreenState();
}

class _PhotoTimelineScreenState extends State<PhotoTimelineScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedMoodFilter;
  String? _selectedActivityFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoProvider>().initialize(widget.babyId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<PhotoProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadMorePhotos();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildUploadFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: DesignTokens.surfaceWhite,
      elevation: 0,
      leading: const SmartBackButton(fallbackRoute: '/dashboard'),
      title: const Text(
        'Photos',
        style: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: DesignTokens.fontSizeXl,
          fontWeight: DesignTokens.fontWeightSemiBold,
        ),
      ),
      actions: [
        // Search button
        IconButton(
          icon: const Icon(Icons.search, color: DesignTokens.textSecondary),
          onPressed: _openSearch,
        ),
        // Albums button
        IconButton(
          icon: const Icon(Icons.photo_album_outlined,
              color: DesignTokens.textSecondary),
          onPressed: _openAlbums,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<PhotoProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.photos.isEmpty) {
          return _buildLoadingState();
        }

        if (provider.error != null && provider.photos.isEmpty) {
          return _buildErrorState(provider.error!);
        }

        if (provider.photos.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: DesignTokens.primaryTeal,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // "On This Day" section
              if (provider.onThisDayPhotos.isNotEmpty)
                _buildOnThisDaySection(provider.onThisDayPhotos),

              // Filters
              SliverToBoxAdapter(child: _buildFilters()),

              // Photos list
              _buildPhotosList(provider),

              // Loading indicator at bottom
              if (provider.isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(DesignTokens.spaceLg),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: DesignTokens.primaryTeal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOnThisDaySection(List<PhotoModel> photos) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(DesignTokens.spaceLg),
        padding: const EdgeInsets.all(DesignTokens.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DesignTokens.primaryTeal.withOpacity(0.1),
              DesignTokens.accentBlue.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          border: Border.all(
            color: DesignTokens.primaryTeal.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: DesignTokens.primaryTeal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: DesignTokens.primaryTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceMd),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'On This Day',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeMd,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                          color: DesignTokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Memories from previous years',
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _viewAllMemories(photos),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceMd),

            // Photo thumbnails
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length.clamp(0, 5),
                separatorBuilder: (_, __) =>
                    const SizedBox(width: DesignTokens.spaceSm),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return GestureDetector(
                    onTap: () => _openPhotoDetail(photo),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                      child: Image.network(
                        photo.thumbnailUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80,
                          height: 80,
                          color: DesignTokens.neutralGray200,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceLg,
        vertical: DesignTokens.spaceSm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mood filter
            _buildFilterChip(
              label: _selectedMoodFilter ?? 'Mood',
              icon: Icons.sentiment_satisfied_alt,
              isSelected: _selectedMoodFilter != null,
              onTap: _showMoodFilterSheet,
            ),
            const SizedBox(width: DesignTokens.spaceSm),

            // Activity filter
            _buildFilterChip(
              label: _selectedActivityFilter ?? 'Activity',
              icon: Icons.local_activity,
              isSelected: _selectedActivityFilter != null,
              onTap: _showActivityFilterSheet,
            ),
            const SizedBox(width: DesignTokens.spaceSm),

            // Date filter
            _buildFilterChip(
              label: 'Date Range',
              icon: Icons.calendar_today,
              isSelected: false,
              onTap: _showDateFilterSheet,
            ),

            // Clear filters
            if (_selectedMoodFilter != null || _selectedActivityFilter != null)
              Padding(
                padding: const EdgeInsets.only(left: DesignTokens.spaceSm),
                child: TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.spaceMd,
          vertical: DesignTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? DesignTokens.primaryTeal.withOpacity(0.1)
              : DesignTokens.surfaceWhite,
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          border: Border.all(
            color: isSelected
                ? DesignTokens.primaryTeal
                : DesignTokens.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? DesignTokens.primaryTeal
                  : DesignTokens.textSecondary,
            ),
            const SizedBox(width: DesignTokens.spaceXs),
            Text(
              label,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: isSelected
                    ? DesignTokens.primaryTeal
                    : DesignTokens.textSecondary,
                fontWeight: isSelected
                    ? DesignTokens.fontWeightSemiBold
                    : DesignTokens.fontWeightRegular,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: DesignTokens.spaceXs),
              Icon(
                Icons.close,
                size: 14,
                color: DesignTokens.primaryTeal,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosList(PhotoProvider provider) {
    final photos = _getFilteredPhotos(provider.photos);
    final groupedPhotos = _groupPhotosByDate(photos);
    final dates = groupedPhotos.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final date = dates[index];
          final datePhotos = groupedPhotos[date]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DesignTokens.spaceLg,
                  DesignTokens.spaceLg,
                  DesignTokens.spaceLg,
                  DesignTokens.spaceSm,
                ),
                child: Text(
                  _formatDateHeader(date),
                  style: const TextStyle(
                    fontSize: DesignTokens.fontSizeMd,
                    fontWeight: DesignTokens.fontWeightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
              ),

              // Photos for this date
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                    horizontal: DesignTokens.spaceLg),
                itemCount: datePhotos.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: DesignTokens.spaceMd),
                itemBuilder: (context, photoIndex) {
                  final photo = datePhotos[photoIndex];
                  final userId = context.read<AuthProvider>().currentUser?.uid;

                  return PhotoCard(
                    photo: photo,
                    currentUserId: userId,
                    onTap: () => _openPhotoDetail(photo),
                    onLike: (userId) {
                      provider.toggleLike(photo.id, userId);
                    },
                  );
                },
              ),
            ],
          );
        },
        childCount: dates.length,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: DesignTokens.primaryTeal),
          SizedBox(height: DesignTokens.spaceMd),
          Text(
            'Loading photos...',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: DesignTokens.fontSizeMd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: DesignTokens.statusCritical,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            const Text(
              'Failed to load photos',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: DesignTokens.fontSizeSm,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton(
              onPressed: () {
                context.read<PhotoProvider>().refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(DesignTokens.spaceLg),
              decoration: BoxDecoration(
                color: DesignTokens.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_outlined,
                size: 48,
                color: DesignTokens.primaryTeal,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'No photos yet',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSm),
            const Text(
              'Capture precious moments with your baby.\nPhotos will include vitals data at the time of capture.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: DesignTokens.fontSizeSm,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: _openUpload,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add First Photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadFAB() {
    return Consumer<PhotoProvider>(
      builder: (context, provider, _) {
        if (provider.isUploading) {
          return FloatingActionButton(
            onPressed: null,
            backgroundColor: DesignTokens.primaryTeal,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: provider.uploadProgress,
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }

        return FloatingActionButton(
          onPressed: _openUpload,
          backgroundColor: DesignTokens.primaryTeal,
          child: const Icon(Icons.add_a_photo, color: Colors.white),
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  List<PhotoModel> _getFilteredPhotos(List<PhotoModel> photos) {
    var filtered = photos;

    if (_selectedMoodFilter != null) {
      filtered =
          filtered.where((p) => p.aiTags.mood == _selectedMoodFilter).toList();
    }

    if (_selectedActivityFilter != null) {
      filtered = filtered
          .where((p) => p.aiTags.activity == _selectedActivityFilter)
          .toList();
    }

    return filtered;
  }

  Map<DateTime, List<PhotoModel>> _groupPhotosByDate(List<PhotoModel> photos) {
    final grouped = <DateTime, List<PhotoModel>>{};

    for (final photo in photos) {
      final date = DateTime(
        photo.capturedAt.year,
        photo.capturedAt.month,
        photo.capturedAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(photo);
    }

    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      const days = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
      ];
      return days[date.weekday % 7];
    } else {
      return '${_monthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openPhotoDetail(PhotoModel photo) {
    // TODO: Navigate to photo detail screen
    // context.push('/photos/${photo.id}', extra: photo);
  }

  void _openUpload() {
    // TODO: Navigate to upload screen or show bottom sheet
    // context.push('/photos/upload');
    _showUploadOptions();
  }

  void _openSearch() {
    // TODO: Navigate to search screen
    // context.push('/photos/search');
  }

  void _openAlbums() {
    // TODO: Navigate to albums screen
    // context.push('/photos/albums');
  }

  void _viewAllMemories(List<PhotoModel> photos) {
    // TODO: Navigate to memories screen
  }

  // ============================================================
  // BOTTOM SHEETS
  // ============================================================

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.neutralGray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'Add Photo',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceSm),
                decoration: BoxDecoration(
                  color: DesignTokens.primaryTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Icon(Icons.camera_alt,
                    color: DesignTokens.primaryTeal),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Capture a new moment'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open camera
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(DesignTokens.spaceSm),
                decoration: BoxDecoration(
                  color: DesignTokens.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                ),
                child: const Icon(Icons.photo_library,
                    color: DesignTokens.accentBlue),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photos'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open gallery picker
              },
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
      ),
    );
  }

  void _showMoodFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Mood',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: PhotoMood.all.where((m) => m != 'unknown').map((mood) {
                return ChoiceChip(
                  label: Text('${_getMoodEmoji(mood)} $mood'),
                  selected: _selectedMoodFilter == mood,
                  onSelected: (selected) {
                    setState(() {
                      _selectedMoodFilter = selected ? mood : null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
      ),
    );
  }

  void _showActivityFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Activity',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Wrap(
              spacing: DesignTokens.spaceSm,
              runSpacing: DesignTokens.spaceSm,
              children: PhotoActivity.all
                  .where((a) => a != 'unknown')
                  .map((activity) {
                return ChoiceChip(
                  label: Text('${_getActivityEmoji(activity)} $activity'),
                  selected: _selectedActivityFilter == activity,
                  onSelected: (selected) {
                    setState(() {
                      _selectedActivityFilter = selected ? activity : null;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: DesignTokens.spaceMd),
          ],
        ),
      ),
    );
  }

  void _showDateFilterSheet() {
    // TODO: Implement date range picker
  }

  void _clearFilters() {
    setState(() {
      _selectedMoodFilter = null;
      _selectedActivityFilter = null;
    });
  }

  String _getMoodEmoji(String mood) {
    switch (mood) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'crying':
        return '😢';
      case 'sleeping':
        return '😴';
      case 'alert':
        return '👀';
      default:
        return '📷';
    }
  }

  String _getActivityEmoji(String activity) {
    switch (activity) {
      case 'feeding':
        return '🍼';
      case 'playing':
        return '🎮';
      case 'sleeping':
        return '🛏️';
      case 'bath':
        return '🛁';
      case 'tummy_time':
        return '🤸';
      case 'outdoor':
        return '🌳';
      default:
        return '📷';
    }
  }
}
