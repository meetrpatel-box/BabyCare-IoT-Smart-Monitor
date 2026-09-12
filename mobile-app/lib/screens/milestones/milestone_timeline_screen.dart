import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/milestone_model.dart';
import '../../providers/milestone_provider.dart';
import '../../providers/baby_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/milestones/milestone_card.dart';
import '../../widgets/common/smart_back_button.dart';

/// Timeline screen showing baby's milestones
/// Displays milestones chronologically with filtering options
class MilestoneTimelineScreen extends StatefulWidget {
  final String babyId;

  const MilestoneTimelineScreen({
    super.key,
    required this.babyId,
  });

  @override
  State<MilestoneTimelineScreen> createState() =>
      _MilestoneTimelineScreenState();
}

class _MilestoneTimelineScreenState extends State<MilestoneTimelineScreen> {
  MilestoneCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMilestones();
    });
  }

  Future<void> _loadMilestones() async {
    if (!mounted) return;
    final milestoneProvider = context.read<MilestoneProvider>();
    await milestoneProvider.loadMilestones(widget.babyId);
  }

  @override
  Widget build(BuildContext context) {
    final babyProvider = context.watch<BabyProvider>();
    final baby =
        babyProvider.babies.where((b) => b.id == widget.babyId).firstOrNull;

    return Scaffold(
      backgroundColor: DesignTokens.backgroundWarm,
      appBar: AppBar(
        backgroundColor: DesignTokens.backgroundWarm,
        elevation: 0,
        leading: const SmartBackButton(),
        title: Text(
          baby != null ? '${baby.name}\'s Milestones' : 'Milestones',
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXl,
            fontWeight: DesignTokens.fontWeightSemiBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: DesignTokens.primaryTeal),
            onPressed: () => _showAddMilestoneDialog(),
            tooltip: 'Add Milestone',
          ),
        ],
      ),
      body: Consumer<MilestoneProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(DesignTokens.primaryTeal),
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: DesignTokens.statusCritical,
                  ),
                  const SizedBox(height: DesignTokens.spaceMd),
                  Text(
                    'Error loading milestones',
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeLg,
                      fontWeight: DesignTokens.fontWeightSemiBold,
                      color: DesignTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXs),
                  Text(
                    provider.error!,
                    style: const TextStyle(
                      fontSize: DesignTokens.fontSizeSm,
                      color: DesignTokens.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignTokens.spaceLg),
                  ElevatedButton(
                    onPressed: _loadMilestones,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.primaryTeal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final milestones = _selectedCategory == null
              ? provider.milestones
              : provider.getMilestonesByCategory(_selectedCategory!);

          if (milestones.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Category filter chips
              _buildCategoryFilter(provider),

              // Statistics card
              _buildStatisticsCard(provider, baby),

              // Milestones list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadMilestones,
                  color: DesignTokens.primaryTeal,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(DesignTokens.spaceMd),
                    itemCount: milestones.length,
                    itemBuilder: (context, index) {
                      final milestone = milestones[index];
                      return MilestoneCard(
                        milestone: milestone,
                        onTap: () => _showMilestoneDetails(milestone),
                        onEdit: () => _showEditMilestoneDialog(milestone),
                        onDelete: () => _confirmDeleteMilestone(milestone),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryFilter(MilestoneProvider provider) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: DesignTokens.spaceSm),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spaceMd),
        children: [
          // All filter
          _buildFilterChip(
            label: 'All',
            count: provider.milestones.length,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          // Category filters
          ...MilestoneCategory.values.map((category) {
            final count = provider.getMilestonesByCategory(category).length;
            if (count == 0) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(right: DesignTokens.spaceXs),
              child: _buildFilterChip(
                label: category.displayName,
                count: count,
                isSelected: _selectedCategory == category,
                onTap: () => setState(() => _selectedCategory = category),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: DesignTokens.surfaceWhite,
      selectedColor: DesignTokens.primaryTeal.withOpacity(0.1),
      checkmarkColor: DesignTokens.primaryTeal,
      labelStyle: TextStyle(
        fontSize: DesignTokens.fontSizeSm,
        fontWeight: isSelected
            ? DesignTokens.fontWeightSemiBold
            : DesignTokens.fontWeightMedium,
        color:
            isSelected ? DesignTokens.primaryTeal : DesignTokens.textSecondary,
      ),
      side: BorderSide(
        color:
            isSelected ? DesignTokens.primaryTeal : DesignTokens.neutralGray200,
      ),
    );
  }

  Widget _buildStatisticsCard(MilestoneProvider provider, baby) {
    final ageInMonths = baby != null
        ? DateTime.now().difference(baby.dateOfBirth).inDays ~/ 30
        : 0;
    final completionPercentage = provider.getCompletionPercentage(ageInMonths);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spaceMd,
        vertical: DesignTokens.spaceXs,
      ),
      padding: const EdgeInsets.all(DesignTokens.spaceMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignTokens.primaryTeal, DesignTokens.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Total',
                value: provider.totalCount.toString(),
                icon: Icons.emoji_events,
              ),
              _buildStatItem(
                label: 'Completed',
                value: provider.completedCount.toString(),
                icon: Icons.check_circle,
              ),
              _buildStatItem(
                label: 'Progress',
                value: '${completionPercentage.toInt()}%',
                icon: Icons.trending_up,
              ),
            ],
          ),
          if (completionPercentage > 0) ...[
            const SizedBox(height: DesignTokens.spaceMd),
            ClipRRect(
              borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
              child: LinearProgressIndicator(
                value: completionPercentage / 100,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: DesignTokens.spaceXs),
        Text(
          value,
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXl,
            fontWeight: DesignTokens.fontWeightBold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: DesignTokens.fontSizeXs,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
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
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: DesignTokens.primaryTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: DesignTokens.primaryTeal,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'No Milestones Yet',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXl,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXs),
            const Text(
              'Start tracking your baby\'s special moments\nand achievements',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: _showAddMilestoneDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLg,
                  vertical: DesignTokens.spaceMd,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add First Milestone'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMilestoneDetails(MilestoneModel milestone) {
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
            Text(
              milestone.title,
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeXl,
                fontWeight: DesignTokens.fontWeightBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            if (milestone.description != null) ...[
              const SizedBox(height: DesignTokens.spaceSm),
              Text(
                milestone.description!,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeMd,
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: DesignTokens.spaceMd),
            // Additional details can go here
          ],
        ),
      ),
    );
  }

  void _showAddMilestoneDialog() {
    // TODO: Implement add milestone dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add milestone dialog - Coming soon'),
        backgroundColor: DesignTokens.primaryTeal,
      ),
    );
  }

  void _showEditMilestoneDialog(MilestoneModel milestone) {
    // TODO: Implement edit milestone dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit "${milestone.title}" - Coming soon'),
        backgroundColor: DesignTokens.primaryTeal,
      ),
    );
  }

  Future<void> _confirmDeleteMilestone(MilestoneModel milestone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Milestone?'),
        content: Text('Are you sure you want to delete "${milestone.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: DesignTokens.statusCritical,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<MilestoneProvider>();
      await provider.deleteMilestone(milestone.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone deleted'),
            backgroundColor: DesignTokens.statusHealthy,
          ),
        );
      }
    }
  }
}
