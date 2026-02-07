import 'package:flutter/material.dart';
import '../utils/widget_keys.dart';

// CP: Minimal screen shown when offline on first launch
class ConnectRequiredScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isRetrying;
  final String? errorMessage;

  const ConnectRequiredScreen({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                errorMessage == null ? Icons.wifi_off : Icons.error_outline,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                errorMessage == null ? 'Connection Required' : 'Setup Failed',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? 'Please connect to the internet to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 140,
                height: 48,
                child: ElevatedButton(
                  key: connectRequiredRetryButton,
                  onPressed: isRetrying ? null : onRetry,
                  child: isRetrying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
