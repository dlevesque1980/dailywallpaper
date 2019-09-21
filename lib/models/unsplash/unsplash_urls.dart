import 'package:json_annotation/json_annotation.dart';

part 'unsplash_urls.g.dart';

@JsonSerializable()
class UnsplashUrls extends Object {
  @JsonKey(name: "raw")
  String raw;
  @JsonKey(name: "full")
  String full;
  @JsonKey(name: "regular")
  String regular;
  @JsonKey(name: "small")
  String small;
  @JsonKey(name: "thumb")
  String thumb;

  UnsplashUrls(this.raw, this.full, this.regular, this.small, this.thumb);

  factory UnsplashUrls.fromJson(Map<String, dynamic> json) => _$UnsplashUrlsFromJson(json);
}
