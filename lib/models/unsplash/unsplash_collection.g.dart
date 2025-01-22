// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_collection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashCollection _$UnsplashCollectionFromJson(Map<String, dynamic> json) =>
    UnsplashCollection(
      (json['id'] as num).toInt(),
      json['title'] as String,
      DateTime.parse(json['published_at'] as String),
      DateTime.parse(json['updated_at'] as String),
      json['curated'] as bool,
      json['cover_photo'] as String,
      UnsplashUser.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UnsplashCollectionToJson(UnsplashCollection instance) =>
    <String, dynamic>{
      'id': instance.Id,
      'title': instance.title,
      'published_at': instance.publishedAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'curated': instance.curated,
      'cover_photo': instance.coverPhoto,
      'user': instance.user,
    };
