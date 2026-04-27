import 'dart:ui' as ui;
import 'dart:math' as math;
import '../models/crop_coordinates.dart';

/// Result of evaluating whether a subject fits within a proposed crop
class SubjectFitResult {
  /// Whether the crop window had to be expanded 
  final bool needsScaling;
  
  /// The adjusted crop coordinates (scaled and shifted)
  final CropCoordinates adjustedCrop;
  
  /// The zoom-out factor applied (> 1.0 means zoomed out)
  final double scaleFactor;
  
  /// Percentage of the subject that is visible in the final crop (0.0 to 1.0)
  final double subjectCoverage;

  const SubjectFitResult({
    required this.needsScaling,
    required this.adjustedCrop,
    required this.scaleFactor,
    required this.subjectCoverage,
  });
}

/// Utility to automatically scale a crop window to fit a detected subject
class SubjectFitChecker {
  /// Checks if the proposed crop adequately contains the subject,
  /// and if not, expands the crop window (zooms out) to fit it.
  static SubjectFitResult checkSubjectFit(
    CropCoordinates proposedCrop,
    ui.Rect subjectBounds,
    ui.Size imageSize,
    ui.Size targetAspectRatio, {
    double minCoverage = 0.85,
    double maxScale = 1.5,
    bool allowLetterbox = false,
  }) {
    // We must do all math in absolute pixels because normalized spaces distort aspect ratios.
    final imageW = imageSize.width;
    final imageH = imageSize.height;
    
    // 1. Convert normalized to absolute
    final absPropW = proposedCrop.width * imageW;
    final absPropH = proposedCrop.height * imageH;
    final absPropX = proposedCrop.x * imageW;
    final absPropY = proposedCrop.y * imageH;
    
    final absSubW = subjectBounds.width * imageW;
    final absSubH = subjectBounds.height * imageH;
    final absSubX = subjectBounds.left * imageW;
    final absSubY = subjectBounds.top * imageH;
    
    // Enhance subject bounds with 5% padding to give the subject room to breathe
    final paddingX = absSubW * 0.05;
    final paddingY = absSubH * 0.05;
    
    final paddedSubW = absSubW + (paddingX * 2);
    final paddedSubH = absSubH + (paddingY * 2);
    final paddedSubX = math.max(0.0, absSubX - paddingX);
    final paddedSubY = math.max(0.0, absSubY - paddingY);
    
    final cropRect = ui.Rect.fromLTWH(absPropX, absPropY, absPropW, absPropH);
    final absSubjectBoundsOrig = ui.Rect.fromLTWH(absSubX, absSubY, absSubW, absSubH);
    final absSubjectBoundsPadded = ui.Rect.fromLTWH(paddedSubX, paddedSubY, paddedSubW, paddedSubH);
        
    final intersection = cropRect.intersect(absSubjectBoundsOrig);
    final subjectArea = absSubW * absSubH;
    
    // Safety check for empty bounds
    if (subjectArea <= 0) {
      return SubjectFitResult(
        needsScaling: false,
        adjustedCrop: proposedCrop,
        scaleFactor: 1.0,
        subjectCoverage: 1.0,
      );
    }

    final intersectionArea = math.max(0.0, intersection.width) * math.max(0.0, intersection.height);
    final coverage = intersectionArea / subjectArea;
    
    // If coverage is good enough, no scaling needed
    if (coverage >= minCoverage) {
      return SubjectFitResult(
        needsScaling: false,
        adjustedCrop: proposedCrop,
        scaleFactor: 1.0,
        subjectCoverage: coverage,
      );
    }
    
    // 2. Needs scaling - We must create a window that fits the subject 
    // AND maintains the target aspect ratio.
    final targetRatio = targetAspectRatio.width / targetAspectRatio.height;
    
    // Calculate the absolute minimum width/height needed to contain the subject 
    // while maintaining the target aspect ratio, using our padded bounds.
    double reqWidth = paddedSubW;
    double reqHeight = paddedSubH;
    
    if (reqWidth / targetRatio < reqHeight) {
      // Height is the restricting factor, expand width to match aspect ratio
      reqWidth = reqHeight * targetRatio;
    } else {
      // Width is the restricting factor, expand height to match aspect ratio
      reqHeight = reqWidth / targetRatio;
    }
    
    // The new crop must be at LEAST as large as the original proposed crop
    double newWidth = math.max(absPropW, reqWidth);
    double newHeight = math.max(absPropH, reqHeight);
    
    // 3. Apply maximum scale limits based on the ORIGINAL crop size
    // REMOVED FOR PHASE 2: We no longer limit the scaling factor if zooming out 
    // is necessary to preserve 100% of the wide/tall subject.
    /*
    final maxW = absPropW * maxScale;
    final maxH = absPropH * maxScale;
    
    if (newWidth > maxW || newHeight > maxH) {
      // If we exceed max scale, we must cap it but keep the aspect ratio
      final scaleToFitMaxW = maxW / newWidth;
      final scaleToFitMaxH = maxH / newHeight;
      final limitingScale = math.min(scaleToFitMaxW, scaleToFitMaxH);
      
      newWidth *= limitingScale;
      newHeight *= limitingScale;
    }
    */
    
    // Further cap to absolute image boundaries (imageW x imageH)
    if (newWidth > imageW || newHeight > imageH) {
      if (allowLetterbox) {
        // With letterbox enabled: expand to fill the image dimension rather than
        // giving up. applyCropAndResize will add blurred side bars to fill the gap.
        final scaleToFitImgW = imageW / newWidth;
        final scaleToFitImgH = imageH / newHeight;
        // Use the LESS restrictive scale so we capture as much as possible.
        final limitingScaleLimits = math.max(scaleToFitImgW, scaleToFitImgH);
        newWidth = math.min(imageW, newWidth * limitingScaleLimits);
        newHeight = math.min(imageH, newHeight * limitingScaleLimits);
      } else {
        final scaleToFitImgW = imageW / newWidth;
        final scaleToFitImgH = imageH / newHeight;
        final limitingScaleLimits = math.min(scaleToFitImgW, scaleToFitImgH);

        newWidth *= limitingScaleLimits;
        newHeight *= limitingScaleLimits;

        // If capping makes the crop smaller than the original proposed crop,
        // it's better to just use the original crop (which is already optimal aspect ratio).
        if (newWidth < absPropW - 1.0 || newHeight < absPropH - 1.0) {
          return SubjectFitResult(
            needsScaling: false,
            adjustedCrop: proposedCrop,
            scaleFactor: 1.0,
            subjectCoverage: coverage,
          );
        }
      }
    }

    // 4. Center the new crop window over the original crop's center to preserve composition
    final cropCenterX = absPropX + (absPropW / 2);
    final cropCenterY = absPropY + (absPropH / 2);
    
    double newX = cropCenterX - (newWidth / 2);
    double newY = cropCenterY - (newHeight / 2);

    // 5. Shift to keep inside image boundaries, but ONLY if the box is actually smaller than the image.
    // If it's larger, it means the user allowed scaling out (letterboxing) in CropSettings.
    if (newWidth <= imageW) {
      if (newX < 0) newX = 0;
      if (newX + newWidth > imageW) newX = imageW - newWidth;
    }
    
    if (newHeight <= imageH) {
      if (newY < 0) newY = 0;
      if (newY + newHeight > imageH) newY = imageH - newHeight;
    }
    
    // 6. Convert back to normalized coordinates
    final normX = newX / imageW;
    final normY = newY / imageH;
    final normW = newWidth / imageW;
    final normH = newHeight / imageH;
    
    final scaleFactor = absPropW > 0 ? newWidth / absPropW : 1.0;
    
    final finalCropRect = ui.Rect.fromLTWH(newX, newY, newWidth, newHeight);
    final finalIntersection = finalCropRect.intersect(absSubjectBoundsOrig);
    final finalIntersectionArea = math.max(0.0, finalIntersection.width) * math.max(0.0, finalIntersection.height);
    final finalCoverage = subjectArea > 0 ? finalIntersectionArea / subjectArea : 1.0;
    
    return SubjectFitResult(
      needsScaling: true,
      adjustedCrop: proposedCrop.copyWith(
        x: normX,
        y: normY,
        width: normW,
        height: normH,
        scalingApplied: true,
        strategy: '${proposedCrop.strategy}_scaled',
      ),
      scaleFactor: scaleFactor,
      subjectCoverage: finalCoverage,
    );
  }
}
