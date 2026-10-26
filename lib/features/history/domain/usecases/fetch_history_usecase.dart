import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';

class FetchHistoryUseCase {
  FetchHistoryUseCase({ImageRepository? imageRepository})
      : _imageRepository = imageRepository ?? ImageRepository();

  final ImageRepository _imageRepository;

  Future<List<DateTime>> getAvailableDates() =>
      _imageRepository.fetchAvailableDates();

  Future<List<ImageItem>> getImagesForDate(DateTime date) =>
      _imageRepository.fetchWallpapersForDate(date);
}
