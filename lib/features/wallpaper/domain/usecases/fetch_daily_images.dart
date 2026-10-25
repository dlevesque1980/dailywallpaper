import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';

class FetchDailyImagesUseCase {
  FetchDailyImagesUseCase({ImageRepository? imageRepository})
      : _imageRepository = imageRepository ?? ImageRepository();

  final ImageRepository _imageRepository;

  Future<List<ImageItem>> call() => _imageRepository.fetchLatestWallpapers();
}
