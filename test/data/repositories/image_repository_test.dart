import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import '../../fakes/fake_data_sources.dart';

void main() {
  group('ImageRepository', () {
    late FakeBingDataSource bing;
    late FakePexelsDataSource pexels;
    late FakeNasaDataSource nasa;
    late ImageRepository repository;

    final testItem = ImageItem(
      'Bing', 
      'https://example.com/image.jpg', 
      'Test Description',
      DateTime.now(), 
      DateTime.now(), 
      'test-id', 
      null, 
      'Test Copyright',
    );

    setUp(() {
      bing = FakeBingDataSource();
      pexels = FakePexelsDataSource();
      nasa = FakeNasaDataSource();
      repository = ImageRepository(
        bingDataSource: bing,
        pexelsDataSource: pexels,
        nasaDataSource: nasa,
      );
    });

    test('fetchFromBing delegates to bingDataSource', () async {
      bing.item = testItem;
      final result = await repository.fetchFromBing('en-US');
      expect(result.imageIdent, 'test-id');
    });

    test('fetchFromNASA delegates to nasaDataSource', () async {
      nasa.item = testItem;
      final result = await repository.fetchFromNASA();
      expect(result.imageIdent, 'test-id');
    });
  });
}
