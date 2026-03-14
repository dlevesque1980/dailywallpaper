# Guide Rapide - Tests Optimisés

## 🚀 Commandes essentielles

```bash
# Tests rapides (20 secondes) - À utiliser quotidiennement
dart test_runner.dart fast

# Tests unitaires seulement
flutter test --tags=unit

# Tous les tests (si nécessaire)
flutter test
```

## 📝 Écrire de nouveaux tests

### Tests unitaires (rapides)
```dart
test('should do something', () async {
  // Test logic here
}, tags: ['unit']);
```

### Tests d'intégration (plus lents)
```dart
test('should integrate components', () async {
  // Integration test logic
}, tags: ['integration']);
```

## ⚡ Bonnes pratiques

1. **Privilégier les tests unitaires** - Plus rapides et fiables
2. **Éviter les tests d'intégration UI** - Souvent instables
3. **Utiliser des mocks** - Pour isoler les composants
4. **Tests de performance manuels** - Pas dans la suite automatisée

## 🔧 Dépannage

### Test qui timeout
```bash
# Augmenter le timeout
flutter test --timeout=30s
```

### Problème de base de données
```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
});
```

### Nettoyage après tests
```dart
tearDown(() async {
  await SmartCropper.clearCache();
  // Autres nettoyages...
});
```