---
trigger: always_on
---

# Instructions Système : Architecture Flutter, BLoC & RxDart (Refactoring Master)

Ce document fusionne les principes de Clean Architecture, les contraintes de performance Android et la gestion rigoureuse des flux avec BLoC/RxDart pour éliminer les "God Classes".

## 1. Structure & Organisation (Anti-God-Class)
- **Feature-First** : Organisation par fonctionnalité dans `lib/features/[feature_name]/`.
- **Vertical Slices** : Chaque feature contient ses propres dossiers `bloc/`, `data/`, et `presentation/`.
- **Loi des 250** : Aucun fichier ne doit dépasser **250 lignes**. Si la logique est trop complexe, extraire dans des **UseCases** (logique métier pure) ou des services spécialisés.
- **Repositories** : Abstraire systématiquement les sources de données (API `http`, base locale `sqflite`, `shared_preferences`).

## 2. Définition des BLoCs & RxDart
- **Dart 3.0+** : Utilisation obligatoire de `sealed class` pour les `Events` et les `States`.
- **Immuabilité** : Utilisation de `built_value` (ou `freezed`/`equatable`) pour garantir que l'état ne peut pas être muté accidentellement.
- **Opérateurs RxDart** : Utiliser `rxdart` (ex: `debounceTime`, `switchMap`, `combineLatest`) pour traiter les flux de données complexes avant d'émettre un état.
- **États Standardisés** : Un flux doit inclure : `Initial`, `Loading`, `Loaded` (Success), et `Error`.
- **Sécurité Asynchrone** : Toujours vérifier `if (!isClosed)` avant chaque `emit` après une opération `await`.

## 3. Gestion des Dépendances (Plugins Android)
- **Isolation des Plugins** : Les appels directs à `google_mlkit_subject_segmentation`, `setwallpaper`, `device_info_plus`, etc., sont interdits dans l'UI ou les BLoCs. Ils doivent résider dans des classes `Service` ou `DataSource` injectées.
- **Injection par Constructeur** : Toutes les dépendances (Repositories/Services) doivent être passées au constructeur du BLoC pour faciliter les tests et le découplage.
- **Environnement** : Utiliser `flutter_dotenv` pour toutes les configurations sensibles.

## 4. UI & Présentation
- **Séparation Stricte** : Aucune logique métier ou transformation de données brute dans les widgets.
- **Interaction BLoC** :
    - **Action** : `context.read<MyBloc>().add(MyEvent())`.
    - **UI** : `BlocBuilder<MyBloc, MyState>` avec `buildWhen` pour optimiser la performance (important pour `flutter_html`).
    - **Effets (Toasts/Navigation)** : `BlocListener<MyBloc, MyState>` pour `fluttertoast` et `url_launcher`.
- **Localisation** : Utiliser `intl` pour extraire toutes les chaînes de caractères.

## 5. Conventions de Nommage
- **Events** : `[Sujet] + [Action] + Event` (ex: `WallpaperUpdateRequested`).
- **States** : `[Sujet] + [Statut] + State` (ex: `WallpaperUpdateSuccess`).
- **Handlers** : Préfixer les méthodes de gestion par `_on` (ex: `on<MyEvent>(_onMyEvent)`).

## 6. Gestion d'Erreur
- Interdiction des blocs `catch` vides.
- Chaque erreur doit émettre un état `Error` contenant un objet d'erreur structuré ou un message traduit via `intl`.