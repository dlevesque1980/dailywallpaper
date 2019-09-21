import 'package:dailywallpaper/models/bing/bing_region_enum.dart';

class RegionItem {
  BingRegionEnum _value;
  String _url;

  BingRegionEnum get value => _value;
  String get url => _url;

  RegionItem(this._value, this._url);
}

class BingRegionState {
  BingRegionEnum _choice;

  BingRegionEnum get choice => _choice;

  BingRegionState(this._choice);
}
