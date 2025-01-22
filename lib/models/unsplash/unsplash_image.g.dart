// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashImage _$UnsplashImageFromJson(Map<String, dynamic> json) =>
    UnsplashImage(
      json['id'] as String,
      DateTime.parse(json['created_at'] as String),
      DateTime.parse(json['updated_at'] as String),
      (json['width'] as num).toInt(),
      (json['height'] as num).toInt(),
      json['color'] as String,
      (json['downloads'] as num).toInt(),
      (json['likes'] as num).toInt(),
      json['liked_by_user'] as bool,
      json['description'] as String,
      UnsplashExif.fromJson(json['exif'] as Map<String, dynamic>),
      UnsplashLocation.fromJson(json['location'] as Map<String, dynamic>),
      (json['current_user_collections'] as List<dynamic>)
          .map((e) => UnsplashCollection.fromJson(e as Map<String, dynamic>))
          .toList(),
      UnsplashUrls.fromJson(json['urls'] as Map<String, dynamic>),
      UnsplashLinks.fromJson(json['links'] as Map<String, dynamic>),
      UnsplashUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UnsplashImageToJson(UnsplashImage instance) =>
    <String, dynamic>{
      'id': instance.Id,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'width': instance.width,
      'height': instance.height,
      'color': instance.color,
      'downloads': instance.downloads,
      'likes': instance.likes,
      'liked_by_user': instance.likeByUser,
      'description': instance.description,
      'exif': instance.exif,
      'location': instance.location,
      'current_user_collections': instance.userCollection,
      'urls': instance.urls,
      'links': instance.links,
      'user': instance.user,
    };
