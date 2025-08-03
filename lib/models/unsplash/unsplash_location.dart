import 'package:dailywallpaper/models/unsplash/unsplash_position.dart';
import 'package:json_annotation/json_annotation.dart';

part 'unsplash_location.g.dart';

@JsonSerializable()
class UnsplashLocation extends Object {
  @JsonKey(name: "city")
  String? city;
  @JsonKey(name: "country")
  String? country;
  @JsonKey(name: "position")
  UnsplashPosition position;

  UnsplashLocation(this.city, this.country, this.position);

  factory UnsplashLocation.fromJson(Map<String, dynamic> json) => _$UnsplashLocationFromJson(json);
}
