import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../theme/app_colors.dart';
import 'skeleton.dart';

/// High-performance list with virtualization, pull-to-refresh, and pagination
/// See DESIGN_GUIDELINES.md: Lists use virtualization, 60fps always

class OptimizedList<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool isLoading;
  final bool hasMore;
  final Widget? emptyWidget;
  final Widget? loadingWidget;
  final Widget? separatorBuilder;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const OptimizedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onRefresh,
    this.onLoadMore,
    this.isLoading = false,
    this.hasMore = false,
    this.emptyWidget,
    this.loadingWidget,
    this.separatorBuilder,
    this.padding,
    this.controller,
    this.physics,
  });

  @override
  State<OptimizedList<T>> createState() => _OptimizedListState<T>();
}

class _OptimizedListState<T> extends State<OptimizedList<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore || widget.onLoadMore == null) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = ListConstants.loadMoreThreshold;

    if (maxScroll - currentScroll <= threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading state
    if (widget.isLoading && widget.items.isEmpty) {
      return widget.loadingWidget ?? _buildLoadingSkeleton();
    }

    // Empty state
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? _buildEmptyState();
    }

    // Build list with refresh
    Widget list = ListView.builder(
      controller: _scrollController,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
      // Performance: cache more items for smooth scrolling
      cacheExtent: ListConstants.cacheExtent,
      // Performance: use itemExtent if all items are same height
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.items.length) {
          return _buildLoadMoreIndicator();
        }

        final item = widget.items[index];

        // Wrap in RepaintBoundary for isolation
        return RepaintBoundary(
          child: widget.separatorBuilder != null && index > 0
              ? Column(
                  children: [
                    widget.separatorBuilder!,
                    widget.itemBuilder(context, item, index),
                  ],
                )
              : widget.itemBuilder(context, item, index),
        );
      },
    );

    // Wrap with RefreshIndicator if refresh is enabled
    if (widget.onRefresh != null) {
      list = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        color: AppColors.primary,
        child: list,
      );
    }

    return list;
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: widget.padding ?? EdgeInsets.all(Spacing.lg),
      itemCount: 5,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: SkeletonListItem(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: IconSizes.xxl,
              color: AppColors.textMuted,
            ),
            SizedBox(height: Spacing.lg),
            Text(
              'Nothing here yet',
              style: TextStyle(
                fontSize: FontSizes.title,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: EdgeInsets.all(Spacing.lg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Optimized grid for cards
class OptimizedGrid<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final int crossAxisCount;
  final double spacing;
  final EdgeInsets? padding;
  final bool isLoading;
  final Widget? emptyWidget;

  const OptimizedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.spacing = Spacing.md,
    this.padding,
    this.isLoading = false,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return _buildLoadingSkeleton();
    }

    if (items.isEmpty) {
      return emptyWidget ?? const SizedBox();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.all(Spacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: itemBuilder(context, items[index], index),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding ?? EdgeInsets.all(Spacing.lg),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => const SkeletonVitalCard(),
    );
  }
}
