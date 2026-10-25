import 'package:flutter/material.dart';

class WallpaperButton extends StatelessWidget {
  const WallpaperButton({
    super.key,
    required this.onPressed,
    this.isSettingWallpaper = false,
    this.isSuccess = false,
  });

  final VoidCallback? onPressed;
  final bool isSettingWallpaper;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 70,
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
              child: _buildButton(),
            ),
    );
  }

  Widget _buildButton() => FloatingActionButton(
        elevation: 0.0,
        backgroundColor: Colors.lightBlue,
        onPressed: onPressed,
        child: const Icon(Icons.wallpaper),
      );

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
