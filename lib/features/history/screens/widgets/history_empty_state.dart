import 'package:flutter/material.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';

class HistoryEmptyState extends StatelessWidget {
  final HistoryState state;
  final bool isToday;
  final String formattedDate;
  final Function(DateTime) onDateSelected;

  const HistoryEmptyState({
    Key? key,
    required this.state,
    required this.isToday,
    required this.formattedDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noImagesAvailable,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isToday
                  ? AppLocalizations.of(context)!.noWallpapersDownloadedToday
                  : AppLocalizations.of(context)!.noWallpapersSavedForDate(formattedDate),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            if (state.availableDates.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (isToday) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.goToHome),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  final mostRecentDate = state.availableDates.reduce(
                    (a, b) => a.isAfter(b) ? a : b,
                  );
                  onDateSelected(mostRecentDate);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(AppLocalizations.of(context)!.viewRecentImages),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.noHistoricalImagesFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.goToHome),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
