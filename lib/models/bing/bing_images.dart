import 'package:dailywallpaper/models/bing/bing_image.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bing_images.g.dart';

@JsonSerializable()
class BingImages extends Object {
  @JsonKey(name: "images")
  List<BingImage> images;

  BingImages(this.images);

  factory BingImages.fromJson(Map<String, dynamic> json) => _$BingImagesFromJson(json);
}
