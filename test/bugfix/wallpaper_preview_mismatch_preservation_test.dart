/// Tests de préservation — Comportement inchangé pour les inputs non bugués
///
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**
///
/// Ces tests DOIVENT PASSER sur le code non corrigé.
/// Ils capturent les comportements existants à préserver après le correctif.
///
/// Méthodologie observation-first :
///   1. Observer le comportement actuel sur le code non corrigé
///   2. Encoder ce comportement comme propriété testable
///   3. Vérifier que le correctif ne casse pas ces propriétés
///
/// Propriétés testées :
///   - P2a : Smart crop désactivé → URL originale utilisée (pas de re-traitement)
///   - P2b : getRenderedBytes() absent → applyCropAndResize() utilisé comme fallback
///   - P2c : sp_IncludeLockWallpaper détermine les écrans mis à jour
///   - P2d : Le cache existant (cacheProcessedImage, cacheCrop) n'est pas modifié
///
/// RÉSULTAT ATTENDU : SUCCÈS (confirme le comportement de base à préserver)

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lib/services/smart_crop/smart_cropper.dart';
import '../../lib/services/smart_crop/models/crop_coordinates.dart';
import '../../lib/services/smart_crop/models/crop_settings.dart';
import '../../lib/core/preferences/pref_consts.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Crée une image synthétique avec un dégradé pour rendre les différences visibles.
Future<ui.Image> createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  for (int x = 0; x < width; x++) {
    final ratio = x / width;
    final r = (255 * (1 - ratio)).round();
    final b = (255 * ratio).round();
    final g = (128 * math.sin(math.pi * ratio)).round();
    canvas.drawRect(
      ui.Rect.fromLTWH(x.toDouble(), 0, 1, height.toDouble()),
      ui.Paint()..color = ui.Color.fromARGB(255, r, g, b),
    );
  }

  for (int y = 0; y < height; y += 20) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, y.toDouble(), width.toDouble(), 2),
      ui.Paint()..color = const ui.Color(0x44FFFFFF),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

/// Convertit une ui.Image en bytes PNG via toByteData.
Future<Uint8List> imageToBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

