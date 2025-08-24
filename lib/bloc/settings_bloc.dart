import 'dart:async';

import 'package:dailywallpaper/api/image_repository.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/prefs/pref_consts.dart';
import 'package:dailywallpaper/prefs/pref_helper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop.dart';
import 'package:rxdart/rxdart.dart';

class SettingsBloc {
  Stream<BingRegionState> _regions = Stream.empty();
  Stream<List<RegionItem>> _thumbnail = Stream.empty();
  Stream<bool> _includeLock = Stream.empty();
  Stream<bool> _nasaEnabled = Stream.empty();
  Stream<bool> _smartCropEnabled = Stream.empty();
  Stream<CropAggressiveness> _smartCropAggressiveness = Stream.empty();
  Stream<CropSettings> _smartCropSettings = Stream.empty();
  Stream<Map<String, dynamic>> _cacheStatistics = Stream.empty();
  var _regionQuery = BehaviorSubject<String>();
  var _thumbnailQuery = BehaviorSubject<String>();
  var _lockQuery = BehaviorSubject<String>();
  var _nasaQuery = BehaviorSubject<String>();
  var _smartCropEnabledQuery = BehaviorSubject<String>();
  var _smartCropAggressivenessQuery = BehaviorSubject<String>();
  var _smartCropSettingsQuery = BehaviorSubject<String>();
  var _cacheStatisticsQuery = BehaviorSubject<String>();

  Stream<BingRegionState> get regions => _regions;
  Stream<List<RegionItem>> get thumbnail => _thumbnail;

  Sink<String> get regionQuery => _regionQuery;
  Sink<String> get thumbnailQuery => _thumbnailQuery;
  Sink<String> get lockQuery => _lockQuery;
  Sink<String> get nasaQuery => _nasaQuery;
  Sink<String> get smartCropEnabledQuery => _smartCropEnabledQuery;
  Sink<String> get smartCropAggressivenessQuery => _smartCropAggressivenessQuery;
  Sink<String> get smartCropSettingsQuery => _smartCropSettingsQuery;
  Sink<String> get cacheStatisticsQuery => _cacheStatisticsQuery;
  Stream<bool> get includeLock => _includeLock;
  Stream<bool> get nasaEnabled => _nasaEnabled;
  Stream<bool> get smartCropEnabled => _smartCropEnabled;
  Stream<CropAggressiveness> get smartCropAggressiveness => _smartCropAggressiveness;
  Stream<CropSettings> get smartCropSettings => _smartCropSettings;
  Stream<Map<String, dynamic>> get cacheStatistics => _cacheStatistics;

  SettingsBloc() {
    _regions = _regionQuery.asyncMap(_handlerBingRegion).asBroadcastStream();
    _includeLock = _lockQuery
        .distinct()
        .asyncMap(_getIncludeLockSetting)
        .asBroadcastStream();
    _nasaEnabled = _nasaQuery
        .distinct()
        .asyncMap(_getNASAEnabledSetting)
        .asBroadcastStream();
    _smartCropEnabled = _smartCropEnabledQuery
        .distinct()
        .asyncMap(_getSmartCropEnabledSetting)
        .asBroadcastStream();
    _smartCropAggressiveness = _smartCropAggressivenessQuery
        .distinct()
        .asyncMap(_getSmartCropAggressivenessSetting)
        .asBroadcastStream();
    _smartCropSettings = _smartCropSettingsQuery
        .distinct()
        .asyncMap(_getSmartCropSettings)
        .asBroadcastStream();
    _cacheStatistics = _cacheStatisticsQuery
        .distinct()
        .asyncMap(_getCacheStatistics)
        .asBroadcastStream();
    _thumbnail =
        _thumbnailQuery.asyncMap(_handlerThumbnail).asBroadcastStream();
  }

  Future<bool> _getIncludeLockSetting(String value) async {
    if (value != "")
      await PrefHelper.setBool(sp_IncludeLockWallpaper, (value == "true"));
    return await PrefHelper.getBool(sp_IncludeLockWallpaper);
  }

  Future<bool> _getNASAEnabledSetting(String value) async {
    if (value != "")
      await PrefHelper.setBool(sp_NASAEnabled, (value == "true"));
    return await PrefHelper.getBool(sp_NASAEnabled);
  }

  Future<bool> _getSmartCropEnabledSetting(String value) async {
    if (value != "")
      await SmartCropPreferences.setSmartCropEnabled(value == "true");
    return await SmartCropPreferences.isSmartCropEnabled();
  }

  Future<CropAggressiveness> _getSmartCropAggressivenessSetting(String value) async {
    if (value != "") {
      final aggressiveness = CropAggressiveness.values.firstWhere(
        (e) => e.name == value,
        orElse: () => CropAggressiveness.balanced,
      );
      await SmartCropPreferences.setCropAggressiveness(aggressiveness);
    }
    return await SmartCropPreferences.getCropAggressiveness();
  }

  Future<CropSettings> _getSmartCropSettings(String value) async {
    if (value != "") {
      // Parse the settings update from JSON-like string
      try {
        final settings = CropSettings.fromJson(value);
        await SmartCropPreferences.saveCropSettings(settings);
      } catch (e) {
        // If parsing fails, just return current settings
      }
    }
    return await SmartCropPreferences.getCropSettings();
  }

  Future<Map<String, dynamic>> _getCacheStatistics(String value) async {
    // The value parameter is used to trigger refresh, but we always return current stats
    return await SmartCropPreferences.getCacheStatistics();
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
    _nasaQuery.close();
    _smartCropEnabledQuery.close();
    _smartCropAggressivenessQuery.close();
    _smartCropSettingsQuery.close();
    _cacheStatisticsQuery.close();
  }
}
