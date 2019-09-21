import 'package:json_annotation/json_annotation.dart';

part 'unsplash_links.g.dart';

@JsonSerializable()
class UnsplashLinks extends Object {
  @JsonKey(name: "self")
  String self;
  @JsonKey(name: "html")
  String html;
  @JsonKey(name: "photos")
  String photos;
  @JsonKey(name: "likes")
  String likes;
  @JsonKey(name: "portfolio")
  String portfolio;
  @JsonKey(name: "download")
  String download;
  @JsonKey(name: "download_location")
  String downloadLocation;

  UnsplashLinks(this.self, this.html, this.photos, this.likes, this.portfolio, this.download, this.downloadLocation);

  factory UnsplashLinks.fromJson(Map<String, dynamic> json) => _$UnsplashLinksFromJson(json);
}
