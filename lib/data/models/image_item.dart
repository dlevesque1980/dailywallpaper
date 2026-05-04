import '../../services/smart_crop/models/crop_result.dart';

class ImageItem {
  String url ="", description="", imageIdent="", copyright="", source="";
  String? triggerUrl="";
  DateTime startTime=DateTime.fromMicrosecondsSinceEpoch(0), endTime= DateTime.fromMicrosecondsSinceEpoch(0);
  
  /// Result of the smart crop analysis for this image
  CropResult? smartCropResult;
 
  ImageItem(this.source, this.url, this.description, this.startTime, this.endTime, this.imageIdent, this.triggerUrl, this.copyright);

  ImageItem.fromMap(Map map) {
    source = map["Source"]!;
    url = map["Url"]!;
    description = map["Description"]!;
    startTime = DateTime.parse(map["StartTime"]!);
    endTime = DateTime.parse(map["EndTime"]!);
    imageIdent = map["ImageIdent"]!;
    triggerUrl = map["TriggerUrl"];
    copyright = map["Copyright"]!;
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
    );
    item.smartCropResult = smartCropResult ?? this.smartCropResult;
    return item;
  }
}
