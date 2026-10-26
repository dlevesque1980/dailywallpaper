alter table public.downloader_settings
  add column if not exists pexels_categories text[] not null
  default array['portrait', 'people', 'animals'];

update public.downloader_settings
set pexels_categories = pexels_categories[1:3]
where cardinality(pexels_categories) > 3;

alter table public.downloader_settings
  drop constraint if exists downloader_settings_pexels_categories_valid;
alter table public.downloader_settings
  add constraint downloader_settings_pexels_categories_valid
  check (
    cardinality(pexels_categories) between 1 and 3
    and pexels_categories <@ array[
      'portrait', 'people', 'animals', 'flowers', 'mountain', 'forest',
      'ocean', 'architecture', 'city', 'landscape', 'nature', 'abstract',
      'minimal'
    ]
  );
