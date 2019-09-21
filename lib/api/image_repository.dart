import 'dart:async';
import 'dart:convert';

import 'package:dailywallpaper/consts/consts.dart';
import 'package:dailywallpaper/models/unsplash/unsplash_image.dart';
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/helper/datetime_helper.dart';
import 'package:dailywallpaper/models/bing/bing_images.dart';
import 'package:dailywallpaper/models/image_item.dart';

class ImageRepository {
  static Future<ImageItem> fetchFromBing(String region) async {
    final response = await http.get('https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$region');
    BingImages bingImages;
    if (response.statusCode == 200) {
      bingImages = BingImages.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load bing image');
    }

    var bingImage = bingImages.images[0];
    var strs = bingImage.copyright.split("(");
    strs[1] = strs[1].substring(0, strs[1].length - 2);
    return new ImageItem("Bing image of the day", 'https://www.bing.com' + bingImage.url.replaceAll("1920x1080", "1080x1920"), strs[0], bingImage.startDate.toUtc(),
        bingImage.endDate.toUtc(), "bing.$region", null, strs[1]);
  }

  static Future<ImageItem> fetchThumbnailFromBing(String region) async {
    final response = await http.get('https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$region');
    BingImages bingImages;
    if (response.statusCode == 200) {
      bingImages = BingImages.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load bing image');
    }

    var bingImage = bingImages.images[0];
    var strs = bingImage.copyright.split("(");
    strs[1] = strs[1].substring(0, strs[1].length - 2);
    return new ImageItem("Bing image of the day", 'https://www.bing.com' + bingImage.url.replaceAll("1920x1080", "220x176"), strs[0], bingImage.startDate.toUtc(),
        bingImage.endDate.toUtc(), "bing.$region", null, strs[1]);
  }

  static Future<ImageItem> fetchFromUnsplash(String category) async {
    final response = await http.get('https://api.unsplash.com/photos/random?h=1080&orientation=portrait&query=$category&client_id=$unsplashClientKey');

    UnsplashImage image;
    if (response.statusCode == 200) {
      image = UnsplashImage.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load unsplash image');
    }
    var startTime = DateTimeHelper.startDayDate(DateTime.now());
    var endTime = startTime.add(new Duration(days: 1));
    var referalQueryString = "?utm_source=Dailywallpaper&utm_medium=referral";
    var unsplashUrl = "https://unsplash.com/$referalQueryString";
    var userUrl = image.user.links.html;
    var userName = image.user.name;
    var copyright = "Photo by <a href=\"$userUrl$referalQueryString\">$userName</a> on <a href=\"$unsplashUrl\">Unsplash</a>";
    return new ImageItem("Unsplash - $category", image.urls.regular, image.description, startTime.toUtc(), endTime.toUtc(), 'unsplash.$category',
        image.links.downloadLocation, copyright);
  }

  static Future<bool> triggerUnsplashDownload(String url) async {
    final response = await http.get("$url?client_id=$unsplashClientKey");
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }
}
