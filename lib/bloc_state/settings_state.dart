import 'package:dailywallpaper/models/image_item.dart';

class SettingsState {
  List<ImageItem> _bingImagesList;

  SettingsState(this._bingImagesList);

  List<ImageItem> get bingImagesList => _bingImagesList;
}
