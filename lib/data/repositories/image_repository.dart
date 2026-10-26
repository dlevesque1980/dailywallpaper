import '../datasources/supabase_wallpaper_data_source.dart';
import '../models/image_item.dart';

class ImageRepository {
  ImageRepository({SupabaseWallpaperDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseWallpaperDataSource();

  final SupabaseWallpaperDataSource _dataSource;

  Future<List<ImageItem>> fetchLatestWallpapers() =>
      _dataSource.fetchLatestWallpapers();

  Future<List<DateTime>> fetchAvailableDates() =>
      _dataSource.fetchAvailableDates();

  Future<List<ImageItem>> fetchWallpapersForDate(DateTime date) =>
      _dataSource.fetchWallpapersForDate(date);
}
