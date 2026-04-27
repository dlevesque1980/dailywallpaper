// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bing_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BingImage _$BingImageFromJson(Map<String, dynamic> json) => BingImage(
      DateTime.parse(json['startdate'] as String),
      json['fullstartdate'] as String,
      DateTime.parse(json['enddate'] as String),
      json['url'] as String,
      json['urlbase'] as String,
      json['copyright'] as String,
      json['copyrightlink'] as String,
      json['quiz'] as String,
      json['wp'] as bool,
      json['hsh'] as String,
      (json['drk'] as num).toInt(),
      (json['top'] as num).toInt(),
      (json['bot'] as num).toInt(),
    );

Map<String, dynamic> _$BingImageToJson(BingImage instance) => <String, dynamic>{
      'startdate': instance.startDate.toIso8601String(),
      'fullstartdate': instance.fullStartDate,
      'enddate': instance.endDate.toIso8601String(),
      'url': instance.url,
      'urlbase': instance.urlBase,
      'copyright': instance.copyright,
      'copyrightlink': instance.copyrightLink,
      'quiz': instance.quiz,
      'wp': instance.wp,
      'hsh': instance.hash,
      'drk': instance.drk,
      'top': instance.top,
      'bot': instance.bot,
    };