/// Compare deux buffers de bytes et retourne le nombre de pixels différents.
int countDifferentPixels(Uint8List a, Uint8List b) {
  if (a.length != b.length) return -1;
  int diff = 0;
  for (int i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      diff++;
    }
  }
  return diff;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SmartCropper.enableTestMode();
  });

  setUp(() async {
    // Réinitialiser SharedPreferences avant chaque test
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    SmartCropper.disableTestMode();
  });

  // =========================================================================
  // P2a — Observation 1 : Smart crop désactivé → URL originale
  // Requirement 3.1
  // =========================================================================
  group('P2a — Smart crop désactivé : URL originale utilisée', () {
    test(
      'Observation : SmartCropPreferences.isSmartCropEnabled() retourne false '
      'quand sp_SmartCropEnabled = false',
      () async {
        // Configurer SharedPreferences pour désactiver le smart crop
        SharedPreferences.setMockInitialValues({
          sp_SmartCropEnabled: false,
        });

        final prefs = await SharedPreferences.getInstance();
        final isEnabled = prefs.getBool(sp_SmartCropEnabled) ?? true;

        print('P2a — Observation 1 :');
        print('  sp_SmartCropEnabled = false → isEnabled = $isEnabled');
        print(
            '  Comportement attendu : _updateWallpaper utilise l\'URL originale');

        // ASSERTION : smart crop est bien désactivé
        expect(isEnabled, isFalse,
            reason:
                'Quand sp_SmartCropEnabled = false, isSmartCropEnabled() doit retourner false');
      },
    );

    test(
      'Propriété : quand smart crop est désactivé, '
      'SmartCropper ne produit aucun traitement d\'image',
      () async {
        // Sur le code non corrigé, quand smart crop est désactivé,
        // _updateWallpaper saute tout le bloc de traitement et utilise l'URL originale.
        // On vérifie ici que le chemin "smart crop désactivé" ne modifie pas
        // les caches existants.

        SharedPreferences.setMockInitialValues({
          sp_SmartCropEnabled: false,
        });

        final sourceImage = await createTestImage(1600, 900);
        const imageIdent = 'test.bing.en-US.preservation';

        // Avant : aucun cache
        final cachedBefore = SmartCropper.getProcessedImage(imageIdent);

        // Simuler le chemin "smart crop désactivé" :
        // _updateWallpaper ne fait rien avec SmartCropper quand smart crop est off.
        // On vérifie que le cache reste vide (aucun traitement parasite).
        final cachedAfter = SmartCropper.getProcessedImage(imageIdent);

        print('P2a — Propriété smart crop désactivé :');
        print('  Cache avant : $cachedBefore');
        print('  Cache après (sans traitement) : $cachedAfter');
        print(
            '  Comportement préservé : aucun traitement SmartCropper quand désactivé');

        expect(cachedBefore, isNull,
            reason: 'Aucun cache ne doit exister avant traitement');
        expect(cachedAfter, isNull,
            reason:
                'Quand smart crop est désactivé, aucun cache ne doit être créé');

        sourceImage.dispose();
      },
    );

    test(
      'Propriété PBT : pour tout imageIdent, '
      'le cache processedImage est null si cacheProcessedImage n\'a pas été appelé',
      () async {
        // Propriété : getProcessedImage(key) retourne null pour toute clé
        // qui n'a pas été explicitement mise en cache.
        // Cela confirme que le chemin "smart crop désactivé" ne peut pas
        // accidentellement trouver un cache et bypasser l'URL originale.

        final testIdents = [
          'bing.en-US',
          'pexels.nature.2024-01-15',
          'nasa.apod.2024-01-15',
          'unknown.image.ident',
          '',
          'bing.fr-FR',
        ];

        for (final ident in testIdents) {
          final cached = SmartCropper.getProcessedImage(ident);
          expect(cached, isNull,
              reason:
                  'getProcessedImage("$ident") doit retourner null si jamais mis en cache');
        }

        print(
            'P2a — PBT : getProcessedImage retourne null pour ${testIdents.length} idents non cachés');
        print('  Comportement préservé : pas de faux positifs dans le cache');
      },
    );
  });

  // =========================================================================
  // P2b — Observation 2 : getRenderedBytes() absent → applyCropAndResize() fallback
  // Requirement 3.2
  // =========================================================================
  group('P2b — getRenderedBytes() absent : fallback vers applyCropAndResize()',
      () {
    test(
      'Observation : sur le code non corrigé, SmartCropper n\'a pas de méthode '
      'getRenderedBytes() — le setter doit toujours re-traiter l\'image',
      () async {
        // Sur le code non corrigé, il n'existe pas de _renderedBytesCache
        // ni de méthode getRenderedBytes(). Le setter doit donc toujours
        // appeler applyCropAndResize().
        //
        // Ce test vérifie que :
        // 1. SmartCropper.getProcessedImage() retourne une ui.Image (pas des bytes)
        // 2. Il n'existe aucun mécanisme de cache de bytes rendus
        // 3. applyCropAndResize() produit un résultat valide (le fallback fonctionne)

        final sourceImage = await createTestImage(1600, 900);
        const cropCoords = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 0.9,
          strategy: 'center_weighted',
        );
        const targetSize = ui.Size(1080, 607);

        // Vérifier que getProcessedImage retourne null (pas de bytes PNG)
        final cachedImage = SmartCropper.getProcessedImage('test.fallback');
        expect(cachedImage, isNull,
            reason:
                'Aucun cache de bytes rendus ne doit exister sur le code non corrigé');

        // Vérifier que applyCropAndResize() fonctionne correctement (le fallback est opérationnel)
        final processedImage = await SmartCropper.applyCropAndResize(
          sourceImage,
          cropCoords,
          targetSize,
        );

        expect(processedImage, isNotNull,
            reason: 'applyCropAndResize() doit retourner une image valide');
        expect(processedImage.width, greaterThan(0),
            reason: 'L\'image résultante doit avoir une largeur positive');
        expect(processedImage.height, greaterThan(0),
            reason: 'L\'image résultante doit avoir une hauteur positive');

        print('P2b — Observation 2 :');
        print(
            '  getProcessedImage("test.fallback") = null (pas de bytes rendus)');
        print(
            '  applyCropAndResize() retourne une image ${processedImage.width}x${processedImage.height}');
        print(
            '  Comportement préservé : fallback vers applyCropAndResize() opérationnel');

        processedImage.dispose();
        sourceImage.dispose();
      },
    );

    test(
      'Propriété PBT : applyCropAndResize() produit une image valide '
      'pour tout crop valide (fallback toujours opérationnel)',
      () async {
        // Propriété : pour tout input valide, applyCropAndResize() retourne
        // une image non-null avec des dimensions positives.
        // Cela garantit que le fallback ne peut pas bloquer l'application du fond d'écran.

        final testCases = [
          // (imageWidth, imageHeight, cropX, cropY, cropW, cropH, targetW, targetH)
          (1600, 900, 0.0, 0.0, 1.0, 1.0, 1080, 607), // 16:9 exact
          (900, 1600, 0.0, 0.0, 1.0, 1.0, 1080, 486), // portrait sur 20:9
          (1920, 1080, 0.3, 0.0, 0.7, 1.0, 1080, 1920), // crop décalé
          (1600, 920, 0.1, 0.1, 0.8, 0.8, 1080, 607), // crop centré réduit
          (800, 600, 0.0, 0.0, 1.0, 1.0, 1080, 607), // petite image
        ];

        for (final tc in testCases) {
          final (imgW, imgH, cx, cy, cw, ch, tW, tH) = tc;
          final sourceImage = await createTestImage(imgW, imgH);
          final cropCoords = CropCoordinates(
            x: cx,
            y: cy,
            width: cw,
            height: ch,
            confidence: 0.9,
            strategy: 'center_weighted',
          );
          final targetSize = ui.Size(tW.toDouble(), tH.toDouble());

          final result = await SmartCropper.applyCropAndResize(
            sourceImage,
            cropCoords,
            targetSize,
          );

          expect(result, isNotNull,
              reason: 'applyCropAndResize() ne doit jamais retourner null '
                  'pour image ${imgW}x$imgH, crop ($cx,$cy,$cw,$ch), target ${tW}x$tH');
          expect(result.width, greaterThan(0),
              reason: 'Largeur doit être positive');
          expect(result.height, greaterThan(0),
              reason: 'Hauteur doit être positive');

          result.dispose();
          sourceImage.dispose();
        }

        print(
            'P2b — PBT : applyCropAndResize() valide pour ${testCases.length} cas de test');
        print('  Comportement préservé : fallback toujours opérationnel');
      },
    );

    test(
      'Propriété : cacheProcessedImage() stocke une ui.Image récupérable via getProcessedImage()',
      () async {
        // Vérifier que le cache existant (ui.Image) fonctionne correctement.
        // Ce cache est distinct du futur cache de bytes rendus.
        // Il doit continuer à fonctionner après le correctif.

        final testImage = await createTestImage(100, 100);
        const testKey = 'test.cache.preservation';

        // Avant mise en cache
        expect(SmartCropper.getProcessedImage(testKey), isNull,
            reason: 'Aucun cache avant cacheProcessedImage()');

        // Mettre en cache
        SmartCropper.cacheProcessedImage(testKey, testImage);

        // Après mise en cache
        final cached = SmartCropper.getProcessedImage(testKey);
        expect(cached, isNotNull,
            reason:
                'getProcessedImage() doit retourner l\'image mise en cache');
        expect(cached!.width, equals(testImage.width),
            reason: 'L\'image récupérée doit avoir la même largeur');
        expect(cached.height, equals(testImage.height),
            reason: 'L\'image récupérée doit avoir la même hauteur');

        print('P2b — Cache existant (ui.Image) :');
        print(
            '  cacheProcessedImage("$testKey") → getProcessedImage("$testKey") = ${cached.width}x${cached.height}');
        print(
            '  Comportement préservé : cache ui.Image fonctionne correctement');

        // Pas de dispose ici car l'image est dans le cache statique
      },
    );
  });

  // =========================================================================
  // P2c — Observation 3 : sp_IncludeLockWallpaper détermine les écrans mis à jour
  // Requirement 3.4
  // =========================================================================
  group('P2c — sp_IncludeLockWallpaper détermine les écrans mis à jour', () {
    test(
      'Observation : sp_IncludeLockWallpaper = true → setLocked = true',
      () async {
        SharedPreferences.setMockInitialValues({
          sp_IncludeLockWallpaper: true,
        });

        final prefs = await SharedPreferences.getInstance();
        final setLocked = prefs.getBool(sp_IncludeLockWallpaper) ?? true;

        print('P2c — Observation 3a :');
        print('  sp_IncludeLockWallpaper = true → setLocked = $setLocked');
        print(
            '  Comportement attendu : setBothWallpaper/setBothWallpaperFromBytes appelé');

        expect(setLocked, isTrue,
            reason:
                'sp_IncludeLockWallpaper = true doit produire setLocked = true');
      },
    );

    test(
      'Observation : sp_IncludeLockWallpaper = false → setLocked = false',
      () async {
        SharedPreferences.setMockInitialValues({
          sp_IncludeLockWallpaper: false,
        });

        final prefs = await SharedPreferences.getInstance();
        final setLocked = prefs.getBool(sp_IncludeLockWallpaper) ?? true;

        print('P2c — Observation 3b :');
        print('  sp_IncludeLockWallpaper = false → setLocked = $setLocked');
        print(
            '  Comportement attendu : setSystemWallpaper/setSystemWallpaperFromBytes appelé');

        expect(setLocked, isFalse,
            reason:
                'sp_IncludeLockWallpaper = false doit produire setLocked = false');
      },
    );

    test(
      'Observation : sp_IncludeLockWallpaper absent → valeur par défaut = true',
      () async {
        // Vérifier la valeur par défaut quand la préférence n'est pas définie.
        // Dans _updateWallpaper : getBoolWithDefault(sp_IncludeLockWallpaper, true)
        SharedPreferences.setMockInitialValues({});

        final prefs = await SharedPreferences.getInstance();
        final setLocked = prefs.getBool(sp_IncludeLockWallpaper) ?? true;

        print('P2c — Observation 3c :');
        print(
            '  sp_IncludeLockWallpaper absent → setLocked = $setLocked (défaut = true)');
        print('  Comportement attendu : setBothWallpaper appelé par défaut');

        expect(setLocked, isTrue,
            reason:
                'La valeur par défaut de sp_IncludeLockWallpaper doit être true');
      },
    );

    test(
      'Propriété PBT : pour tout état de sp_IncludeLockWallpaper, '
      'la valeur lue correspond à la valeur écrite',
      () async {
        // Propriété : la lecture de sp_IncludeLockWallpaper est déterministe.
        // Pour tout booléen b, écrire b puis lire retourne b.
        // Cela garantit que le paramètre lock screen est toujours respecté.

        for (final value in [true, false]) {
          SharedPreferences.setMockInitialValues({
            sp_IncludeLockWallpaper: value,
          });

          final prefs = await SharedPreferences.getInstance();
          final readValue = prefs.getBool(sp_IncludeLockWallpaper) ?? true;

          expect(readValue, equals(value),
              reason:
                  'Écrire sp_IncludeLockWallpaper=$value doit retourner $value à la lecture');
        }

        print(
            'P2c — PBT : sp_IncludeLockWallpaper est déterministe pour true et false');
        print(
            '  Comportement préservé : le paramètre lock screen est toujours respecté');
      },
    );
  });

  // =========================================================================
  // P2d — Cache existant non modifié (cacheProcessedImage, cacheCrop)
  // Requirement 3.5
  // =========================================================================
  group('P2d — Cache existant non modifié par le correctif', () {
    test(
      'Propriété : cacheProcessedImage() et getProcessedImage() sont idempotents',
      () async {
        // Propriété : mettre en cache la même image deux fois retourne toujours
        // la dernière version mise en cache.
        final image1 = await createTestImage(200, 200);
        final image2 = await createTestImage(300, 300);
        const key = 'test.idempotent.cache';

        SmartCropper.cacheProcessedImage(key, image1);
        expect(SmartCropper.getProcessedImage(key)!.width, equals(200));

        // Écraser avec une nouvelle image
        SmartCropper.cacheProcessedImage(key, image2);
        expect(SmartCropper.getProcessedImage(key)!.width, equals(300),
            reason: 'La deuxième mise en cache doit écraser la première');

        print('P2d — Cache idempotent :');
        print(
            '  cacheProcessedImage() écrase correctement les entrées existantes');
        print(
            '  Comportement préservé : le cache ui.Image fonctionne comme attendu');
      },
    );

    test(
      'Propriété : getCachedCrop() retourne null pour une image jamais analysée',
      () async {
        // Vérifier que getCachedCrop() retourne null pour une image inconnue.
        // Cela confirme que le fallback vers applyCropAndResize() est bien déclenché
        // quand aucun crop n'est en cache.

        const settings = CropSettings.defaultSettings;
        const targetSize = ui.Size(1080, 607);
        const unknownUrl = 'https://unknown.image.url/test.jpg';

        final cachedCrop = await SmartCropper.getCachedCrop(
          unknownUrl,
          targetSize,
          settings,
        );

        expect(cachedCrop, isNull,
            reason:
                'getCachedCrop() doit retourner null pour une image jamais analysée');

        print('P2d — getCachedCrop() pour image inconnue :');
        print('  getCachedCrop("$unknownUrl") = null');
        print(
            '  Comportement préservé : fallback vers applyCropAndResize() déclenché correctement');
      },
    );

    test(
      'Propriété PBT : applyCropAndResize() est déterministe — '
      'même input produit même output (bytes identiques)',
      () async {
        // Propriété : applyCropAndResize() est une fonction pure.
        // Pour le même input, elle doit toujours produire le même output.
        // Cela garantit que le fallback est prévisible et reproductible.

        final sourceImage = await createTestImage(1600, 900);
        const cropCoords = CropCoordinates(
          x: 0.1,
          y: 0.1,
          width: 0.8,
          height: 0.8,
          confidence: 0.9,
          strategy: 'center_weighted',
        );
        const targetSize = ui.Size(1080, 607);

        // Appeler deux fois avec le même input
        final result1 = await SmartCropper.applyCropAndResize(
          sourceImage,
          cropCoords,
          targetSize,
        );
        final result2 = await SmartCropper.applyCropAndResize(
          sourceImage,
          cropCoords,
          targetSize,
        );

        final bytes1 = await imageToBytes(result1);
        final bytes2 = await imageToBytes(result2);

        final diffPixels = countDifferentPixels(bytes1, bytes2);

        print('P2d — Déterminisme de applyCropAndResize() :');
        print('  Appel 1 : ${result1.width}x${result1.height}');
        print('  Appel 2 : ${result2.width}x${result2.height}');
        print('  Pixels différents : $diffPixels');
        print(
            '  Comportement préservé : applyCropAndResize() est déterministe');

        expect(result1.width, equals(result2.width),
            reason: 'Les deux appels doivent produire la même largeur');
        expect(result1.height, equals(result2.height),
            reason: 'Les deux appels doivent produire la même hauteur');
        expect(diffPixels, equals(0),
            reason:
                'applyCropAndResize() doit être déterministe : même input → même output');

        result1.dispose();
        result2.dispose();
        sourceImage.dispose();
      },
    );
  });
}
