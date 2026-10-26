alter table public.downloader_settings
  add column if not exists pexels_categories text[] not null
  default array['portrait', 'people', 'animals'];

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

revoke insert, update, delete on table public.downloader_settings
  from anon, authenticated;
grant update (include_nasa, pexels_categories, updated_at)
  on table public.downloader_settings to anon, authenticated;

drop policy if exists "Anyone can update downloader settings"
  on public.downloader_settings;
create policy "Anyone can update downloader settings"
  on public.downloader_settings
  for update
  to anon, authenticated
  using (id = 'global')
  with check (id = 'global');
