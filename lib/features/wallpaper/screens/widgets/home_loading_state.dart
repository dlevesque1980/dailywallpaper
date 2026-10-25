import 'package:flutter/material.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class HomeLoadingState extends StatelessWidget {
  const HomeLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingWallpapers,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
