import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/bloc_state/pexels_categories_state.dart';
import 'package:dailywallpaper/prefs/pref_consts.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('PexelsCategoriesBloc', () {
    test('should create bloc instance', () {
      final bloc = PexelsCategoriesBloc();
      expect(bloc, isA<PexelsCategoriesBloc>());
      expect(bloc.categories, isA<Stream<PexelsCategoriesState>>());
      expect(bloc.categoriesQuery, isA<Sink<List<String>>>());
      bloc.dispose();
    });

    test('should have default categories available', () {
      expect(defaultPexelsCategories, isNotEmpty);
      expect(defaultPexelsCategories, contains('nature'));
      expect(defaultPexelsCategories, contains('landscape'));
      expect(defaultPexelsCategories.length, equals(10));
    });
  });

  group('PexelsCategoriesState', () {
    test('should create state with categories', () {
      const available = ['cat1', 'cat2', 'cat3'];
      const selected = ['cat1', 'cat2'];
      
      final state = PexelsCategoriesState(available, selected);
      
      expect(state.availableCategories, equals(available));
      expect(state.selectedCategories, equals(selected));
    });

    test('should implement equality correctly', () {
      const available = ['cat1', 'cat2'];
      const selected = ['cat1'];
      
      final state1 = PexelsCategoriesState(available, selected);
      final state2 = PexelsCategoriesState(available, selected);
      final state3 = PexelsCategoriesState(available, ['cat2']);
      
      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('should have proper toString implementation', () {
      const available = ['cat1', 'cat2'];
      const selected = ['cat1'];
      
      final state = PexelsCategoriesState(available, selected);
      final stringRepresentation = state.toString();
      
      expect(stringRepresentation, contains('PexelsCategoriesState'));
      expect(stringRepresentation, contains('cat1'));
      expect(stringRepresentation, contains('cat2'));
    });
  });
}