import 'package:flutter/material.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';

class HistoryErrorState extends StatelessWidget {
  final HistoryState state;
  final String error;
  final String translatedMessage;
  final Function(DateTime) onRetry;

  const HistoryErrorState({
    super.key,
    required this.state,
    required this.error,
    required this.translatedMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isNetworkError = error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection') ||
        error.toLowerCase().contains('supabase');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNetworkError ? Icons.wifi_off_outlined : Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              isNetworkError
                  ? AppLocalizations.of(context)!.connectionError
                  : AppLocalizations.of(context)!.error,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              translatedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    onRetry(state.selectedDate);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.retry),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.home),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
