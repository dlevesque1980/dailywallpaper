import 'dart:io';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

abstract class MlSegmentationService {
  Future<SubjectSegmentationResult> processImage(File imageFile);
  void dispose();
}

class MlSegmentationServiceImpl implements MlSegmentationService {
  final SubjectSegmenter _segmenter;

  MlSegmentationServiceImpl()
      : _segmenter = SubjectSegmenter(
          options: SubjectSegmenterOptions(
            enableMultipleSubjects: SubjectResultOptions(
              enableConfidenceMask: true,
              enableSubjectBitmap: false,
            ),
            enableForegroundConfidenceMask: true,
            enableForegroundBitmap: false,
          ),
        );

  @override
  Future<SubjectSegmentationResult> processImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return await _segmenter.processImage(inputImage);
  }

  @override
  void dispose() {
    _segmenter.close();
  }
}
