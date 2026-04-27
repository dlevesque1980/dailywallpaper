# Stratégie de Tests Optimisée

## Tests à conserver (priorité haute)

### Tests unitaires essentiels
- `test/services/smart_crop/smart_cropper_test.dart` - Test principal du système
- `test/bloc/history_bloc_test.dart` - Logique métier critique
- `test/helper/database_helper_test.dart` - Persistance des données
- `test/api/nasa_service_test.dart` - API principale

### Tests d'intégration critiques
- `test/services/smart_crop/final_integration_test.dart` - Test end-to-end du smart crop
- Un seul test d'intégration history (pas les 4 actuels)

## Tests à supprimer ou fusionner

### Tests redondants d'analyseurs
Au lieu de 10 tests séparés d'analyseurs, créer un seul test paramétré qui teste tous les analyseurs avec les mêmes scénarios de base.

### Tests de performance
Garder seulement les benchmarks essentiels, supprimer les tests de performance détaillés qui sont plus appropriés pour le profiling manuel.

### Tests d'intégration UI
Les tests d'intégration de navigation qui timeout constamment - les remplacer par des tests unitaires des widgets.

## Nouvelle organisation

```
test/
├── unit/                    # Tests rapides (<100ms chacun)
│   ├── services/
│   ├── bloc/
│   └── models/
├── integration/             # Tests critiques seulement
│   ├── smart_crop_e2e_test.dart
│   └── history_core_test.dart
└── performance/             # Tests manuels uniquement
    └── benchmarks.dart
```

## Tags pour exécution sélective

Utiliser les tags Flutter pour catégoriser :
- `@Tags(['unit'])` - Tests rapides quotidiens
- `@Tags(['integration'])` - Tests avant merge
- `@Tags(['performance'])` - Tests manuels
- `@Tags(['flaky'])` - Tests instables à investiguer