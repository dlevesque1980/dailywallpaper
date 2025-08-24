import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:dailywallpaper/helper/datetime_helper.dart';
import 'package:dailywallpaper/models/bing/bing_images.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/api/pexels_service.dart';
import 'package:dailywallpaper/models/pexels/pexels_models.dart';
import 'package:dailywallpaper/api/nasa_service.dart';
import 'package:dailywallpaper/models/nasa/nasa_models.dart';

class ImageRepository {
  static Future<ImageItem> fetchFromBing(String region) async {
    final response = await http.get(Uri.parse(
        'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$region'));
    BingImages bingImages;
    if (response.statusCode == 200) {
      bingImages = BingImages.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load bing image');
    }

    var bingImage = bingImages.images[0];
    var strs = bingImage.copyright.split("(");
    strs[1] = strs[1].substring(0, strs[1].length - 2);
    return new ImageItem(
        "Bing image of the day",
        'https://www.bing.com' + bingImage.url.replaceAll("1920x1080", "UHD"),
        strs[0],
        bingImage.startDate.toUtc(),
        bingImage.endDate.toUtc(),
        "bing.$region",
        null,
        strs[1]);
  }

  static Future<ImageItem> fetchThumbnailFromBing(String region) async {
    final response = await http.get(Uri.parse(
        'https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=$region'));
    BingImages bingImages;
    if (response.statusCode == 200) {
      bingImages = BingImages.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load bing image');
    }

    var bingImage = bingImages.images[0];
    var strs = bingImage.copyright.split("(");
    strs[1] = strs[1].substring(0, strs[1].length - 2);
    return new ImageItem(
        "Bing image of the day",
        'https://www.bing.com' +
            bingImage.url.replaceAll("1920x1080", "220x176"),
        strs[0],
        bingImage.startDate.toUtc(),
        bingImage.endDate.toUtc(),
        "bing.$region",
        null,
        strs[1]);
  }

  /// Fetch a random image from Pexels by category
  /// 
  /// [category] - Search category (e.g., "nature", "landscape", "city")
  /// Returns an ImageItem compatible with the existing app structure
  static Future<ImageItem> fetchFromPexels(String category) async {
    if (category.trim().isEmpty) {
      throw Exception('Category cannot be empty');
    }
    
    try {
      final pexelsPhoto = await PexelsService.getRandomPhotoByCategory(category);
      
      if (pexelsPhoto == null) {
        throw Exception('No images found for category: $category');
      }
      
      return _convertPexelsPhotoToImageItem(pexelsPhoto, category);
    } on PexelsApiException catch (e) {
      throw Exception('Failed to load Pexels image: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load Pexels image: ${e.toString()}');
    }
  }

  /// Fetch curated images from Pexels
  /// 
  /// [page] - Page number for pagination (default: 1)
  /// Returns a list of ImageItems from Pexels curated collection
  static Future<List<ImageItem>> fetchPexelsCurated({int page = 1}) async {
    try {
      final response = await PexelsService.fetchCuratedPhotos(
        page: page,
        perPage: 15, // Standard number of images per page
      );
      
      return response.photos
          .map((photo) => _convertPexelsPhotoToImageItem(photo, 'curated'))
          .toList();
    } on PexelsApiException catch (e) {
      throw Exception('Failed to load Pexels curated images: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load Pexels curated images: ${e.toString()}');
    }
  }

  /// Search Pexels images by query
  /// 
  /// [query] - Search term
  /// [page] - Page number for pagination (default: 1)
  /// Returns a list of ImageItems matching the search query
  static Future<List<ImageItem>> searchPexelsImages({
    required String query,
    int page = 1,
  }) async {
    try {
      final response = await PexelsService.searchPhotos(
        query: query,
        page: page,
        perPage: 15,
        orientation: 'portrait', // Prefer portrait for mobile wallpapers
      );
      
      return response.photos
          .map((photo) => _convertPexelsPhotoToImageItem(photo, query))
          .toList();
    } on PexelsApiException catch (e) {
      throw Exception('Failed to search Pexels images: ${e.message}');
    } catch (e) {
      throw Exception('Failed to search Pexels images: ${e.toString()}');
    }
  }

