// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashUser _$UnsplashUserFromJson(Map<String, dynamic> json) => UnsplashUser(
      json['id'] as String?,
      DateTime.parse(json['updated_at'] as String),
      json['username'] as String?,
      json['name'] as String?,
      json['portfolio_url'] as String?,
      json['bio'] as String?,
      json['location'] as String?,
      (json['total_likes'] as num?)?.toInt(),
      (json['total_photos'] as num?)?.toInt(),
      (json['total_collections'] as num?)?.toInt(),
      UnsplashLinks.fromJson(json['links'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UnsplashUserToJson(UnsplashUser instance) =>
    <String, dynamic>{
      'id': instance.Id,
      'updated_at': instance.updatedAt.toIso8601String(),
      'username': instance.userName,
      'name': instance.name,
      'portfolio_url': instance.portfolioUrl,
      'bio': instance.bio,
      'location': instance.location,
      'total_likes': instance.totalLikes,
      'total_photos': instance.totalPhotos,
      'total_collections': instance.totalCollection,
      'links': instance.links,
    };
