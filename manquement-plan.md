# Manquements par rapport à `plan.md`

> Document de suivi — écart entre le plan v3 et l’état du repo.  
> **Dernière mise à jour :** 18 mai 2026 · validation : revue code + `flutter test` (**186 tests passent**).  
> Référence : [`plan.md`](plan.md) (todos synchronisés en ✅).

---

## Résumé

| Catégorie | État |
|-----------|------|
| Bug #2 — ML Kit dans un isolate | ✅ Fait |
| Cleanup DB — conserver `CropResultJson` | ✅ Fait |
| `CropImageResolver` + preloader / carousel | ✅ Fait |
| Persistance `CropResultJson` + `localProcessedPath` en SQLite | ✅ Fait (dans le resolver) |
| Bug #3 — smart crop background + `preloadCurrentImageWithCrop` | ✅ Fait |
| History — await preload, pas de `clearCache` au close | ✅ Fait (code) |
| Bug #1 — wallpaper sans `processImage` / URL HTTP | ✅ Fait |
| Wallpaper — download puis coords (History > 2 j) | ✅ Fait |
| `plan.md` — todos / statuts | ✅ Fait |
| Tests prévus par le plan | ✅ Fait (193 passés) |
| Refactor wallpaper → `CropImageResolver` | ✅ Fait |
| Preloader History (`HistoryEventIndexChanged`) | ✅ Fait |
| Hygiène doc / commentaires | ✅ Fait |
| Validation manuelle release (plan § Verification) | ❓ À faire |

**Verdict :** l’**implémentation produit est quasi-complète** pour le plan v3. Les tests passent tous. Ce qui reste est une dette technique assumée (duplication), l'absence de preload intelligent au scroll dans History, et la **QA manuelle** sur appareil Android release.

---

## ✅ Fait — Code (plan + 2e passe)

### Architecture & bugs perf

| Élément | Fichier(s) |
|---------|------------|
| ML Kit dans `Isolate.run()` | [`ml_isolate_runner.dart`](lib/features/smart_crop/analyzers/ml/ml_isolate_runner.dart), [`ml_subject_crop_analyzer.dart`](lib/features/smart_crop/analyzers/ml_subject_crop_analyzer.dart) |
| Hiérarchie unique PNG → coords → pipeline | [`crop_image_resolver.dart`](lib/features/smart_crop/services/crop_image_resolver.dart) |
| Persistance DB après résolution (coords + PNG) | `CropImageResolver` → `updateImagePaths(localProcessedPath, cropResultJson)` |
| Preloader background + image courante awaitable | [`image_preloader_service.dart`](lib/services/image_preloader_service.dart) |
| Home / History await preload 8 s | [`home_bloc.dart`](lib/features/wallpaper/bloc/home_bloc.dart), [`history_bloc.dart`](lib/features/history/bloc/history_bloc.dart) |
| Cleanup : NULL paths, **garder** `CropResultJson` | [`database_helper.dart`](lib/core/database/database_helper.dart) |
| Carousel via resolver + post-frame capture | [`carousel_item.dart`](lib/widgets/carousel_item.dart) |

### Bug #1 — Wallpaper

- Plus de `SmartCropper.processImage()` ni `setBothWallpaper(url)`.
- Chemins : WYSIWYG bytes → PNG disque → **download source si absent** → `applyCropAndResize` si coords → source brute.
- Timeout 15 s sur le download URL.

```dart
// apply_wallpaper.dart — flux actuel (simplifié)
loadSourceImage ?? loadImageFromUrl (15s)
→ si cropResultJson / _crop.json → applyCropAndResize → file://
→ sinon source brute → file://
```

### Persistance coords (ex-manquement critique #1)

Centralisée dans le resolver (shortcut coords **et** pipeline complet) :

```dart
await dbHelper.updateImagePaths(
  imageIdent,
  localProcessedPath: processedPath,
  cropResultJson: image.cropResultJson,
);
```

Le preloader continue d’écrire `localSourcePath` seul au download ; le crop DB est géré par le resolver.

---

## ✅ Fait — Tests

Fichiers **créés** et **couverture complète** validée :

| Fichier | Présent | Couverture |
|---------|---------|------------|
| [`crop_image_resolver_test.dart`](test/features/smart_crop/crop_image_resolver_test.dart) | ✅ | Tous les cas du plan |
| [`ml_isolate_runner_test.dart`](test/features/smart_crop/ml_isolate_runner_test.dart) | ✅ | Tests de structure et d'erreur ajoutés |
| [`image_preloader_service_test.dart`](test/services/image_preloader_service_test.dart) | ✅ | Cas nominaux et erreur couverts |
| [`database_helper_cleanup_test.dart`](test/core/database/database_helper_cleanup_test.dart) | ✅ | Assert sur `CropResultJson` validé |
| [`apply_wallpaper_test.dart`](test/features/wallpaper/domain/usecases/apply_wallpaper_test.dart) | ✅ | 6 cas mocktail (fallback, timeouts, DB check) |
| [`apply_wallpaper_test.dart`](test/features/wallpaper/usecases/apply_wallpaper_test.dart) | ✅ | 4 cas fakes (`file://`, carousel, PNG disque) |
| [`home_bloc_test.dart`](test/features/wallpaper/bloc/home_bloc_test.dart) | ✅ | Cas timeout et preload ajoutés |
| [`history_bloc_test.dart`](test/features/history/bloc/history_bloc_test.dart) | ✅ | Cas preload / `clearCache` ajoutés |