  /// Convert a PexelsPhoto to an ImageItem
  /// 
  /// This private method handles the conversion between Pexels API format
  /// and the app's internal ImageItem format, ensuring proper attribution
  static ImageItem _convertPexelsPhotoToImageItem(PexelsPhoto photo, String category) {
    // Create proper attribution as required by Pexels guidelines
    final photographerUrl = photo.photographerUrl;
    final photographer = photo.photographer;
    final pexelsUrl = "https://www.pexels.com";
    final referralQuery = "?utm_source=DailyWallpaper&utm_medium=referral";
    
    final copyright = 'Photo by <a href="$photographerUrl$referralQuery">$photographer</a> on <a href="$pexelsUrl$referralQuery">Pexels</a>';
    
    // Use current day as the time range (similar to how Bing works)
    final startTime = DateTimeHelper.startDayDate(DateTime.now());
    final endTime = startTime.add(const Duration(days: 1));
    
    // Use large2x for high quality, fallback to original if not available
    final imageUrl = photo.src.large2x.isNotEmpty ? photo.src.large2x : photo.src.original;
    
    // Create description from alt text or photographer name
    final description = photo.alt?.isNotEmpty == true 
        ? photo.alt! 
        : 'Photo by ${photo.photographer}';
    
    return ImageItem(
      "Pexels - $category",           // source
      imageUrl,                       // url
      description,                    // description
      startTime.toUtc(),             // startTime
      endTime.toUtc(),               // endTime
      'pexels.$category', // imageIdent (will be updated with date in BLoC)
      null,                          // triggerUrl (not needed for Pexels)
      copyright,                     // copyright (with proper attribution)
    );
  }

  /// Fetch NASA Astronomy Picture of the Day
  /// 
  /// Returns the current day's NASA APOD as an ImageItem
  /// Automatically filters out videos and only returns images
  static Future<ImageItem> fetchFromNASA() async {
    try {
      final nasaResponse = await NASAService.fetchAPOD();
      
      if (!nasaResponse.isImage) {
        throw Exception('Today\'s NASA APOD is not an image (it\'s a ${nasaResponse.mediaType})');
      }
      
      return _convertNASAResponseToImageItem(nasaResponse);
    } on NASAException catch (e) {
      throw Exception('Failed to load NASA APOD: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load NASA APOD: ${e.toString()}');
    }
  }

  /// Fetch NASA APOD for a specific date
  /// 
  /// [date] - Date in format 'YYYY-MM-DD'
  /// Returns the NASA APOD for the specified date as an ImageItem
  static Future<ImageItem> fetchNASAByDate(String date) async {
    try {
      final nasaResponse = await NASAService.fetchAPODByDate(date);
      
      if (!nasaResponse.isImage) {
        throw Exception('NASA APOD for $date is not an image (it\'s a ${nasaResponse.mediaType})');
      }
      
      return _convertNASAResponseToImageItem(nasaResponse);
    } on NASAException catch (e) {
      throw Exception('Failed to load NASA APOD for $date: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load NASA APOD for $date: ${e.toString()}');
    }
  }

  /// Fetch multiple NASA APODs from recent days
  /// 
  /// [days] - Number of days to go back (default: 7)
  /// Returns a list of ImageItems from NASA APOD archive (images only)
  static Future<List<ImageItem>> fetchNASAArchive({int days = 7}) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));
      
      final startDateStr = _formatDateForNASA(startDate);
      final endDateStr = _formatDateForNASA(endDate);
      
      final nasaResponses = await NASAService.fetchAPODRange(
        startDate: startDateStr,
        endDate: endDateStr,
        maxImages: days,
      );
      
      return nasaResponses
          .map((response) => _convertNASAResponseToImageItem(response))
          .toList();
    } on NASAException catch (e) {
      throw Exception('Failed to load NASA archive: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load NASA archive: ${e.toString()}');
    }
  }

  /// Convert a NASAResponse to an ImageItem
  /// 
  /// This private method handles the conversion between NASA API format
  /// and the app's internal ImageItem format, ensuring proper attribution
  static ImageItem _convertNASAResponseToImageItem(NASAResponse nasaResponse) {
    // Parse the date to create proper time range
    final date = DateTime.parse(nasaResponse.date);
    final startTime = DateTimeHelper.startDayDate(date);
    final endTime = startTime.add(const Duration(days: 1));
    
    // Use the best quality image URL (prefer hdurl over url)
    final imageUrl = nasaResponse.bestImageUrl;
    
    // Create proper NASA attribution
    final copyright = nasaResponse.attribution;
    
    // Use title as description, fallback to explanation if title is empty
    final description = nasaResponse.title.isNotEmpty 
        ? nasaResponse.title 
        : nasaResponse.explanation.length > 100
            ? '${nasaResponse.explanation.substring(0, 100)}...'
            : nasaResponse.explanation;
    
    return ImageItem(
      "NASA APOD",                   // source
      imageUrl,                      // url
      description,                   // description
      startTime.toUtc(),            // startTime
      endTime.toUtc(),              // endTime
      'nasa.${nasaResponse.date}',  // imageIdent
      null,                         // triggerUrl (not needed for NASA)
      copyright,                    // copyright (with proper attribution)
    );
  }

  /// Format DateTime to NASA API date format (YYYY-MM-DD)
  static String _formatDateForNASA(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
           '${date.month.toString().padLeft(2, '0')}-'
           '${date.day.toString().padLeft(2, '0')}';
  }

  /// Validate image URL accessibility
  /// 
  /// This utility method can be used to check if an image URL is accessible
  /// before attempting to use it as a wallpaper
  static Future<bool> validateImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

}
