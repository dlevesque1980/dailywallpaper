# Project Guidelines

## Code Style
- This is a Dart/Flutter app. Use `dart format .` and `flutter analyze` to keep code consistent.
- Linting is configured via `analysis_options.yaml` at the repo root.
- Generated code lives in `*.g.dart` (json_serializable / built_value). Do not edit generated files manually; regenerate them using build_runner.

## Architecture
- UI code lives under `lib/screen/` and reusable widgets under `lib/widget/`.
- Business logic is in `lib/bloc/` + `lib/bloc_state/` and exposed via small InheritedWidget providers in `lib/bloc_provider/` (e.g., `HomeProvider`, `SettingsProvider`).
- HTTP APIs are implemented under `lib/api/` (Bing / Pexels / NASA).
- Models are under `lib/models/` (mix of plain Dart models and `json_serializable` / `built_value`).
- Services such as caching and smart-crop are in `lib/services/`.

## Build & Test
- Install dependencies: `flutter pub get`
- Regenerate generated sources: `flutter pub run build_runner build --delete-conflicting-outputs`
- Run the app: `flutter run -d <device>` (Android only; only Android platform enabled in `pubspec.yaml`).
- Run tests via the provided helper: `dart test_runner.dart unit|integration|all|fast`.
- For analysis: `flutter analyze`.

## Project Conventions
- Configuration is loaded from `.env` (gitignored). Ensure `.env` contains at least `PEXELS_API_KEY` and `NASA_API_KEY`.
- The app uses a local SQLite database (`wallpaper.db`) via `sqflite`.
- Most screens use a stream-based BLoC pattern and a small custom provider layer (no `flutter_bloc` package).

## Integration Points
- Bing Image of the Day is accessed via `lib/api/bing_service.dart` and `bing_data.json`.
- Pexels and NASA require API keys in `.env` (see `lib/api/pexels_service.dart` and `lib/api/nasa_service.dart`).

## Security
- Do not commit `.env` or API keys. `.gitignore` already excludes `.env`.
