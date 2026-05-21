import '../../features/smart_crop/models/crop_result.dart';

class ImageItem {
  String url = "",
      description = "",
      imageIdent = "",
      copyright = "",
      source = "";
  String? triggerUrl = "";
  DateTime startTime = DateTime.fromMicrosecondsSinceEpoch(0),
      endTime = DateTime.fromMicrosecondsSinceEpoch(0);

  /// Order of the image in the list
  int displayOrder = 0;

  /// Result of the smart crop analysis for this image
  CropResult? smartCropResult;

  /// Chemins de fichiers locaux pour la persistance
  String? localSourcePath;
  String? localProcessedPath;
  String? cropResultJson;

  ImageItem(this.source, this.url, this.description, this.startTime,
      this.endTime, this.imageIdent, this.triggerUrl, this.copyright,
      {this.displayOrder = 0,
      this.localSourcePath,
      this.localProcessedPath,
      this.cropResultJson});

  ImageItem.fromMap(Map map) {
    source = (map["Source"] as String?) ?? '';
    url = (map["Url"] as String?) ?? '';
    description = (map["Description"] as String?) ?? '';
    startTime = map["StartTime"] != null
        ? DateTime.parse(map["StartTime"]!)
        : DateTime.now();
    endTime = map["EndTime"] != null
        ? DateTime.parse(map["EndTime"]!)
        : DateTime.now().add(const Duration(days: 1));
    imageIdent = (map["ImageIdent"] as String?) ?? '';
    triggerUrl = map["TriggerUrl"] as String?;
    copyright = (map["Copyright"] as String?) ?? '';
    displayOrder = (map["DisplayOrder"] as int?) ?? 0;
    localSourcePath = map["LocalSourcePath"] as String?;
    localProcessedPath = map["LocalProcessedPath"] as String?;
    cropResultJson = map["CropResultJson"] as String?;
  }

  /// Create a copy of this ImageItem with updated fields
  ImageItem copyWith({
    String? source,
    String? url,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? imageIdent,
    String? triggerUrl,
    String? copyright,
    CropResult? smartCropResult,
    int? displayOrder,
    String? localSourcePath,
    String? localProcessedPath,
    String? cropResultJson,
  }) {
    final item = ImageItem(
      source ?? this.source,
      url ?? this.url,
      description ?? this.description,
      startTime ?? this.startTime,
      endTime ?? this.endTime,
      imageIdent ?? this.imageIdent,
      triggerUrl ?? this.triggerUrl,
      copyright ?? this.copyright,
      displayOrder: displayOrder ?? this.displayOrder,
      localSourcePath: localSourcePath ?? this.localSourcePath,
      localProcessedPath: localProcessedPath ?? this.localProcessedPath,
      cropResultJson: cropResultJson ?? this.cropResultJson,
    );
    item.smartCropResult = smartCropResult ?? this.smartCropResult;
    return item;
  }
}
