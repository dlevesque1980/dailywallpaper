class ImageItem {
  String url, description, imageIdent, triggerUrl, copyright, source;
  DateTime startTime, endTime;

  ImageItem(this.source, this.url, this.description, this.startTime, this.endTime, this.imageIdent, this.triggerUrl, this.copyright);

  ImageItem.fromMap(Map map) {
    source = map["Source"];
    url = map["Url"];
    description = map["Description"];
    startTime = DateTime.parse(map["StartTime"]);
    endTime = DateTime.parse(map["EndTime"]);
    imageIdent = map["ImageIdent"];
    triggerUrl = map["TriggerUrl"];
    copyright = map["Copyright"];
  }
}
