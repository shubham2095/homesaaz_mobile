// lib/widgets/states.dart
import 'package:flutter/material.dart';

import '../app/tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Hs.med,
      curve: Hs.curve,
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: Hs.blue),
      ),
    ),
  );
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Hs.med,
          curve: Hs.curve,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 12),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Hs.hairline,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: Hs.faint),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Hs.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.cloud_off_rounded,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 42)),
            ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message = 'Nothing to show yet.'});
  final String message;

  @override
  Widget build(BuildContext context) =>
      _StateScaffold(icon: Icons.inbox_rounded, message: message);
}
