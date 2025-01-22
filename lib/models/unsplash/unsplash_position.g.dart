// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashPosition _$UnsplashPositionFromJson(Map<String, dynamic> json) =>
    UnsplashPosition(
      (json['latitude'] as num).toDouble(),
      (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$UnsplashPositionToJson(UnsplashPosition instance) =>
    <String, dynamic>{
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
