class NASAResponse {
  final String date;
  final String explanation;
  final String? hdurl;
  final String mediaType;
  final String serviceVersion;
  final String title;
  final String url;
  final String? copyright;

  NASAResponse({
    required this.date,
    required this.explanation,
    this.hdurl,
    required this.mediaType,
    required this.serviceVersion,
    required this.title,
    required this.url,
    this.copyright,
  });

  factory NASAResponse.fromJson(Map<String, dynamic> json) {
    return NASAResponse(
      date: json['date'] ?? '',
      explanation: json['explanation'] ?? '',
      hdurl: json['hdurl'],
      mediaType: json['media_type'] ?? 'image',
      serviceVersion: json['service_version'] ?? '1',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      copyright: json['copyright'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'explanation': explanation,
      'hdurl': hdurl,
      'media_type': mediaType,
      'service_version': serviceVersion,
      'title': title,
      'url': url,
      'copyright': copyright,
    };
  }

  // Helper method to check if this is an image (not video)
  bool get isImage => mediaType.toLowerCase() == 'image';

  // Get the best quality image URL (prefer hdurl over url)
  String get bestImageUrl => hdurl?.isNotEmpty == true ? hdurl! : url;

  // Create proper attribution for NASA images
  String get attribution {
    final baseAttribution = 'Image courtesy of NASA';
    if (copyright?.isNotEmpty == true) {
      return '$baseAttribution - $copyright';
    }
    return baseAttribution;
  }

  @override
  String toString() {
    return 'NASAResponse{date: $date, title: $title, mediaType: $mediaType, isImage: $isImage}';
  }
}