import 'package:json_annotation/json_annotation.dart';

part 'bing_image.g.dart';

@JsonSerializable()
class BingImage extends Object {
  @JsonKey(name: "startdate")
  DateTime startDate;
  @JsonKey(name: "fullstartdate")
  String fullStartDate;
  @JsonKey(name: "enddate")
  DateTime endDate;
  @JsonKey(name: "url")
  String url;
  @JsonKey(name: "urlbase")
  String urlBase;
  @JsonKey(name: "copyright")
  String copyright;
  @JsonKey(name: "copyrightlink")
  String copyrightLink;
  @JsonKey(name: "quiz")
  String quiz;
  @JsonKey(name: "wp")
  bool wp;
  @JsonKey(name: "hsh")
  String hash;
  @JsonKey(name: "drk")
  int drk;
  @JsonKey(name: "top")
  int top;
  @JsonKey(name: "bot")
  int bot;

  BingImage(this.startDate, this.fullStartDate, this.endDate, this.url, this.urlBase, this.copyright, this.copyrightLink, this.quiz, this.wp, this.hash, this.drk,
      this.top, this.bot);

  factory BingImage.fromJson(Map<String, dynamic> json) => _$BingImageFromJson(json);
}
