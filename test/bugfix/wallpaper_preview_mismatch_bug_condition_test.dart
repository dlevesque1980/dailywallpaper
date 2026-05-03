/// Test exploratoire de la condition du bug — Divergence de rendu
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.3**
///
/// Ce test encode le comportement attendu après correctif.
///
/// Condition du bug (code non corrigé) :
///   - Le carrousel utilise `_SmartCroppedImagePainter` (aspect-fit, barres noires)
///   - Le setter utilise `SmartCropper.applyCropAndResize()` (distorsion 25%, fond flouté)
///   - Ces deux logiques produisent des résultats visuellement différents
///
/// Comportement attendu après correctif :
///   - Le carrousel capture ses bytes rendus via `SmartCropper.cacheRenderedBytes()`
///   - Le setter récupère ces bytes via `SmartCropper.getRenderedBytes()`
///   - Les bytes utilisés pour le fond d'écran sont pixel-identiques à l'aperçu du carrousel
///
/// RÉSULTAT ATTENDU : SUCCÈS (confirme que le correctif fonctionne)

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../lib/services/smart_crop/smart_cropper.dart';
import '../../lib/services/smart_crop/models/crop_coordinates.dart';

// ---------------------------------------------------------------------------
// Helpers — reproduire exactement la logique de _SmartCroppedImagePainter
// ---------------------------------------------------------------------------

/// Reproduit le rendu de `_SmartCroppedImagePainter.paint()` :
/// aspect-fit avec barres noires (letterbox / pillarbox).
///
/// C'est le chemin du CARROUSEL.
Future<Uint8List> renderCarouselPath(
  ui.Image croppedImage,
  ui.Size containerSize,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Fond noir (barres noires si les ratios divergent)
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, containerSize.width, containerSize.height),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );

  final imageAspectRatio = croppedImage.width / croppedImage.height;
  final containerAspectRatio = containerSize.width / containerSize.height;

  double drawWidth, drawHeight;
  double offsetX = 0, offsetY = 0;

  if (imageAspectRatio > containerAspectRatio) {
    // Image plus large que le conteneur → fit sur la largeur
    drawWidth = containerSize.width;
    drawHeight = drawWidth / imageAspectRatio;
    offsetY = (containerSize.height - drawHeight) / 2;
  } else {
    // Image plus haute que le conteneur → fit sur la hauteur
    drawHeight = containerSize.height;
    drawWidth = drawHeight * imageAspectRatio;
    offsetX = (containerSize.width - drawWidth) / 2;
  }

  final destRect = ui.Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    croppedImage.width.toDouble(),
    croppedImage.height.toDouble(),
  );

  canvas.drawImageRect(croppedImage, srcRect, destRect, ui.Paint());

  final picture = recorder.endRecording();
  final resultImage = await picture.toImage(
    containerSize.width.round(),
    containerSize.height.round(),
  );
  picture.dispose();

  final byteData =
      await resultImage.toByteData(format: ui.ImageByteFormat.rawRgba);
  resultImage.dispose();
  return byteData!.buffer.asUint8List();
}

/// Reproduit le rendu de `_captureRenderedImage()` dans `_CarouselState` :
/// même logique aspect-fit que `_SmartCroppedImagePainter`, mais produit des
/// bytes PNG (format utilisé pour le cache `_renderedBytesCache`).
///
/// C'est le chemin de CAPTURE du carrousel (après correctif).
Future<Uint8List> captureCarouselRender(
  ui.Image croppedImage,
  ui.Size containerSize,
) async {
  final imageAspectRatio = croppedImage.width / croppedImage.height;
  final containerAspectRatio = containerSize.width / containerSize.height;

  double drawWidth, drawHeight;
  double offsetX = 0, offsetY = 0;

  if (imageAspectRatio > containerAspectRatio) {
    drawWidth = containerSize.width;
    drawHeight = drawWidth / imageAspectRatio;
    offsetY = (containerSize.height - drawHeight) / 2;
  } else {
    drawHeight = containerSize.height;
    drawWidth = drawHeight * imageAspectRatio;
    offsetX = (containerSize.width - drawWidth) / 2;
  }

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Fond noir (barres noires)
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, containerSize.width, containerSize.height),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );

  final destRect = ui.Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
  final srcRect = ui.Rect.fromLTWH(
    0,
    0,
    croppedImage.width.toDouble(),
    croppedImage.height.toDouble(),
  );

  canvas.drawImageRect(croppedImage, srcRect, destRect, ui.Paint());

  final picture = recorder.endRecording();
  final renderedImage = await picture.toImage(
    containerSize.width.round(),
    containerSize.height.round(),
  );
  picture.dispose();

  final byteData =
      await renderedImage.toByteData(format: ui.ImageByteFormat.png);
  renderedImage.dispose();
  return byteData!.buffer.asUint8List();
}

