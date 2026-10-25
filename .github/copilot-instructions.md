# Project Guidelines

## Code Style
- This is a Dart/Flutter app. Format changed Dart files with `dart format` and
  validate with `flutter analyze`.
- Linting is configured in the repository-root `analysis_options.yaml`.
- Freezed unions are generated; update their source declarations and regenerate
  with `dart run build_runner build`.

## Architecture
- UI lives under `lib/features/` and reusable widgets under `lib/widgets/`.
- Feature state and orchestration use `flutter_bloc`.
- The read-only Supabase REST data source is
  `lib/data/datasources/supabase_wallpaper_data_source.dart`; repository
  operations live in `lib/data/repositories/image_repository.dart`.
- `ImageItem` maps a row from the Supabase `wallpapers` table.
- The app renders Cloudinary `image_url` values directly. Image generation and
  crop preparation happen in an external service, not in Flutter.
- Shared Preferences stores the lock-screen option and carousel selection.

## Build & Test
- Install dependencies: `flutter pub get`
- Regenerate Freezed sources: `dart run build_runner build`
- Run on Android 12 or later: `flutter run -d <device>`
- Run tests: `flutter test`
- Analyze: `flutter analyze`

## Configuration and Security
- Supply `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` with Dart build defines.
- The app does not bundle or read `.env`; use only a public publishable key in
  the client. Never use a Supabase secret or legacy `service_role` key there.
- Supabase Row Level Security permits reads of wallpapers and downloader
  settings. Global NASA settings are changed through the authenticated
  `update-downloader-settings` Edge Function; its admin email allowlist and
  secret key stay in Supabase Function secrets.
- Store auth refresh tokens only in secure storage.
- Keep secret keys on a trusted server. Do not commit credentials.

## Android
- The app's Android minimum SDK is 31 for AVIF support.
- Android platform configuration is under `android/`.
