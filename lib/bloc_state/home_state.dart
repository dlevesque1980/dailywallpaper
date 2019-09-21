import 'package:dailywallpaper/models/image_item.dart';

class HomeState {
  List<ImageItem> _list;
  int _imageIndex;

  HomeState(this._list, this._imageIndex);

  List<ImageItem> get list => _list;
  int get imageIndex => _imageIndex;
}
