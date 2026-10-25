# Daily Wallpaper — UI/UX

## Product direction

The wallpaper is the interface: show the externally prepared Cloudinary image
edge-to-edge, with only small controls layered over it. The Flutter app does
not analyze, crop, or otherwise transform image content.

## Shared visual language

- Use a black background and white foreground controls for contrast.
- Keep the home and history carousels full-screen and edge-to-edge.
- Keep AppBars transparent and low-elevation.
- Use a light-blue wallpaper action and a green confirmation state.
- Keep loading, empty, and error states explicit and readable.

## Home

- Show records for the newest available Supabase date in a horizontal carousel.
- Render each record's `image_url` directly using `Image.network` and
  `BoxFit.cover`.
- Use the record title when available, otherwise show its source.
- The info sheet shows title, source, credit, and an optional source link.
- The menu contains Settings and History; there are no crop or ML controls.
- The wallpaper action downloads the same URL and passes its bytes to the
  Android wallpaper plugin.

## History

- Select a date from the dates returned by Supabase and display that date's
  wallpaper rows using the same carousel.
- Provide clear loading, empty, retry, and wallpaper-application feedback.

## Settings

- Keep the local preference for applying wallpapers to the lock screen.
- Expose the global NASA downloader option from Supabase. It is read-only until
  an authorized administrator signs in; changes are saved through the Supabase
  Edge Function.
- Do not add source selectors, crop controls, or ML status panels.

## Platform

- Android API 31 is the minimum supported version for AVIF images.
