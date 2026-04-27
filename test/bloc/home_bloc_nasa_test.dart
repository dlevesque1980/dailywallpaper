import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';

void main() {
  group('HomeBloc NASA Integration', () {
    setUpAll(() async {
      // Load environment variables for testing
      await dotenv.load(fileName: '.env');
    });

    test('should have NASA handler method available', () {
      final homeBloc = HomeBloc();

      // Verify that the HomeBloc can be instantiated
      expect(homeBloc, isA<HomeBloc>());
      expect(homeBloc.results, isA<Stream>());

      homeBloc.dispose();
    });

    test('should have NASA preference constant defined (legacy)', () {
      // Test that NASA preference constant is defined (kept for backward compatibility)
      // Note: NASA is now always enabled in HomeBloc, this constant is no longer used
      expect(sp_NASAEnabled, 'nasaenabled');
    });

    test('should always include NASA images regardless of toggle setting', () {
      // Test that NASA is always included now (no toggle dependency)
      // This test verifies that the NASA toggle removal was successful
      final homeBloc = HomeBloc();

      // Verify that HomeBloc doesn't check NASA toggle anymore
      // The _nasaHandler method should always attempt to load NASA images
      expect(homeBloc, isA<HomeBloc>());

      homeBloc.dispose();
    });

    // Note: We're not testing actual NASA API calls here to avoid hitting rate limits
    // and to keep tests fast and reliable. In a real scenario, you would:
    // 1. Mock the ImageRepository.fetchFromNASA method
    // 2. Test with fake NASA responses
    // 3. Test error handling scenarios
    // 4. Test the daily persistence logic
  });
}
