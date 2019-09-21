import 'package:dailywallpaper/models/unsplash/unsplash_collection.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_exif.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_links.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_location.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_urls.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_user.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unsplash_image.g.dart';

@JsonSerializable()
class UnsplashImage extends Object {
  @JsonKey(name: "id")
  String Id;
  @JsonKey(name: "created_at")
  DateTime createdAt;
  @JsonKey(name: "updated_at")
  DateTime updatedAt;
  @JsonKey(name: "width")
  int width;
  @JsonKey(name: "height")
  int height;
  @JsonKey(name: "color")
  String color;
  @JsonKey(name: "downloads")
  int downloads;
  @JsonKey(name: "likes")
  int likes;
  @JsonKey(name: "liked_by_user")
  bool likeByUser;
  @JsonKey(name: "description")
  String description;
  @JsonKey(name: "exif")
  UnsplashExif exif;
  @JsonKey(name: "location")
  UnsplashLocation location;
  @JsonKey(name: "current_user_collections")
  List<UnsplashCollection> userCollection;
  @JsonKey(name: "urls")
  UnsplashUrls urls;
  @JsonKey(name: "links")
  UnsplashLinks links;

  @JsonKey(name: "user")
  UnsplashUser user;

  UnsplashImage(this.Id, this.createdAt, this.updatedAt, this.width, this.height, this.color, this.downloads, this.likes, this.likeByUser, this.description,
      this.exif, this.location, this.userCollection, this.urls, this.links, this.user);

  factory UnsplashImage.fromJson(Map<String, dynamic> json) => _$UnsplashImageFromJson(json);
}