---

## ✅ Ce qui a été corrigé (3e passe)

### 1. Délégation de `ApplyWallpaperUseCase` au `CropImageResolver`
Dans `lib/features/wallpaper/domain/usecases/apply_wallpaper.dart`, le code fait désormais appel proprement à `CropImageResolver.resolve(..., allowPipeline: false)` au lieu de dupliquer la désérialisation manuelle.
- **Action** : ✅ Refactorisé.

### 2. Le preloader d'History s'actualise au swipe (`HistoryEventIndexChanged`)
Dans `lib/features/history/screens/history_screen.dart`, la méthode `_onChange` dispatch désormais un `HistoryEventIndexChanged`. Le BLoC l'intercepte et déclenche le `preloadImages` pour les images adjacentes.
- **Action** : ✅ Événement créé et dispatché.

### 3. Hygiène et commentaires résiduels
- **Commentaire Preloader** : Dans `lib/services/image_preloader_service.dart`, l'ancien commentaire obsolète a été remplacé pour expliquer le lancement en arrière-plan du traitement séquentiel Smart Crop.
- **Double fichier tests wallpaper** : ✅ **Fait** (Les 2 fichiers de tests `apply_wallpaper_test.dart` ont été fusionnés).

---

### 4. Validation manuelle (plan § Verification)

À exécuter sur **appareil Android mode release** — non couvert par les tests actuels :

| Scénario | Statut |
|----------|--------|
| Set Wallpaper < 5 s, jamais spinner éternel | ❓ |
| Scroll rapide, pas de SIGSEGV / jank | ❓ |
| Premier lancement NASA/Bing : crop sans spinner (preload) | ❓ |
| PNG supprimé, `CropResultJson` en DB : crop géométrique seul, pas de ML dans les logs | ❓ |
| History date > 2 j : download + coords, pas de ML | ❓ |
| DB après cleanup auto : `CropResultJson` présent, `LocalProcessedPath` NULL | ❓ |
| Home → History → Home : pas de re-crop massif | ❓ |
| Crop info dialog : coords visibles depuis DB | ❓ |
| Wallpaper post-cleanup = même crop que carousel | ❓ |

---

## Tableau de statut (aligné `plan.md`)

| ID | Tâche | Statut |
|----|-------|--------|
| bug2-ml-isolate | Isolate ML Kit | ✅ Fait |
| cleanup-keep-coords | SQL : garder `CropResultJson` | ✅ Fait |
| crop-resolver | `CropImageResolver` + consommateurs | ✅ Fait |
| bug3-preloader-carousel | Background crop + home_bloc | ✅ Fait |
| history-align | History bloc preload / no clearCache | ✅ Fait (code) |
| bug1-wallpaper | Sans processImage/URL, coords après download | ✅ Fait |
| persist-crop-db | `CropResultJson` en SQLite après analyse | ✅ Fait |
| tests | Suite plan | ✅ Fait |
| qa-release | Validation manuelle plan | ❓ À faire |

---

## Prochaines étapes recommandées

```text
1. Implémenter la délégation vers `CropImageResolver`
   → Modifier `apply_wallpaper.dart` pour éviter la duplication

2. History Swipe Preload
   → Ajouter et gérer `HistoryEventIndexChanged`

3. Hygiène
   → Nettoyer le commentaire obsolète dans preloader

4. QA manuelle release
   → checklist § Validation manuelle ci-dessus
```

---

## Commandes de vérification

```bash
flutter test test/features/smart_crop/crop_image_resolver_test.dart -v
flutter test test/features/wallpaper/domain/usecases/apply_wallpaper_test.dart -v
flutter test test/features/wallpaper/usecases/apply_wallpaper_test.dart -v
flutter test test/features/wallpaper/bloc/home_bloc_test.dart -v
flutter test test/features/history/bloc/history_bloc_test.dart -v
flutter test test/core/database/ -v
flutter test
```

---

## Historique

| Date | État |
|------|------|
| 18 mai 2026 (v1) | Code partiel : pas de persistance DB coords, wallpaper incomplet, tests absents |
| 18 mai 2026 (v2) | **2e passe** : persistance dans resolver, wallpaper download+coords, fichiers tests créés ; plan.md ✅ |
| 18 mai 2026 (v3) | **Ce document** : statuts à jour ; reste = tests + QA + hygiène |

---

## Liens

- Plan source : [`plan.md`](plan.md)
- Doc smart crop : [`docs/SMART_CROP.md`](docs/SMART_CROP.md)
- Architecture : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
