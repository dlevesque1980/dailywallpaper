import 'dart:async';

import 'package:dailywallpaper/api/image_repository.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/prefs/pref_consts.dart';
import 'package:dailywallpaper/prefs/pref_helper.dart';
import 'package:rxdart/rxdart.dart';

class SettingsBloc {
  Stream<BingRegionState> _regions = Stream.empty();
  Stream<List<RegionItem>> _thumbnail = Stream.empty();
  Stream<bool> _includeLock = Stream.empty();
  var _regionQuery = BehaviorSubject<String>();
  var _thumbnailQuery = BehaviorSubject<String>();
  var _lockQuery = BehaviorSubject<String>();

  Stream<BingRegionState> get regions => _regions;
  Stream<List<RegionItem>> get thumbnail => _thumbnail;

  Sink<String> get regionQuery => _regionQuery;
  Sink<String> get thumbnailQuery => _thumbnailQuery;
  Sink<String> get lockQuery => _lockQuery;
  Stream<bool> get includeLock => _includeLock;

  SettingsBloc() {
    _regions = _regionQuery.asyncMap(_handlerBingRegion).asBroadcastStream();
    _includeLock = _lockQuery
        .distinct()
        .asyncMap(_getIncludeLockSetting)
        .asBroadcastStream();
    _thumbnail =
        _thumbnailQuery.asyncMap(_handlerThumbnail).asBroadcastStream();
  }

  Future<bool> _getIncludeLockSetting(String value) async {
    if (value != "")
      await PrefHelper.setBool(sp_IncludeLockWallpaper, (value == "true"));
    return await PrefHelper.getBool(sp_IncludeLockWallpaper);
  }

  Stream<RegionItem> _getRegions() async* {
    for (BingRegionEnum region in BingRegionEnum.values) {
      var image = await ImageRepository.fetchThumbnailFromBing(
          BingRegionEnum.definitionOf(region));
      yield RegionItem(region, image.url);
    }
  }

  Future<BingRegionState> _handlerBingRegion(String rg) async {
    if (rg != "") PrefHelper.setString(sp_BingRegion, rg);
    var choice = await _getChoice();
    return new BingRegionState(choice);
  }

  Future<List<RegionItem>> _handlerThumbnail(String query) async {
    var regions = <RegionItem>[];
    await for (var region in _getRegions()) {
      regions.add(region);
    }

    return regions;
  }

  Future<BingRegionEnum> _getChoice() async {
    var val = await PrefHelper.getString(sp_BingRegion);
    return BingRegionEnum.valueFromDefinition(val!);
  }

  void dispose() {
    _lockQuery.close();
    _regionQuery.close();
  }
}
