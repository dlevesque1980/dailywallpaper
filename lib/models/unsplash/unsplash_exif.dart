import 'package:json_annotation/json_annotation.dart';
import 'dart:core';

part 'unsplash_exif.g.dart';

@JsonSerializable()
class UnsplashExif extends Object {
  @JsonKey(name: "make")
  String? make;
  @JsonKey(name: "model")
  String? model;
  @JsonKey(name: "exposure_time")
  String? exposureTime;
  @JsonKey(name: "aperture")
  String? aperture;
  @JsonKey(name: "focal_length")
  String? focalLength;
  @JsonKey(name: "iso")
  int? iso;

  UnsplashExif(this.make, this.model, this.exposureTime, this.aperture, this.focalLength, this.iso);

  factory UnsplashExif.fromJson(Map<String, dynamic> json) => _$UnsplashExifFromJson(json);
}
