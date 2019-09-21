import 'dart:async';

import 'package:dailywallpaper/bloc_state/home_state.dart';
import 'package:dailywallpaper/helper/datetime_helper.dart';
import 'package:dailywallpaper/prefs/prefs.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/api/image_repository.dart';
import 'package:dailywallpaper/helper/database_helper.dart';
import 'package:setwallpaper/setwallpaper.dart';

class HomeBloc {
  Stream<HomeState> _results = Stream.empty();
  var _query = BehaviorSubject<String>();
  Stream<String> _wallpaper = Stream.empty();
  var _setWallpaper = BehaviorSubject<int>();
  var fetchingInitialData = false;

  Stream<HomeState> get results => _results;
  Sink<String> get query => _query;
  Stream<String> get wallpaper => _wallpaper;
  Sink<int> get setWallpaper => _setWallpaper;
  HomeState state;

  HomeBloc() {
    _results = _query.distinct().asyncMap(_imageHandler).asBroadcastStream();
    _wallpaper = _setWallpaper.asyncMap(_updateWallpaper).asBroadcastStream();
  }

  HomeState initialData(int index) {
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    if (!fetchingInitialData) {
      fetchingInitialData = true;
      Prefs.bingRegion.then((region) {
        Prefs.unsplashCategories.then((categories) {
          var catStr = categories.join(";");

          print("query:$dateStr.$region;$catStr");
          query.add('$dateStr.$region;$catStr');
          fetchingInitialData = false;
        });
      });
    }
    return null;
  }

  Future<HomeState> _imageHandler(String query) async {
    var list = new List<ImageItem>();
    list.add(await _bingHandler(query));
    await for (ImageItem i in _unsplashHandler(query)) {
      list.add(i);
    }
    state = HomeState(list, 0);
    return state;
  }

  Stream<ImageItem> _unsplashHandler(String query) async* {
    var dbHelper = new DatabaseHelper();
    var categories = await Prefs.unsplashCategories;
    for (var cat in categories) {
      ImageItem unsplashImage = await dbHelper.getCurrentImage('unsplash.$cat');
      if (unsplashImage == null) {
        unsplashImage = await ImageRepository.fetchFromUnsplash(cat);
        await dbHelper.insertImage(unsplashImage);
      }
      yield unsplashImage;
    }
  }

  Future<ImageItem> _bingHandler(String query) async {
    ImageItem image;
    var region = await Prefs.bingRegion;
    var dbHelper = new DatabaseHelper();
    image = await dbHelper.getCurrentImage("bing.$region");
    if (image == null) {
      image = await ImageRepository.fetchFromBing(region);
      await dbHelper.insertImage(image);
    }

    return image;
  }

  Future<String> _updateWallpaper(int index) async {
    var setLocked = await Prefs.includeLockWallpaper;
    String message;
    var image = state.list[index];

    if (setLocked) {
      message = await Setwallpaper.setBothWallpaper(image.url);
    } else {
      message = await Setwallpaper.setSystemWallpaper(image.url);
    }

    if (image.triggerUrl != null && image.triggerUrl.isNotEmpty) {
      ImageRepository.triggerUnsplashDownload(image.triggerUrl);
    }

    return message;
  }

  void dispose() {
    _query.close();
    _setWallpaper.close();
  }
}
