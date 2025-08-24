import 'package:dailywallpaper/models/pexels/pexels_photo.dart';

class PexelsResponse {
  final int page;
  final int perPage;
  final List<PexelsPhoto> photos;
  final String? nextPage;
  final String? prevPage;
  final int totalResults;

  PexelsResponse({
    required this.page,
    required this.perPage,
    required this.photos,
    this.nextPage,
    this.prevPage,
    required this.totalResults,
  });

  factory PexelsResponse.fromJson(Map<String, dynamic> json) {
    return PexelsResponse(
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 15,
      photos: (json['photos'] as List<dynamic>?)
          ?.map((photoJson) => PexelsPhoto.fromJson(photoJson))
          .toList() ?? [],
      nextPage: json['next_page'],
      prevPage: json['prev_page'],
      totalResults: json['total_results'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'per_page': perPage,
      'photos': photos.map((photo) => photo.toJson()).toList(),
      'next_page': nextPage,
      'prev_page': prevPage,
      'total_results': totalResults,
    };
  }
}