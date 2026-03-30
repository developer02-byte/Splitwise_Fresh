import 'package:flutter/material.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  bool _hasError = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "We've been notified. Please try restarting the app.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _error = null;
                    });
                  },
                  child: const Text('Try Again'),
                )
              ],
            ),
          ),
        ),
      );
    }
    return ErrorWidgetClass(
      onCatch: (error, stack) {
        setState(() {
          _hasError = true;
          _error = error;
        });
      },
      child: widget.child,
    );
  }
}

class ErrorWidgetClass extends StatefulWidget {
  final Widget child;
  final void Function(Object error, StackTrace stack) onCatch;

  const ErrorWidgetClass({super.key, required this.child, required this.onCatch});

  @override
  State<ErrorWidgetClass> createState() => _ErrorWidgetClassState();
}

class _ErrorWidgetClassState extends State<ErrorWidgetClass> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class RouteErrorBoundary extends StatefulWidget {
  final Widget child;
  final String routeName;

  const RouteErrorBoundary({
    required this.child,
    required this.routeName,
    super.key,
  });

  @override
  State<RouteErrorBoundary> createState() => _RouteErrorBoundaryState();
}

class _RouteErrorBoundaryState extends State<RouteErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Oops, something went wrong here.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() => _hasError = false);
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}
