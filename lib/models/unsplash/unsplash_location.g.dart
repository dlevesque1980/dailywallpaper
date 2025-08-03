// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unsplash_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnsplashLocation _$UnsplashLocationFromJson(Map<String, dynamic> json) =>
    UnsplashLocation(
      json['city'] as String?,
      json['country'] as String?,
      UnsplashPosition.fromJson(json['position'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UnsplashLocationToJson(UnsplashLocation instance) =>
    <String, dynamic>{
      'city': instance.city,
      'country': instance.country,
      'position': instance.position,
    };
