// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_links.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashLinks _$UnsplashLinksFromJson(Map<String, dynamic> json) =>
    UnsplashLinks(
      json['self'] as String?,
      json['html'] as String?,
      json['photos'] as String?,
      json['likes'] as String?,
      json['portfolio'] as String?,
      json['download'] as String?,
      json['download_location'] as String?,
    );

Map<String, dynamic> _$UnsplashLinksToJson(UnsplashLinks instance) =>
    <String, dynamic>{
      'self': instance.self,
      'html': instance.html,
      'photos': instance.photos,
      'likes': instance.likes,
      'portfolio': instance.portfolio,
      'download': instance.download,
      'download_location': instance.downloadLocation,
    };
