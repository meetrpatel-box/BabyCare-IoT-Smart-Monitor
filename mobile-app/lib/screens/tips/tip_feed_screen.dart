import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/tip_model.dart';
import '../../providers/tip_provider.dart';
import '../../providers/baby_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/tips/tip_card.dart';
import '../../widgets/common/smart_back_button.dart';

/// Feed screen showing parenting tips
/// Displays tips with Tip of the Day, filtering, and feedback tracking
class TipFeedScreen extends StatefulWidget {
  final String babyId;

  const TipFeedScreen({
    super.key,
    required this.babyId,
  });

  @override
  State<TipFeedScreen> createState() => _TipFeedScreenState();
}

class _TipFeedScreenState extends State<TipFeedScreen> {
  TipCategory? _selectedCategory;
  bool _showDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTips();
    });
  }

  Future<void> _loadTips() async {
    if (!mounted) return;
    final tipProvider = context.read<TipProvider>();
    final babyProvider = context.read<BabyProvider>();
    final baby = babyProvider.babies.where((b) => b.id == widget.babyId).firstOrNull;
    final ageInMonths = baby?.ageInMonths ?? 0;
    await tipProvider.loadTips(widget.babyId, ageInMonths);
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
          baby != null ? '${baby.name}\'s Tips' : 'Parenting Tips',
          style: const TextStyle(
            fontSize: DesignTokens.fontSizeXl,
            fontWeight: DesignTokens.fontWeightSemiBold,
            color: DesignTokens.textPrimary,
          ),
        ),
        actions: [
          // Toggle show/hide dismissed tips
          IconButton(
            icon: Icon(
              _showDismissed ? Icons.visibility_off : Icons.visibility,
              color: DesignTokens.primaryTeal,
            ),
            onPressed: () => setState(() => _showDismissed = !_showDismissed),
            tooltip: _showDismissed ? 'Hide Dismissed' : 'Show Dismissed',
          ),
        ],
      ),
      body: Consumer<TipProvider>(
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
                  const Text(
                    'Error loading tips',
                    style: TextStyle(
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
                    onPressed: _loadTips,
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

          final tips = _getFilteredTips(provider);

          if (tips.isEmpty && provider.tips.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Tip of the Day (if available)
              if (provider.tipOfTheDay != null && !_showDismissed)
                _buildTipOfTheDay(provider),

              // Category filter chips
              _buildCategoryFilter(provider),

              // Tips list
              Expanded(
                child: tips.isEmpty
                    ? _buildNoResultsState()
                    : RefreshIndicator(
                        onRefresh: _loadTips,
                        color: DesignTokens.primaryTeal,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(DesignTokens.spaceMd),
                          itemCount: tips.length,
                          itemBuilder: (context, index) {
                            final tip = tips[index];
                            final isDismissed = provider.isTipDismissed(tip.id);
                            final isHelpful = provider.getTipHelpfulness(tip.id);

                            return TipCard(
                              tip: tip,
                              isDismissed: isDismissed,
                              isHelpful: isHelpful,
                              onMarkHelpful: () =>
                                  _markHelpful(provider, tip.id, true),
                              onMarkNotHelpful: () =>
                                  _markHelpful(provider, tip.id, false),
                              onDismiss: () => _dismissTip(provider, tip.id),
                              onUndismiss: () =>
                                  _undismissTip(provider, tip.id),
                              onTap: () => _showTipDetails(tip),
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

  Widget _buildTipOfTheDay(TipProvider provider) {
    final tip = provider.tipOfTheDay!;

    return Container(
      margin: const EdgeInsets.all(DesignTokens.spaceMd),
      padding: const EdgeInsets.all(DesignTokens.spaceLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DesignTokens.accentPurple, DesignTokens.primaryTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: DesignTokens.accentPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.wb_sunny,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: DesignTokens.spaceXs),
              const Text(
                'Tip of the Day',
                style: TextStyle(
                  fontSize: DesignTokens.fontSizeLg,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spaceMd),
          Text(
            tip.title,
            style: const TextStyle(
              fontSize: DesignTokens.fontSizeLg,
              fontWeight: DesignTokens.fontWeightSemiBold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DesignTokens.spaceXs),
          Text(
            tip.content,
            style: TextStyle(
              fontSize: DesignTokens.fontSizeSm,
              color: Colors.white.withOpacity(0.95),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(TipProvider provider) {
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
            count: _showDismissed
                ? provider.tips.length
                : provider.activeTips.length,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          const SizedBox(width: DesignTokens.spaceXs),
          // Category filters
          ...TipCategory.values.map((category) {
            final allCategoryTips = provider.getTipsByCategory(category);
            final visibleTips = _showDismissed
                ? allCategoryTips
                : allCategoryTips
                    .where((t) => !provider.isTipDismissed(t.id))
                    .toList();

            if (visibleTips.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(right: DesignTokens.spaceXs),
              child: _buildFilterChip(
                label: category.displayName,
                count: visibleTips.length,
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
                color: DesignTokens.accentPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                size: 64,
                color: DesignTokens.accentPurple,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            const Text(
              'No Tips Available',
              style: TextStyle(
                fontSize: DesignTokens.fontSizeXl,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXs),
            const Text(
              'Check back soon for helpful parenting tips\ntailored to your baby\'s age',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLg),
            ElevatedButton.icon(
              onPressed: _loadTips,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spaceLg,
                  vertical: DesignTokens.spaceMd,
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off,
              size: 64,
              color: DesignTokens.neutralGray400,
            ),
            const SizedBox(height: DesignTokens.spaceMd),
            Text(
              _showDismissed ? 'No Dismissed Tips' : 'No Tips in This Category',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeLg,
                fontWeight: DesignTokens.fontWeightSemiBold,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXs),
            Text(
              _showDismissed
                  ? 'You haven\'t dismissed any tips yet'
                  : 'Try selecting a different category',
              style: const TextStyle(
                fontSize: DesignTokens.fontSizeSm,
                color: DesignTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TipModel> _getFilteredTips(TipProvider provider) {
    List<TipModel> tips;

    // Apply category filter
    if (_selectedCategory == null) {
      tips = provider.tips;
    } else {
      tips = provider.getTipsByCategory(_selectedCategory!);
    }

    // Apply dismissed filter
    if (!_showDismissed) {
      tips = tips.where((tip) => !provider.isTipDismissed(tip.id)).toList();
    }

    return tips;
  }

  void _showTipDetails(TipModel tip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusLg),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(DesignTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: DesignTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: DesignTokens.neutralGray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Category and priority badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spaceXs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(tip.category).withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tip.category.icon,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tip.category.displayName,
                          style: TextStyle(
                            fontSize: DesignTokens.fontSizeXs,
                            fontWeight: DesignTokens.fontWeightMedium,
                            color: _getCategoryColor(tip.category),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tip.priority == TipPriority.high ||
                      tip.priority == TipPriority.urgent) ...[
                    const SizedBox(width: DesignTokens.spaceXs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (tip.priority == TipPriority.urgent
                                ? DesignTokens.statusCritical
                                : DesignTokens.statusWarning)
                            .withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm),
                      ),
                      child: Text(
                        tip.priority.displayName,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeXs,
                          fontWeight: DesignTokens.fontWeightSemiBold,
                          color: tip.priority == TipPriority.urgent
                              ? DesignTokens.statusCritical
                              : DesignTokens.statusWarning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: DesignTokens.spaceMd),

              // Title
              Text(
                tip.title,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeXl,
                  fontWeight: DesignTokens.fontWeightBold,
                  color: DesignTokens.textPrimary,
                ),
              ),

              const SizedBox(height: DesignTokens.spaceMd),

              // Content
              Text(
                tip.content,
                style: const TextStyle(
                  fontSize: DesignTokens.fontSizeMd,
                  color: DesignTokens.textSecondary,
                  height: 1.6,
                ),
              ),

              // Tags
              if (tip.tags.isNotEmpty) ...[
                const SizedBox(height: DesignTokens.spaceLg),
                Wrap(
                  spacing: DesignTokens.spaceXs,
                  runSpacing: DesignTokens.spaceXs,
                  children: tip.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spaceXs,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: DesignTokens.neutralGray100,
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radiusSm),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          fontSize: DesignTokens.fontSizeSm,
                          color: DesignTokens.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Source URL
              if (tip.sourceUrl != null) ...[
                const SizedBox(height: DesignTokens.spaceLg),
                InkWell(
                  onTap: () {
                    // TODO: Launch URL
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Open: ${tip.sourceUrl}'),
                        backgroundColor: DesignTokens.primaryTeal,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 18,
                        color: DesignTokens.primaryTeal,
                      ),
                      const SizedBox(width: DesignTokens.spaceXs),
                      Expanded(
                        child: Text(
                          tip.sourceUrl!,
                          style: const TextStyle(
                            fontSize: DesignTokens.fontSizeSm,
                            color: DesignTokens.primaryTeal,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // AI Generated indicator
              if (tip.isAiGenerated) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: DesignTokens.accentPurple.withOpacity(0.6),
                    ),
                    const SizedBox(width: DesignTokens.spaceXs),
                    Text(
                      'AI Generated • Verify with your pediatrician',
                      style: TextStyle(
                        fontSize: DesignTokens.fontSizeXs,
                        color: DesignTokens.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: DesignTokens.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markHelpful(
      TipProvider provider, String tipId, bool helpful) async {
    await provider.markTipHelpful(tipId, helpful);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(helpful ? 'Marked as helpful' : 'Marked as not helpful'),
          backgroundColor: DesignTokens.primaryTeal,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _dismissTip(TipProvider provider, String tipId) async {
    await provider.dismissTip(tipId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tip dismissed'),
          backgroundColor: DesignTokens.neutralGray600,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _undismissTip(TipProvider provider, String tipId) async {
    await provider.undismissTip(tipId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tip restored'),
          backgroundColor: DesignTokens.statusHealthy,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Color _getCategoryColor(TipCategory category) {
    switch (category) {
      case TipCategory.sleep:
        return DesignTokens.statusSleeping;
      case TipCategory.feeding:
        return DesignTokens.accentGreen;
      case TipCategory.health:
        return DesignTokens.statusCritical;
      case TipCategory.safety:
        return DesignTokens.statusWarning;
      case TipCategory.development:
        return DesignTokens.accentPurple;
      case TipCategory.behavior:
        return DesignTokens.accentBlue;
      case TipCategory.care:
        return DesignTokens.accentPink;
      case TipCategory.bonding:
        return DesignTokens.accentYellow;
      case TipCategory.general:
        return DesignTokens.neutralGray400;
    }
  }
}
