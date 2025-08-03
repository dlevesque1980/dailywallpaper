import 'package:dailywallpaper/models/unsplash/unsplash_links.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unsplash_user.g.dart';

@JsonSerializable()
class UnsplashUser extends Object {
  @JsonKey(name: "id")
  String? Id;
  @JsonKey(name: "updated_at")
  DateTime updatedAt;
  @JsonKey(name: "username")
  String? userName;
  @JsonKey(name: "name")
  String? name;
  @JsonKey(name: "portfolio_url")
  String? portfolioUrl;
  @JsonKey(name: "bio")
  String? bio;
  @JsonKey(name: "location")
  String? location;
  @JsonKey(name: "total_likes")
  int? totalLikes;
  @JsonKey(name: "total_photos")
  int? totalPhotos;
  @JsonKey(name: "total_collections")
  int? totalCollection;
  @JsonKey(name: "links")
  UnsplashLinks links;

  UnsplashUser(this.Id, this.updatedAt, this.userName, this.name, this.portfolioUrl, this.bio, this.location, this.totalLikes, this.totalPhotos,
      this.totalCollection, this.links);

  factory UnsplashUser.fromJson(Map<String, dynamic> json) => _$UnsplashUserFromJson(json);
}
