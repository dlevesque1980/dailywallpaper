class ImageItem {
  String url ="", description="", imageIdent="", copyright="", source="";
  String? triggerUrl="";
  DateTime startTime=DateTime.fromMicrosecondsSinceEpoch(0), endTime= DateTime.fromMicrosecondsSinceEpoch(0);
 
  ImageItem(this.source, this.url, this.description, this.startTime, this.endTime, this.imageIdent, this.triggerUrl, this.copyright);

  ImageItem.fromMap(Map map) {
    source = map["Source"]!;
    url = map["Url"]!;
    description = map["Description"]!;
    startTime = DateTime.parse(map["StartTime"]!);
    endTime = DateTime.parse(map["EndTime"]!);
    imageIdent = map["ImageIdent"]!;
    triggerUrl = map["TriggerUrl"]!;
    copyright = map["Copyright"]!;
  }
}
