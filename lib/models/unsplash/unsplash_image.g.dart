// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashImage _$UnsplashImageFromJson(Map<String, dynamic> json) {
  return UnsplashImage(
      json['id'] as String,
      json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
      json['width'] as int,
      json['height'] as int,
      json['color'] as String,
      json['downloads'] as int,
      json['likes'] as int,
      json['liked_by_user'] as bool,
      json['description'] as String,
      json['exif'] == null
          ? null
          : UnsplashExif.fromJson(json['exif'] as Map<String, dynamic>),
      json['location'] == null
          ? null
          : UnsplashLocation.fromJson(json['location'] as Map<String, dynamic>),
      (json['current_user_collections'] as List)
          ?.map((e) => e == null
              ? null
              : UnsplashCollection.fromJson(e as Map<String, dynamic>))
          ?.toList(),
      json['urls'] == null
          ? null
          : UnsplashUrls.fromJson(json['urls'] as Map<String, dynamic>),
      json['links'] == null
          ? null
          : UnsplashLinks.fromJson(json['links'] as Map<String, dynamic>),
      json['user'] == null
          ? null
          : UnsplashUser.fromJson(json['user'] as Map<String, dynamic>));
}

Map<String, dynamic> _$UnsplashImageToJson(UnsplashImage instance) =>
    <String, dynamic>{
      'id': instance.Id,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
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
      'user': instance.user
    };
