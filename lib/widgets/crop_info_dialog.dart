import 'package:flutter/material.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class CropInfoDialog extends StatelessWidget {
  final ImageItem image;

  const CropInfoDialog({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final result = image.smartCropResult;
    if (result == null) {
      return AlertDialog(
        content: Text(AppLocalizations.of(context)!.analysisInProgress),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      );
    }

    final crop = result.bestCrop;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.blue),
          const SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.cropAnalysis),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(context, AppLocalizations.of(context)!.strategy, crop.strategy),
          _infoRow(context, AppLocalizations.of(context)!.confidence,
              '${(crop.confidence * 100).toStringAsFixed(1)}%'),
          _infoRow(context, AppLocalizations.of(context)!.targetAspect,
              (crop.width / crop.height).toStringAsFixed(2)),
          const Divider(),
          Text(AppLocalizations.of(context)!.coordinatesNormalized,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          _infoRow(context, 'X / Y',
              '${crop.x.toStringAsFixed(3)} / ${crop.y.toStringAsFixed(3)}'),
          _infoRow(context, 'W / H',
              '${crop.width.toStringAsFixed(3)} / ${crop.height.toStringAsFixed(3)}'),
          if (crop.subjectBounds != null) ...[
            const Divider(),
            Text(AppLocalizations.of(context)!.subjectDetection,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            _infoRow(context, AppLocalizations.of(context)!.bounds,
                '${crop.subjectBounds!.width.toStringAsFixed(2)}x${crop.subjectBounds!.height.toStringAsFixed(2)}'),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.close),
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
