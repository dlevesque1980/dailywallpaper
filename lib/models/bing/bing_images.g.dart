// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bing_images.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BingImages _$BingImagesFromJson(Map<String, dynamic> json) {
  return BingImages((json['images'] as List)
      ?.map((e) =>
          e == null ? null : BingImage.fromJson(e as Map<String, dynamic>))
      ?.toList());
}

Map<String, dynamic> _$BingImagesToJson(BingImages instance) =>
    <String, dynamic>{'images': instance.images};
