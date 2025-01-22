// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bing_images.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BingImages _$BingImagesFromJson(Map<String, dynamic> json) => BingImages(
      (json['images'] as List<dynamic>)
          .map((e) => BingImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BingImagesToJson(BingImages instance) =>
    <String, dynamic>{
      'images': instance.images,
    };
