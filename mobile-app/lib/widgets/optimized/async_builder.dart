import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../core/constants.dart';

/// Optimized async data builder with loading, error, empty states
/// Enforces DESIGN_GUIDELINES.md: Every screen must have loading/error/empty states
class AsyncBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final Stream<T>? stream;
  final T? data;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final bool Function(T? data)? isEmpty;
  final VoidCallback? onRetry;

  const AsyncBuilder({
    super.key,
    this.future,
    this.stream,
    this.data,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.isEmpty,
    this.onRetry,
  }) : assert(future != null || stream != null || data != null);

  @override
  Widget build(BuildContext context) {
    if (data != null) {
      return _buildData(context, data as T);
    }

    if (future != null) {
      return FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) => _buildSnapshot(context, snapshot),
      );
    }

    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) => _buildSnapshot(context, snapshot),
    );
  }

  Widget _buildSnapshot(BuildContext context, AsyncSnapshot<T> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildLoading(context);
    }

    if (snapshot.hasError) {
      return _buildError(context, snapshot.error!);
    }

    if (!snapshot.hasData) {
      return _buildEmpty(context);
    }

    return _buildData(context, snapshot.data as T);
  }

  Widget _buildData(BuildContext context, T data) {
    final checkEmpty = isEmpty ?? _defaultIsEmpty;
    if (checkEmpty(data)) {
      return _buildEmpty(context);
    }
    return builder(context, data);
  }

  bool _defaultIsEmpty(T? data) {
    if (data == null) return true;
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }

  Widget _buildLoading(BuildContext context) {
    return loadingBuilder?.call(context) ?? const DefaultLoadingWidget();
  }

  Widget _buildError(BuildContext context, Object error) {
    return errorBuilder?.call(context, error, onRetry ?? () {}) ??
        DefaultErrorWidget(
          error: error.toString(),
          onRetry: onRetry,
        );
  }

  Widget _buildEmpty(BuildContext context) {
    return emptyBuilder?.call(context) ?? const DefaultEmptyWidget();
  }
}

/// Default loading widget with skeleton animation
class DefaultLoadingWidget extends StatelessWidget {
  final String? message;

  const DefaultLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary.withOpacity(0.7),
              ),
            ),
          ),
          if (message != null) ...[
            SizedBox(height: Spacing.md),
            Text(
              message!,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: FontSizes.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Default error widget with retry button
class DefaultErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const DefaultErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: IconSizes.xxl,
              color: AppColors.error.withOpacity(0.7),
            ),
            SizedBox(height: Spacing.lg),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: FontSizes.title,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Spacing.sm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: FontSizes.caption,
                color: AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: Spacing.xl),
              SizedBox(
                height: TouchTarget.comfortable,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Default empty state widget
class DefaultEmptyWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final IconData? icon;
  final Widget? action;

  const DefaultEmptyWidget({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: IconSizes.xxl,
              color: AppColors.textMuted,
            ),
            SizedBox(height: Spacing.lg),
            Text(
              title ?? 'Nothing here yet',
              style: TextStyle(
                fontSize: FontSizes.title,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (message != null) ...[
              SizedBox(height: Spacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: FontSizes.caption,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: Spacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
