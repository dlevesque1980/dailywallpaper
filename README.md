# Daily Wallpaper

Daily Wallpaper displays wallpaper records prepared by an external service and
stored in the Supabase `wallpapers` table. The Flutter app reads each record's
Cloudinary `image_url`, displays that image as-is, and can apply it to the
Android home screen and optionally the lock screen.

## Requirements

- Flutter SDK with Dart `>=3.4.3 <4.0.0`
- Android API 31 or later (Android 12+), for native AVIF image decoding
- A Supabase project with the `wallpapers` table and public read access enabled

## Setup

1. Install packages:

   ```bash
   flutter pub get
   ```

2. Run the app with the project's public URL and publishable key (or provide
   those values through a local `dart_defines.json` file):

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://ncfpyfwvawyyyiqfpzwk.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
   ```

   The ignored local `dart_defines.json` can use this shape:

   ```json
   {
     "SUPABASE_URL": "https://ncfpyfwvawyyyiqfpzwk.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
   }
   ```

   The project URL is configured in the app. The key is compiled into the
   client and is public. **Never pass a Supabase secret key (such as
   `sb_secret_...`) or legacy `service_role` key to the app.** Secret keys must
   only be used by a trusted server. The app deliberately does not bundle or
   read `.env`.

3. Configure Supabase Row Level Security so the `anon` role can `SELECT` rows
   from `public.wallpapers`, and cannot insert, update, or delete them. The app
   is read-only; image generation and crop preparation belong to the external
   service. For a public read-only wallpaper catalog, the policy is:

   ```sql
   alter table public.wallpapers enable row level security;

   create policy "Public can read wallpapers"
   on public.wallpapers
   for select
   to anon
   using (true);
   ```

4. Run on an Android 12+ device:

   ```bash
   flutter run --dart-define-from-file=dart_defines.json
   ```

5. Set up global downloader settings:

   - Apply `20261025120000_create_downloader_settings.sql`,
     `20261025130000_add_pexels_categories_to_downloader_settings.sql`, and
     `20261025140000_limit_pexels_categories_to_three.sql` in order in the
     Supabase SQL Editor (or with `supabase db push`). The global row stores the
     NASA toggle and selected Pexels categories, limited to three.
   - Apply `20261025150000_add_category_to_wallpapers.sql` to add the nullable
     `wallpapers.category` column. The service inserting Pexels images must set
     this to that image's category; Bing and NASA rows leave it `NULL`.
   - The app reads and updates those settings directly with the public
     `SUPABASE_PUBLISHABLE_KEY`; no Supabase account or sign-in is required.
     Row-level security allows anonymous updates only to the downloader
     settings columns, with database constraints limiting Pexels selection to
     one through three supported categories. Never put a secret key in
     `dart_defines.json`, `.env` bundled with Flutter, or the app.

## Data and behavior

- The home screen displays the records for the newest available `date`.
- History and its date selector query Supabase directly.
- Images are loaded from the provided Cloudinary URL; there is no local
  SQLite database, image-analysis/ML pipeline, smart crop, or background
  fetcher.
- The setting for applying the selected image to the lock screen remains local.
- NASA and Pexels downloader options are stored in
  `public.downloader_settings`; the app and downloader read the same global
  settings row.
- Previously cached SQLite wallpaper history is not migrated.

## Tests and analysis

```bash
flutter test
flutter analyze
```
