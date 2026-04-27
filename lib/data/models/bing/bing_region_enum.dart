import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'bing_region_enum.g.dart';

class BingRegionEnum extends EnumClass {
  static Serializer<BingRegionEnum> get serializer => _$bingRegionEnumSerializer;

  @BuiltValueEnumConst(wireName: 'en-US')
  static const BingRegionEnum US = _$us;
  @BuiltValueEnumConst(wireName: 'fr-CA')
  static const BingRegionEnum FrenchCanada = _$frenchcanana;
  @BuiltValueEnumConst(wireName: 'en-CA')
  static const BingRegionEnum EnglishCanada = _$englishcanada;
  @BuiltValueEnumConst(wireName: 'de-DE')
  static const BingRegionEnum Germany = _$germany;
  @BuiltValueEnumConst(wireName: 'en-AU')
  static const BingRegionEnum Australia = _$australia;
  @BuiltValueEnumConst(wireName: 'en-GB')
  static const BingRegionEnum UK = _$uk;
  @BuiltValueEnumConst(wireName: 'en-IN')
  static const BingRegionEnum India = _$india;
  @BuiltValueEnumConst(wireName: 'fr-FR')
  static const BingRegionEnum France = _$france;
  @BuiltValueEnumConst(wireName: 'ja-JP')
  static const BingRegionEnum Japan = _$japan;
  @BuiltValueEnumConst(wireName: 'zh-CN')
  static const BingRegionEnum China = _$china;
  @BuiltValueEnumConst(wireName: 'en-WW')
  static const BingRegionEnum International = _$international;

  const BingRegionEnum._(String name) : super(name);
  static BuiltSet<BingRegionEnum> get values => _$values;
  static BingRegionEnum valueOf(String name) => _$valueOf(name);

  static String definitionOf(BingRegionEnum value) {
    switch (value) {
      case Australia:
        return "en-AU";
      case China:
        return "zh-CN";
      case EnglishCanada:
        return "en-CA";
      case France:
        return "fr-FR";
      case FrenchCanada:
        return "fr-CA";
      case Germany:
        return "de-DE";
      case India:
        return "en-IN";
      case International:
        return "en-WW";
      case Japan:
        return "ja-JP";
      case UK:
        return "en-GB";
      case US:
        return "en-US";
    }

    throw new ArgumentError(value);
  }

  static String labelOf(BingRegionEnum value) {
    switch (value) {
      case Australia:
        return value.toString();
      case China:
        return value.toString();
      case EnglishCanada:
        return "English Canada";
      case France:
        return value.toString();
      case FrenchCanada:
        return "French Canada";
      case Germany:
        return value.toString();
      case India:
        return value.toString();
      case International:
        return value.toString();
      case Japan:
        return value.toString();
      case UK:
        return "United Kingdom";
      case US:
        return "United States";
    }

    throw new ArgumentError(value);
  }

  static BingRegionEnum valueFromDefinition(String definition) {
    switch (definition) {
      case "en-AU":
        return Australia;
      case "zh-CH":
        return China;
      case "en-CA":
        return EnglishCanada;
      case "fr-FR":
        return France;
      case "fr-CA":
        return FrenchCanada;
      case "de-DE":
        return Germany;
      case "en-IN":
        return India;
      case "en-WW":
        return International;
      case "ja-JP":
        return Japan;
      case "en-GB":
        return UK;
      case "en-US":
        return US;
    }
    throw new ArgumentError(definition);
  }
}

abstract class BingRegionEnumMixin = Object with _$BingRegionEnumMixin;
