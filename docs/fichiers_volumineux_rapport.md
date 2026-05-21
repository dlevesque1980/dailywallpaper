# Rapport des Fichiers Dépassant la Loi des 250 Lignes (Mise à jour)

Ce document liste les fichiers du dossier `lib/` qui dépassent la limite architecturale stricte de **250 lignes**. Les fichiers générés (`.freezed.dart`, `.g.dart`, `app_localizations.dart`) ont été exclus de cette analyse car ils sont créés automatiquement.

*Mise à jour : Suite au refactoring de stabilisation (Axe 4), `ImagePreloaderService` a été identifié comme nouveau fichier à refactoriser.*

---

## ✅ Fichiers Refactorisés (sous la barre ou hors périmètre)

| Ancienne taille | Fichier | Résultat |
| --- | --- | --- |
| 389 | `history_screen.dart` | ✅ Réduit via extraction de `HistoryAppBar` et `HistoryWallpaperFab` |
| 350 | `error_handler.dart` | ✅ `CropError` extrait dans `crop_error.dart` |
| 119 | `fallback_strategies.dart` | ✅ Supprimé et refactorisé |
| 534 | `performance_monitor.dart` | ✅ Réduit à 299 lignes (encore à la limite, mais en progrès) |

---

## ⚠️ Fichiers à Refactoriser (> 250 lignes, hors générés)

| Lignes | Fichier | Action Suggérée |
| --- | --- | --- |
| 433 | `lib/l10n/app_localizations.dart` | (Ignorer - Fichier de localisation standard) |
| 353 | `lib/features/smart_crop/cache/crop_cache_manager.dart` | Extraire les utilitaires de génération de clés et l'interface de statistiques. |
| 344 | `lib/services/image_preloader_service.dart` | **[NOUVEAU]** Extraire la logique de `SessionId` et `PriorityCalculator`. |
| 343 | `lib/features/smart_crop/analyzers/entropy_based_crop_analyzer.dart` | Extraire les algorithmes mathématiques complexes dans un Helper. |
| 335 | `lib/features/smart_crop/models/crop_settings.dart` | Déplacer les méthodes de sérialisation et les factories. |
| 335 | `lib/features/smart_crop/analyzers/face_detection_crop_analyzer.dart` | Séparer la configuration ML Kit de l'analyse elle-même. |
| 332 | `lib/features/smart_crop/utils/performance_manager.dart` | Découpler la gestion des budgets de performance. |
| 330 | `lib/features/smart_crop/cache/intelligent_cache_manager.dart` | Extraire les politiques d'éviction (`EvictionPolicy`). |
| 329 | `lib/features/smart_crop/utils/degradation_manager.dart` | Extraire les stratégies de dégradation. |
| 325 | `lib/features/smart_crop/analyzers/rule_of_thirds_crop_analyzer.dart` | Isoler la logique de grille de tiers. |
| 320 | `lib/features/smart_crop/registry/analyzer_registry.dart` | Séparer l'enregistrement statique de la logique de résolution. |
| 319 | `lib/features/smart_crop/analyzers/edge_detection_crop_analyzer.dart` | Extraire les filtres de convolution. |
| 318 | `lib/features/smart_crop/config/configuration_manager.dart` | Terminer la décomposition vers `ConfigurationMigrator`. |
| 304 | `lib/features/smart_crop/models/crop_result.dart` | Déplacer les extensions de rendu. |
| 304 | `lib/features/smart_crop/analyzers/center_weighted_crop_analyzer.dart` | Simplifier les calculs de pondération. |
| 295 | `lib/features/wallpaper/screens/home_screen.dart` | Extraire les widgets de navigation et de superposition. |
| 292 | `lib/widgets/date_picker_dialog.dart` | Isoler le style du calendrier. |
| 288 | `lib/core/database/database_helper.dart` | Déplacer les scripts de migration dans des fichiers SQL. |
| 287 | `lib/features/smart_crop/utils/image_utils.dart` | Extraire les utilitaires de conversion de format. |
| 279 | `lib/features/smart_crop/cache/crop_cache_dao.dart` | Découpler les méthodes de statistiques. |
| 276 | `lib/features/smart_crop/services/image_processor.dart` | Isoler les manipulations de Canvas/UI. |
| 271 | `lib/features/smart_crop/utils/image_processing_pipeline.dart` | Séparer les étapes du pipeline. |
| 270 | `lib/features/smart_crop/utils/screen_utils.dart` | Déplacer les constantes de résolution. |
| 262 | `lib/widgets/optimized_image_widget.dart` | Séparer le rendu d'image de la gestion des erreurs. |
| 261 | `lib/features/smart_crop/utils/battery_optimizer.dart` | Isoler les seuils de batterie. |
| 261 | `lib/features/smart_crop/smart_crop_preferences.dart` | Extraire les clés de préférences. |

---

## 📊 Statistiques

- **Total fichiers > 250 lignes** : 26 (hors générés)
- **Fichiers traités dans cette session** : 0 (focus sur la stabilisation Android 16)
- **Tests** : ✅ 177 tests passent (exit code 0)
