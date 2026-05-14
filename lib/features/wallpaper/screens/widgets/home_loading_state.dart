import 'package:flutter/material.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class HomeLoadingState extends StatelessWidget {
  const HomeLoadingState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.optimizingWallpapers,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.analyzingForCrop,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
