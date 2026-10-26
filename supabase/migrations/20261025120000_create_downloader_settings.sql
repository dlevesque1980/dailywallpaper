create table if not exists public.downloader_settings (
  id text primary key check (id = 'global'),
  include_nasa boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.downloader_settings (id, include_nasa)
values ('global', true)
on conflict (id) do nothing;

alter table public.downloader_settings enable row level security;

revoke all on table public.downloader_settings from anon, authenticated;
grant select on table public.downloader_settings to anon, authenticated;
grant all on table public.downloader_settings to service_role;

drop policy if exists "Anyone can read downloader settings"
  on public.downloader_settings;
create policy "Anyone can read downloader settings"
  on public.downloader_settings
  for select
  to anon, authenticated
  using (true);
