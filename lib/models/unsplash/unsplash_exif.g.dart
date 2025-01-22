// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_exif.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashExif _$UnsplashExifFromJson(Map<String, dynamic> json) => UnsplashExif(
      json['make'] as String,
      json['model'] as String,
      json['exposure_time'] as String,
      json['aperture'] as String,
      json['focal_length'] as String,
      (json['iso'] as num).toInt(),
    );

Map<String, dynamic> _$UnsplashExifToJson(UnsplashExif instance) =>
    <String, dynamic>{
      'make': instance.make,
      'model': instance.model,
      'exposure_time': instance.exposureTime,
      'aperture': instance.aperture,
      'focal_length': instance.focalLength,
      'iso': instance.iso,
    };
