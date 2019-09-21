// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_urls.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashUrls _$UnsplashUrlsFromJson(Map<String, dynamic> json) {
  return UnsplashUrls(
      json['raw'] as String,
      json['full'] as String,
      json['regular'] as String,
      json['small'] as String,
      json['thumb'] as String);
}

Map<String, dynamic> _$UnsplashUrlsToJson(UnsplashUrls instance) =>
    <String, dynamic>{
      'raw': instance.raw,
      'full': instance.full,
      'regular': instance.regular,
      'small': instance.small,
      'thumb': instance.thumb
    };
