/// Smart crop analyzers library
///
/// This library exports all available crop analysis strategies for the smart crop system.
/// Each analyzer implements a different approach to identifying optimal crop areas.

export 'rule_of_thirds_crop_analyzer.dart';
export 'center_weighted_crop_analyzer.dart';
export 'entropy_based_crop_analyzer.dart';
export 'edge_detection_crop_analyzer.dart';
export 'landscape_aware_crop_analyzer.dart';
export 'subject_detection_crop_analyzer.dart';
export 'bird_detection_crop_analyzer.dart' hide HSV;
export 'face_detection_crop_analyzer.dart';
export 'object_detection_crop_analyzer.dart';
export 'enhanced_composition_crop_analyzer.dart';
export 'color_crop_analyzer.dart';
export 'ml_subject_crop_analyzer.dart';
