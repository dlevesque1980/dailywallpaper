import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dailywallpaper/data/models/bing/bing_images.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/datasources/bing_data_source.dart';

class BingService implements BingDataSource {
  static const String _baseUrl = 'https://www.bing.com';
  static const String _archivePath = '/HPImageArchive.aspx?format=js&idx=0&n=1';

  final http.Client _client;

  BingService({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<ImageItem> fetchFromBing(String region) async {
    final response = await _client.get(Uri.parse('$_baseUrl$_archivePath&mkt=$region'));
    
    if (response.statusCode == 200) {
      final bingImages = BingImages.fromJson(json.decode(response.body));
      return _convertBingImageToItem(bingImages, region, isThumbnail: false);
    } else {
      throw Exception('Failed to load bing image: ${response.statusCode}');
    }
  }

  @override
  Future<ImageItem> fetchThumbnailFromBing(String region) async {
    final response = await _client.get(Uri.parse('$_baseUrl$_archivePath&mkt=$region'));
    
    if (response.statusCode == 200) {
      final bingImages = BingImages.fromJson(json.decode(response.body));
      return _convertBingImageToItem(bingImages, region, isThumbnail: true);
    } else {
      throw Exception('Failed to load bing thumbnail: ${response.statusCode}');
    }
  }

  ImageItem _convertBingImageToItem(BingImages bingImages, String region, {required bool isThumbnail}) {
    if (bingImages.images.isEmpty) {
      throw Exception('No images found in Bing response');
    }

    final bingImage = bingImages.images[0];
    final copyrightParts = bingImage.copyright.split("(");
    final photographer = copyrightParts.length > 1 
        ? copyrightParts[1].substring(0, copyrightParts[1].length - 1).trim()
        : "";
    
    final resolution = isThumbnail ? "220x176" : "UHD";
    final imageUrl = '$_baseUrl${bingImage.url.replaceAll("1920x1080", resolution)}';

    return ImageItem(
      "Bing image of the day",
      imageUrl,
      copyrightParts[0].trim(),
      bingImage.startDate.toUtc(),
      bingImage.endDate.toUtc(),
      "bing.$region",
      null,
      photographer,
    );
  }
}
