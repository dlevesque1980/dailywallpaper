import 'package:json_annotation/json_annotation.dart';

part 'unsplash_position.g.dart';

/*
  "location": {
    "city": "Montreal",
    "country": "Canada",
    "position": {
      "latitude": 45.4732984,
      "longitude": -73.6384879
    }
  },
 */

@JsonSerializable()
class UnsplashPosition extends Object {
  @JsonKey(name: "latitude")
  double latitude;
  @JsonKey(name: "longitude")
  double longitude;

  UnsplashPosition(this.latitude, this.longitude);

  factory UnsplashPosition.fromJson(Map<String, dynamic> json) => _$UnsplashPositionFromJson(json);
}
