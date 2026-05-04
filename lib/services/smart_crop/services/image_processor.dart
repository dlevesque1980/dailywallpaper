import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/utils/post_crop_scaler.dart';

class ImageProcessor {
  /// Applies crop coordinates to an image and returns the cropped result
  Future<ui.Image> applyCrop(
    ui.Image sourceImage,
    CropCoordinates coordinates,
  ) async {
    try {
      if (!coordinates.isValid) {
        throw ArgumentError('Invalid crop coordinates: $coordinates');
      }

      if (sourceImage.width <= 0 || sourceImage.height <= 0) {
        throw ArgumentError('Invalid source image dimensions');
      }

      final sourceWidth = sourceImage.width;
      final sourceHeight = sourceImage.height;

      final cropX = (coordinates.x * sourceWidth).round();
      final cropY = (coordinates.y * sourceHeight).round();
      final cropWidth = (coordinates.width * sourceWidth).round();
      final cropHeight = (coordinates.height * sourceHeight).round();

      final clampedX = math.max(0, math.min(cropX, sourceWidth - 1));
      final clampedY = math.max(0, math.min(cropY, sourceHeight - 1));
      final clampedWidth =
          math.max(1, math.min(cropWidth, sourceWidth - clampedX));
      final clampedHeight =
          math.max(1, math.min(cropHeight, sourceHeight - clampedY));

      final cropRect = ui.Rect.fromLTWH(
        clampedX.toDouble(),
        clampedY.toDouble(),
        clampedWidth.toDouble(),
        clampedHeight.toDouble(),
      );

      return await _cropImageWithCanvas(sourceImage, cropRect);
    } catch (e) {
      return sourceImage;
    }
  }

