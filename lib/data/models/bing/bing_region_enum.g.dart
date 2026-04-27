// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bing_region_enum.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

const BingRegionEnum _$us = const BingRegionEnum._('US');
const BingRegionEnum _$frenchcanana = const BingRegionEnum._('FrenchCanada');
const BingRegionEnum _$englishcanada = const BingRegionEnum._('EnglishCanada');
const BingRegionEnum _$germany = const BingRegionEnum._('Germany');
const BingRegionEnum _$australia = const BingRegionEnum._('Australia');
const BingRegionEnum _$uk = const BingRegionEnum._('UK');
const BingRegionEnum _$india = const BingRegionEnum._('India');
const BingRegionEnum _$france = const BingRegionEnum._('France');
const BingRegionEnum _$japan = const BingRegionEnum._('Japan');
const BingRegionEnum _$china = const BingRegionEnum._('China');
const BingRegionEnum _$international = const BingRegionEnum._('International');

BingRegionEnum _$valueOf(String name) {
  switch (name) {
    case 'US':
      return _$us;
    case 'FrenchCanada':
      return _$frenchcanana;
    case 'EnglishCanada':
      return _$englishcanada;
    case 'Germany':
      return _$germany;
    case 'Australia':
      return _$australia;
    case 'UK':
      return _$uk;
    case 'India':
      return _$india;
    case 'France':
      return _$france;
    case 'Japan':
      return _$japan;
    case 'China':
      return _$china;
    case 'International':
      return _$international;
    default:
      throw ArgumentError(name);
  }
}

final BuiltSet<BingRegionEnum> _$values =
    BuiltSet<BingRegionEnum>(const <BingRegionEnum>[
  _$us,
  _$frenchcanana,
  _$englishcanada,
  _$germany,
  _$australia,
  _$uk,
  _$india,
  _$france,
  _$japan,
  _$china,
  _$international,
]);

class _$BingRegionEnumMeta {
  const _$BingRegionEnumMeta();
  BingRegionEnum get US => _$us;
  BingRegionEnum get FrenchCanada => _$frenchcanana;
  BingRegionEnum get EnglishCanada => _$englishcanada;
  BingRegionEnum get Germany => _$germany;
  BingRegionEnum get Australia => _$australia;
  BingRegionEnum get UK => _$uk;
  BingRegionEnum get India => _$india;
  BingRegionEnum get France => _$france;
  BingRegionEnum get Japan => _$japan;
  BingRegionEnum get China => _$china;
  BingRegionEnum get International => _$international;
  BingRegionEnum valueOf(String name) => _$valueOf(name);
  BuiltSet<BingRegionEnum> get values => _$values;
}

mixin _$BingRegionEnumMixin {
  // ignore: non_constant_identifier_names
  _$BingRegionEnumMeta get BingRegionEnum => const _$BingRegionEnumMeta();
}

Serializer<BingRegionEnum> _$bingRegionEnumSerializer =
    _$BingRegionEnumSerializer();

class _$BingRegionEnumSerializer
    implements PrimitiveSerializer<BingRegionEnum> {
  static const Map<String, Object> _toWire = const <String, Object>{
    'US': 'en-US',
    'FrenchCanada': 'fr-CA',
    'EnglishCanada': 'en-CA',
    'Germany': 'de-DE',
    'Australia': 'en-AU',
    'UK': 'en-GB',
    'India': 'en-IN',
    'France': 'fr-FR',
    'Japan': 'ja-JP',
    'China': 'zh-CN',
    'International': 'en-WW',
  };
  static const Map<Object, String> _fromWire = const <Object, String>{
    'en-US': 'US',
    'fr-CA': 'FrenchCanada',
    'en-CA': 'EnglishCanada',
    'de-DE': 'Germany',
    'en-AU': 'Australia',
    'en-GB': 'UK',
    'en-IN': 'India',
    'fr-FR': 'France',
    'ja-JP': 'Japan',
    'zh-CN': 'China',
    'en-WW': 'International',
  };

  @override
  final Iterable<Type> types = const <Type>[BingRegionEnum];
  @override
  final String wireName = 'BingRegionEnum';

  @override
  Object serialize(Serializers serializers, BingRegionEnum object,
          {FullType specifiedType = FullType.unspecified}) =>
      _toWire[object.name] ?? object.name;

  @override
  BingRegionEnum deserialize(Serializers serializers, Object serialized,
          {FullType specifiedType = FullType.unspecified}) =>
      BingRegionEnum.valueOf(
          _fromWire[serialized] ?? (serialized is String ? serialized : ''));
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
