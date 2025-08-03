import 'package:dailywallpaper/models/unsplash/unsplash_user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unsplash_collection.g.dart';

@JsonSerializable()
class UnsplashCollection extends Object {
  @JsonKey(name: "id")
  int Id;
  @JsonKey(name: "title")
  String? title;
  @JsonKey(name: "published_at")
  DateTime publishedAt;
  @JsonKey(name: "updated_at")
  DateTime updatedAt;
  @JsonKey(name: "curated")
  bool curated;
  @JsonKey(name: "cover_photo")
  String? coverPhoto;

  @JsonKey(name: "user")
  UnsplashUser user;

  UnsplashCollection(this.Id, this.title, this.publishedAt, this.updatedAt, this.curated, this.coverPhoto, this.user);

  factory UnsplashCollection.fromJson(Map<String, dynamic> json) => _$UnsplashCollectionFromJson(json);
}