  Future<ui.Image> _cropImageWithCanvas(
      ui.Image sourceImage, ui.Rect cropRect) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final srcRect = cropRect;
    final dstRect = ui.Rect.fromLTWH(0, 0, cropRect.width, cropRect.height);

    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());

    final picture = recorder.endRecording();
    final croppedImage = await picture.toImage(
      cropRect.width.round(),
      cropRect.height.round(),
    );

    picture.dispose();
    return croppedImage;
  }

  /// Applies crop and resizes to target size in one operation
  Future<ui.Image> applyCropAndResize(
    ui.Image sourceImage,
    CropCoordinates coordinates,
    ui.Size targetSize,
  ) async {
    try {
      if (!coordinates.isValid) {
        throw ArgumentError('Invalid crop coordinates: $coordinates');
      }

      if (targetSize.width <= 0 || targetSize.height <= 0) {
        throw ArgumentError('Invalid target size: $targetSize');
      }

      final sourceWidth = sourceImage.width;
      final sourceHeight = sourceImage.height;

      final cropX = coordinates.x * sourceWidth;
      final cropY = coordinates.y * sourceHeight;
      final cropWidth = coordinates.width * sourceWidth;
      final cropHeight = coordinates.height * sourceHeight;

      if (cropWidth <= 0 || cropHeight <= 0) {
        throw ArgumentError('Invalid crop dimensions: $cropWidth x $cropHeight');
      }

      final srcLeftRaw = math.max(0.0, cropX);
      final srcTopRaw = math.max(0.0, cropY);
      final srcRightRaw = math.min(sourceWidth.toDouble(), cropX + cropWidth);
      final srcBottomRaw =
          math.min(sourceHeight.toDouble(), cropY + cropHeight);

      if (srcRightRaw <= srcLeftRaw || srcBottomRaw <= srcTopRaw) {
        return await resizeImage(sourceImage, targetSize);
      }

      if (coordinates.strategy.contains('_letterbox')) {
        final double sW = srcRightRaw - srcLeftRaw;
        final double sH = srcBottomRaw - srcTopRaw;
        final double srcAspect = sW / sH;
        final double targetAspect = targetSize.width / targetSize.height;

        double fittedW, fittedH, fittedX, fittedY;
        if (srcAspect > targetAspect) {
          fittedH = targetSize.height;
          fittedW = targetSize.height * srcAspect;
          fittedX = (targetSize.width - fittedW) / 2;
          fittedY = 0;
        } else {
          fittedW = targetSize.width;
          fittedH = targetSize.width / srcAspect;
          fittedX = 0;
          fittedY = (targetSize.height - fittedH) / 2;
        }

        final srcRect =
            ui.Rect.fromLTRB(srcLeftRaw, srcTopRaw, srcRightRaw, srcBottomRaw);
        final dstRect = ui.Rect.fromLTWH(fittedX, fittedY, fittedW, fittedH);

        var croppedImage = await _cropAndResizeWithCanvas(
            sourceImage, srcRect, dstRect, targetSize);
        croppedImage = await PostCropScaler.scaleIfNeeded(croppedImage);
        return croppedImage;
      }

      final double sW = srcRightRaw - srcLeftRaw;
      final double sH = srcBottomRaw - srcTopRaw;
      final double targetAspect = targetSize.width / targetSize.height;
      final double srcAspect = sW / sH;

      double finalSrcWidth = sW;
      double finalSrcHeight = sH;
      const double maxDistortion = 1.25;

      if (srcAspect > targetAspect * maxDistortion) {
        finalSrcWidth = sH * (targetAspect * maxDistortion);
      } else if (srcAspect < targetAspect / maxDistortion) {
        finalSrcHeight = sW / (targetAspect / maxDistortion);
      }

      final double rawCenterX = srcLeftRaw + sW / 2.0;
      final double rawCenterY = srcTopRaw + sH / 2.0;

      double srcLeft = rawCenterX - finalSrcWidth / 2.0;
      double srcTop = rawCenterY - finalSrcHeight / 2.0;

      if (sW > finalSrcWidth) {
        final double imageCenterX = sourceWidth / 2.0;
        if (rawCenterX > imageCenterX) {
          final double slack = (sW - finalSrcWidth) / 2.0;
          srcLeft += slack * 0.8;
        } else if (rawCenterX < imageCenterX) {
          final double slack = (sW - finalSrcWidth) / 2.0;
          srcLeft -= slack * 0.8;
        }
      }

      if (sH > finalSrcHeight) {
        final double imageCenterY = sourceHeight / 2.0;
        if (rawCenterY > imageCenterY) {
          final double slack = (sH - finalSrcHeight) / 2.0;
          srcTop += slack * 0.8;
        } else if (rawCenterY < imageCenterY) {
          final double slack = (sH - finalSrcHeight) / 2.0;
          srcTop -= slack * 0.8;
        }
      }

      final double srcRight = srcLeft + finalSrcWidth;
      final double srcBottom = srcTop + finalSrcHeight;
      final srcRect = ui.Rect.fromLTRB(srcLeft, srcTop, srcRight, srcBottom);
      final dstRect =
          ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);

      var croppedImage = await _cropAndResizeWithCanvas(
          sourceImage, srcRect, dstRect, targetSize);
      croppedImage = await PostCropScaler.scaleIfNeeded(croppedImage);

      return croppedImage;
    } catch (e) {
      return await resizeImage(sourceImage, targetSize);
    }
  }

  Future<ui.Image> _cropAndResizeWithCanvas(
    ui.Image sourceImage,
    ui.Rect srcRect,
    ui.Rect dstRect,
    ui.Size targetSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final hasEmptySpace = dstRect.left > 0.1 ||
        dstRect.top > 0.1 ||
        dstRect.right < targetSize.width - 0.1 ||
        dstRect.bottom < targetSize.height - 0.1;

    if (hasEmptySpace) {
      final bgPaint = ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0);

      canvas.drawImageRect(
        sourceImage,
        ui.Rect.fromLTWH(
            0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        bgPaint,
      );

      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
        ui.Paint()..color = const ui.Color(0x66000000),
      );
    }

    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());

    final picture = recorder.endRecording();
    final resultImage = await picture.toImage(
      targetSize.width.round(),
      targetSize.height.round(),
    );

    picture.dispose();
    return resultImage;
  }

  Future<ui.Image> resizeImage(
      ui.Image sourceImage, ui.Size targetSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final double sW = sourceImage.width.toDouble();
    final double sH = sourceImage.height.toDouble();

    final double targetAspect = targetSize.width / targetSize.height;
    final double srcAspect = sW / sH;

    double finalSrcWidth = sW;
    double finalSrcHeight = sH;

    if (srcAspect > targetAspect) {
      finalSrcWidth = sH * targetAspect;
    } else if (srcAspect < targetAspect) {
      finalSrcHeight = sW / targetAspect;
    }

    final double srcLeft = (sW - finalSrcWidth) / 2.0;
    final double srcTop = (sH - finalSrcHeight) / 2.0;

    final srcRect =
        ui.Rect.fromLTWH(srcLeft, srcTop, finalSrcWidth, finalSrcHeight);
    final dstRect = ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);

    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());

    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(
      targetSize.width.round(),
      targetSize.height.round(),
    );

    picture.dispose();
    return resizedImage;
  }
}
