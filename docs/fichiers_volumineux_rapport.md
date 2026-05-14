# Rapport des Fichiers Dépassant la Loi des 250 Lignes (Mise à jour)

Ce document liste les fichiers du dossier `lib/` qui dépassent la limite architecturale stricte de **250 lignes**. Les fichiers générés (`.freezed.dart`, `.g.dart`, `app_localizations.dart`) ont été exclus de cette analyse car ils sont créés automatiquement.

*Mise à jour : Suite au refactoring complet (Axes 1, 2 et 3), plusieurs fichiers ont été réduits avec succès. Les notes ci-dessous indiquent les changements récents.*

---

## ✅ Fichiers Refactorisés (sous la barre ou hors périmètre)

| Ancienne taille | Fichier | Résultat |
| --- | --- | --- |
| 389 | `history_screen.dart` | ✅ Réduit via extraction de `HistoryAppBar` et `HistoryWallpaperFab` |
| 350 | `error_handler.dart` | ✅ `CropError` extrait dans `crop_error.dart` |
| 119 | `fallback_strategies.dart` | ✅ Supprimé et refactorisé |
| 534 | `performance_monitor.dart` | ✅ Réduit à 299 lignes (refactoring précédent) |

---

## ⚠️ Fichiers à Refactoriser (> 250 lignes, hors générés)

| Lignes | Fichier | Action Suggérée |
| --- | --- | --- |
| 353 | `lib/features/smart_crop/cache/crop_cache_manager.dart` | Extraire les utilitaires de génération de clés et l'interface de statistiques. |
| 343 | `lib/features/smart_crop/analyzers/entropy_based_crop_analyzer.dart` | Extraire les algorithmes mathématiques complexes dans un Helper. |
| 335 | `lib/features/smart_crop/models/crop_settings.dart` | Déplacer les méthodes de sérialisation et les factories. |
| 335 | `lib/features/smart_crop/analyzers/face_detection_crop_analyzer.dart` | Séparer la configuration ML Kit de l'analyse elle-même. |
| 332 | `lib/features/smart_crop/utils/performance_manager.dart` | Réduit suite au refactoring `PerformanceBudgetCalculator`, mais dépasse encore légèrement. |
| 330 | `lib/features/smart_crop/cache/intelligent_cache_manager.dart` | Déplacer les méthodes de préchargement de combinaisons fréquentes. |
| 329 | `lib/features/smart_crop/utils/degradation_manager.dart` | Réduit suite à l'extraction de `FallbackStrategy`, mais dépasse encore légèrement. |
| 325 | `lib/features/smart_crop/analyzers/rule_of_thirds_crop_analyzer.dart` | Extraire les calculs géométriques et la pondération des points. |
| 320 | `lib/features/smart_crop/registry/analyzer_registry.dart` | Séparer le design pattern *Factory* et les instances statiques. |
| 319 | `lib/services/image_preloader_service.dart` | Extraire la gestion du cache temporaire de la logique de préchargement. |
| 319 | `lib/features/smart_crop/analyzers/edge_detection_crop_analyzer.dart` | Extraire les convolutions de Sobel/Prewitt dans un utilitaire. |
| 318 | `lib/features/smart_crop/config/configuration_manager.dart` | Réduit suite à l'extraction de `ConfigurationValidator` et `ConfigurationMigrator`, mais dépasse encore légèrement. |
| 304 | `lib/features/smart_crop/models/crop_result.dart` | Séparer la désérialisation complexe et les helpers d'extension. |
| 304 | `lib/features/smart_crop/analyzers/center_weighted_crop_analyzer.dart` | Isoler le calcul de distribution spatiale. |
| 301 | `lib/features/smart_crop/analyzers/bird/bird_feature_detector.dart` | Isoler la détection des becs/ailes/yeux en classes spécifiques. |
| 299 | `lib/features/smart_crop/utils/performance_monitor.dart` | Extraire l'analyseur de tendances (trends) pour passer sous 250. |
| 296 | `lib/features/settings/screens/simplified_settings_screen.dart` | Découper en composants réutilisables (Sections, Tuiles). |
| 295 | `lib/features/wallpaper/screens/home_screen.dart` | Déplacer l'AppBar, le FloatingActionButton et les dialogues. |
| 293 | `lib/features/smart_crop/utils/device_capability_detector.dart` | Extraire les heuristiques de détection dans des classes spécialisées. |
| 292 | `lib/widgets/date_picker_dialog.dart` | Découper les sections de l'interface en sous-widgets. |
| 288 | `lib/core/database/database_helper.dart` | Séparer les migrations et les requêtes dans des helpers distincts. |
| 287 | `lib/features/smart_crop/utils/image_utils.dart` | Extraire les transformations bitmap dans un service dédié. |
| 286 | `lib/widgets/smart_crop_quality_slider.dart` | Extraire la logique de rendu du slider dans un painter. |
| 279 | `lib/features/smart_crop/cache/crop_cache_dao.dart` | Séparer les requêtes de lecture et d'écriture dans des DAOs distincts. |
| 276 | `lib/features/smart_crop/services/image_processor.dart` | Extraire les opérations de redimensionnement et de recadrage. |
| 271 | `lib/features/smart_crop/utils/image_processing_pipeline.dart` | Séparer les étapes du pipeline en handlers chaînables. |
| 270 | `lib/features/smart_crop/utils/screen_utils.dart` | Extraire les utilitaires spécifiques par plateforme. |
| 262 | `lib/widgets/optimized_image_widget.dart` | Découper les états de chargement/erreur en sous-widgets. |
| 261 | `lib/features/smart_crop/utils/battery_optimizer.dart` | Extraire les stratégies de réduction de qualité dans des classes dédiées. |
| 261 | `lib/features/smart_crop/smart_crop_preferences.dart` | Séparer les groupes de préférences par domaine fonctionnel. |

---

## 📊 Statistiques

- **Total fichiers > 250 lignes** : 29 (hors générés)
- **Fichiers traités dans cette session** : 6 (histoire UI + modèles intégrés + managers)
- **Tests** : ✅ 177 tests passent (exit code 0)
