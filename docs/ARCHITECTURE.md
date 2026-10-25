# Architecture

Daily Wallpaper is a read-only Flutter client for a Supabase `wallpapers` table.
An external service creates and crops the images, uploads them to Cloudinary,
and writes their ready-to-display URLs and metadata to Supabase.

## Data flow

- `SupabaseWallpaperDataSource` performs authenticated REST `GET` requests
  using the public `SUPABASE_PUBLISHABLE_KEY` build define.
- `ImageRepository` exposes the newest available date and historical records.
- `ImageItem` maps the Supabase row, including the canonical `image_url` and
  optional Cloudinary/crop metadata.
- Home and History BLoCs load records and expose loading, empty, and error
  states.
- `CarouselItem` renders the Cloudinary URL directly. Applying a wallpaper
  downloads the same URL as bytes and passes it to the Android wallpaper
  plugin without running image analysis.

## Supabase access

The app reads `public.wallpapers` and the singleton
`public.downloader_settings` row. It reads and updates the shared NASA option
and Pexels category selection directly through PostgREST with the public
publishable key. No Supabase Auth session or sign-in is used for settings.
Row-level security permits anonymous updates to the settings columns, while
database constraints restrict Pexels categories to the supported options and
limit selection to one through three. The downloader reads
`downloader_settings.include_nasa` and `downloader_settings.pexels_categories`.
Wallpaper rows use nullable `category` for Pexels records; the ingestion
service stores the selected Pexels category on each inserted image, while
Bing and NASA rows leave it null. Daily and history carousels order Bing first,
Pexels by the category selector order, and NASA last. The app bar uses a
source label while the info sheet renders the original title and credit as
HTML, including links.

Pass only `SUPABASE_URL` and the public `SUPABASE_PUBLISHABLE_KEY` as build
defines. The publishable key is included in the client binary and is public by
design. Never pass a secret or legacy service-role key to the app. The app does
not bundle or read `.env`.

## Local state and Android

Shared Preferences stores the lock-screen option and carousel selection.
Wallpaper rows and history are not stored in SQLite. Android's minimum SDK is
31 (Android 12) for AVIF decoding; the app uses the existing Android target
SDK configuration.