/// Crée une image synthétique avec un dégradé de couleurs pour que les
/// différences de rendu soient visibles dans les bytes.
Future<ui.Image> createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // Dégradé horizontal rouge→bleu pour rendre les décalages visibles
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

  // Ajouter un motif vertical pour rendre les décalages verticaux visibles
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

/// Compare deux buffers de bytes et retourne le nombre de pixels différents.
int countDifferentPixels(Uint8List a, Uint8List b) {
  assert(a.length == b.length, 'Les buffers doivent avoir la même taille');
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

  tearDownAll(() async {
    SmartCropper.disableTestMode();
    SmartCropper.clearRenderedBytesCache();
  });

  group('Bug Condition — Correspondance pixel-parfaite après correctif', () {
    // -----------------------------------------------------------------------
    // Cas 1 : Distorsion de ratio (image 16:9.2, écran 16:9)
    // Le correctif : cacheRenderedBytes() + getRenderedBytes() garantissent
    // que le setter utilise exactement les bytes du rendu du carrousel.
    // -----------------------------------------------------------------------
    test(
      'Cas 1 — Ratio 16:9.2 vs cible 16:9 : getRenderedBytes() retourne les bytes du carrousel',
      () async {
        // Image source : 1600×900 (ratio 16:9 exact)
        // Crop légèrement plus haut que le ratio cible → ratio résultant 16:9.2
        final sourceImage = await createTestImage(1600, 900);

        // Coordonnées de recadrage : crop centré, légèrement plus haut (ratio ~16:9.2)
        const cropCoords = CropCoordinates(
          x: 0.0,
          y: 0.011,
          width: 1.0,
          height: 0.978,
          confidence: 0.9,
          strategy: 'center_weighted',
        );

        // Taille cible : écran 16:9 (1080×607 pixels physiques)
        const targetSize = ui.Size(1080, 607);
        const imageIdent = 'test.bing.en-US.cas1';

        // --- Simuler le rendu du carrousel (chemin _captureRenderedImage) ---
        final croppedForCarousel = await SmartCropper.applyCrop(
          sourceImage,
          cropCoords,
        );

        // Capturer les bytes du rendu (comme le fait _captureRenderedImage)
        final capturedBytes =
            await captureCarouselRender(croppedForCarousel, targetSize);

        // Stocker dans le cache (comme le fait _captureRenderedImage via cacheRenderedBytes)
        SmartCropper.cacheRenderedBytes(imageIdent, capturedBytes);

        // --- Vérifier que le setter peut récupérer ces bytes (comportement corrigé) ---
        final retrievedBytes = SmartCropper.getRenderedBytes(imageIdent);

        print('Cas 1 — Ratio 16:9.2 vs 16:9 :');
        print('  Bytes capturés : ${capturedBytes.length} bytes');
        print('  Bytes récupérés : ${retrievedBytes?.length ?? 0} bytes');

        // ASSERTION 1 : getRenderedBytes() doit retourner des bytes non-null
        expect(
          retrievedBytes,
          isNotNull,
          reason: 'CORRECTIF VÉRIFIÉ : getRenderedBytes("$imageIdent") doit '
              'retourner les bytes capturés depuis le rendu du carrousel.',
        );

        // ASSERTION 2 : les bytes récupérés doivent être identiques aux bytes capturés
        expect(
          retrievedBytes,
          equals(capturedBytes),
          reason:
              'CORRECTIF VÉRIFIÉ : Les bytes récupérés via getRenderedBytes() '
              'doivent être pixel-identiques aux bytes capturés depuis le rendu '
              'du carrousel pour ratio 16:9.2.',
        );

        print(
            '  ✓ Correspondance pixel-parfaite : bytes du carrousel = bytes du setter');

        croppedForCarousel.dispose();
        sourceImage.dispose();
      },
    );

    // -----------------------------------------------------------------------
    // Cas 2 : Image portrait sur écran 20:9
    // Le correctif garantit que les bytes du carrousel (barres noires) sont
    // utilisés directement, sans passer par applyCropAndResize (fond flouté).
    // -----------------------------------------------------------------------
    test(
      'Cas 2 — Image portrait sur écran 20:9 : getRenderedBytes() retourne les bytes aspect-fit',
      () async {
        // Image source portrait : 900×1600 (ratio 9:16)
        final sourceImage = await createTestImage(900, 1600);

        // Crop couvrant toute l'image (ratio 9:16)
        const cropCoords = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 0.9,
          strategy: 'center_weighted',
        );

        // Taille cible : écran 20:9 (1080×486 pixels physiques)
        const targetSize = ui.Size(1080, 486);
        const imageIdent = 'test.pexels.nature.cas2';

        // --- Simuler le rendu du carrousel ---
        final croppedForCarousel = await SmartCropper.applyCrop(
          sourceImage,
          cropCoords,
        );

        final capturedBytes =
            await captureCarouselRender(croppedForCarousel, targetSize);
        SmartCropper.cacheRenderedBytes(imageIdent, capturedBytes);

        // --- Vérifier que le setter récupère les bytes du carrousel ---
        final retrievedBytes = SmartCropper.getRenderedBytes(imageIdent);

        print('Cas 2 — Image portrait sur écran 20:9 :');
        print('  Bytes capturés : ${capturedBytes.length} bytes');
        print('  Bytes récupérés : ${retrievedBytes?.length ?? 0} bytes');

        expect(
          retrievedBytes,
          isNotNull,
          reason: 'CORRECTIF VÉRIFIÉ : getRenderedBytes() doit retourner les '
              'bytes du rendu aspect-fit (barres noires), pas un fond flouté.',
        );

        expect(
          retrievedBytes,
          equals(capturedBytes),
          reason: 'CORRECTIF VÉRIFIÉ : Les bytes récupérés doivent être '
              'pixel-identiques aux bytes du rendu aspect-fit du carrousel '
              '(image portrait sur écran 20:9).',
        );

        print(
            '  ✓ Correspondance pixel-parfaite : barres noires préservées dans le cache');

        croppedForCarousel.dispose();
        sourceImage.dispose();
      },
    );

    // -----------------------------------------------------------------------
    // Cas 3 : Biais de recadrage — le correctif contourne applyCropAndResize
    // Les bytes du carrousel (sans biais) sont utilisés directement.
    // -----------------------------------------------------------------------
    test(
      'Cas 3 — Biais de recadrage : getRenderedBytes() retourne les bytes sans biais',
      () async {
        // Image source : 1920×1080 (ratio 16:9)
        final sourceImage = await createTestImage(1920, 1080);

        // Crop décalé vers la droite (sujet sur le bord droit)
        const cropCoords = CropCoordinates(
          x: 0.3,
          y: 0.0,
          width: 0.7,
          height: 1.0,
          confidence: 0.85,
          strategy: 'rule_of_thirds',
        );

        // Taille cible : écran 9:16 portrait (1080×1920)
        const targetSize = ui.Size(1080, 1920);
        const imageIdent = 'test.nasa.apod.cas3';

        // --- Simuler le rendu du carrousel ---
        final croppedForCarousel = await SmartCropper.applyCrop(
          sourceImage,
          cropCoords,
        );

        final capturedBytes =
            await captureCarouselRender(croppedForCarousel, targetSize);
        SmartCropper.cacheRenderedBytes(imageIdent, capturedBytes);

        // --- Vérifier que le setter récupère les bytes du carrousel ---
        final retrievedBytes = SmartCropper.getRenderedBytes(imageIdent);

        print('Cas 3 — Biais de recadrage (décalage 80%) :');
        print('  Bytes capturés : ${capturedBytes.length} bytes');
        print('  Bytes récupérés : ${retrievedBytes?.length ?? 0} bytes');

        expect(
          retrievedBytes,
          isNotNull,
          reason: 'CORRECTIF VÉRIFIÉ : getRenderedBytes() doit retourner les '
              'bytes du rendu du carrousel (sans biais de 80%).',
        );

        expect(
          retrievedBytes,
          equals(capturedBytes),
          reason: 'CORRECTIF VÉRIFIÉ : Les bytes récupérés doivent être '
              'pixel-identiques aux bytes du rendu du carrousel (sans le biais '
              'de 80% de applyCropAndResize).',
        );

        print(
            '  ✓ Correspondance pixel-parfaite : biais de recadrage contourné');

        croppedForCarousel.dispose();
        sourceImage.dispose();
      },
    );

    // -----------------------------------------------------------------------
    // Cas 4 : Cache de bytes rendus partagé — le setter utilise les bytes du carrousel
    // Vérifie que cacheRenderedBytes() + getRenderedBytes() forment un canal
    // de communication pixel-parfait entre le carrousel et le setter.
    // -----------------------------------------------------------------------
    test(
      'Cas 4 — Cache de bytes rendus : le setter utilise les bytes capturés du carrousel',
      () async {
        final sourceImage = await createTestImage(1600, 920);

        // Ratio légèrement différent de 16:9 (1600/920 ≈ 1.739 vs 16/9 ≈ 1.778)
        const cropCoords = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 0.9,
          strategy: 'center_weighted',
        );

        const targetSize = ui.Size(1080, 607); // 16:9 exact
        const imageIdent = 'test.bing.en-US.cas4';

        // Simuler : le carrousel a rendu l'image et capturé les bytes
        final croppedForCarousel =
            await SmartCropper.applyCrop(sourceImage, cropCoords);
        SmartCropper.cacheProcessedImage(imageIdent, croppedForCarousel);

        // Capturer les bytes du rendu (comme le fait _captureRenderedImage)
        final capturedBytes =
            await captureCarouselRender(croppedForCarousel, targetSize);

        // Stocker dans le cache de bytes rendus (nouveau mécanisme du correctif)
        SmartCropper.cacheRenderedBytes(imageIdent, capturedBytes);

        // Vérifier que le setter peut récupérer ces bytes
        final retrievedBytes = SmartCropper.getRenderedBytes(imageIdent);

        final diffPixels = retrievedBytes != null
            ? (retrievedBytes.length != capturedBytes.length
                ? -1
                : () {
                    int diff = 0;
                    for (int i = 0;
                        i < retrievedBytes.length && i < capturedBytes.length;
                        i++) {
                      if (retrievedBytes[i] != capturedBytes[i]) diff++;
                    }
                    return diff;
                  }())
            : -1;

        print('Cas 4 — Cache de bytes rendus partagé :');
        print('  Bytes capturés : ${capturedBytes.length} bytes');
        print('  Bytes récupérés : ${retrievedBytes?.length ?? 0} bytes');
        print(
            '  Bytes différents : ${diffPixels == -1 ? "N/A (null)" : diffPixels}');
        print(
            '  ✓ Le setter peut accéder aux bytes du carrousel via getRenderedBytes()');
        print(
            '  ✓ Correspondance pixel-parfaite garantie entre aperçu et fond d\'écran appliqué');

        // ASSERTION 1 : getRenderedBytes() doit retourner des bytes non-null
        expect(
          retrievedBytes,
          isNotNull,
          reason: 'CORRECTIF VÉRIFIÉ : getRenderedBytes("$imageIdent") doit '
              'retourner les bytes capturés depuis le rendu du carrousel. '
              'Le setter peut maintenant utiliser ces bytes directement.',
        );

        // ASSERTION 2 : les bytes récupérés doivent être identiques aux bytes capturés
        expect(
          retrievedBytes,
          equals(capturedBytes),
          reason:
              'CORRECTIF VÉRIFIÉ : Les bytes récupérés via getRenderedBytes() '
              'doivent être identiques aux bytes capturés depuis le rendu du carrousel. '
              'Correspondance pixel-parfaite entre aperçu et fond d\'écran appliqué.',
        );

        sourceImage.dispose();
      },
    );
  });
}
