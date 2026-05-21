import 'package:flutter/material.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class WallpaperButton extends StatelessWidget {
  const WallpaperButton({
    Key? key,
    required this.onPressed,
    this.isSettingWallpaper = false,
    this.isSuccess = false,
    this.isCropProcessing = false,
    this.isSourceLoading = false,
  }) : super(key: key);

  final VoidCallback? onPressed;
  final bool isSettingWallpaper;
  final bool isSuccess;
  final bool isCropProcessing;
  final bool isSourceLoading;

  @override
  Widget build(BuildContext context) {
    final double targetWidth = (isCropProcessing || isSourceLoading) ? 220 : 70;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: targetWidth,
      height: 60,
      alignment: Alignment.bottomRight,
      child: isSettingWallpaper || isSuccess
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: _circularContainer(isSuccess),
            )
          : SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: (isCropProcessing || isSourceLoading)
                  ? _buildProcessingButton(context)
                  : _buildButton(),
            ),
    );
  }

  Widget _buildButton() => FloatingActionButton(
        elevation: 0.0,
        child: const Icon(Icons.wallpaper),
        backgroundColor: Colors.lightBlue,
        onPressed: onPressed,
      );

  Widget _buildDisabledButton() => const FloatingActionButton(
        elevation: 0.0,
        backgroundColor: Colors.white12,
        onPressed: null,
        child: Icon(Icons.wallpaper, color: Colors.white38),
      );

  Widget _buildProcessingButton(BuildContext context) {
    return FloatingActionButton.extended(
      elevation: 0.0,
      highlightElevation: 0.0,
      backgroundColor: Colors.black54,
      onPressed: null, // Disabled
      icon: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white38),
        ),
      ),
      label: Text(
        AppLocalizations.of(context)!.analysisInProgress,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _circularContainer(bool done) {
    final color = done ? Colors.green : Colors.blue;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.done, size: 50, color: Colors.white)
            : const CircularProgressIndicator(
                color: Colors.white,
              ),
      ),
    );
  }
}
