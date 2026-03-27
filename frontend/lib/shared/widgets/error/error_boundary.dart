import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/dimensions.dart';

/// Global Error Boundary Widget — wraps any screen to intercept and display
/// full-page error states gracefully (matches Error_Contract.md).
class ErrorBoundary extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.error,
    this.stackTrace,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final errorMessage = _humanReadableError(error);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(kSpacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: kSpacingL),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: kSpacingS),
              Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: kSpacingXL),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _humanReadableError(Object error) {
    final raw = error.toString();
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.contains('401') || raw.contains('Unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }
    if (raw.contains('403') || raw.contains('Forbidden')) {
      return 'You don\'t have permission to do that.';
    }
    if (raw.contains('404')) {
      return 'The requested item could not be found.';
    }
    if (raw.contains('500') || raw.contains('SERVER_ERROR')) {
      return 'Our servers hit a snag. We\'re on it — please try again shortly.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'The request took too long. Check your connection and retry.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

/// Extension on AsyncValue to simplify error/loading/data widget trees
extension AsyncValueUI<T> on AsyncValue<T> {
  Widget whenWidget({
    required Widget Function(T data) data,
    Widget Function()? loading,
    Widget Function(Object error, StackTrace? st)? error,
  }) {
    return when(
      loading: loading ?? () => const Center(child: CircularProgressIndicator()),
      error: error ?? (err, st) => ErrorBoundary(error: err, stackTrace: st),
      data: data,
    );
  }
}
