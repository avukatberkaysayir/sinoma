-- Admin-managed home (learning-path) design overrides: per (level, unit) you can
-- upload a banner image, the 4 landmark photos (+ TR/EN descriptions) and the 4
-- phase-circle icons, and tune each one's display scale. The path falls back to
-- the bundled assets when there is no override. Files live in the public
-- `path-assets` storage bucket.
insert into storage.buckets (id, name, public, file_size_limit)
values ('path-assets', 'path-assets', true, 8388608)
on conflict (id) do update set public = true;

create table if not exists public.path_assets (
  level      int  not null,
  unit       int  not null,
  kind       text not null,                 -- 'banner' | 'photo' | 'icon'
  slot       int  not null default 0,       -- 0 for banner; 0..3 for photo/icon
  url        text,
  desc_tr    text,
  desc_en    text,
  scale      real default 1.0,
  updated_at timestamptz default now(),
  primary key (level, unit, kind, slot)
);

alter table public.path_assets enable row level security;
drop policy if exists pa_read on public.path_assets;
create policy pa_read on public.path_assets for select using (true);
drop policy if exists pa_admin on public.path_assets;
create policy pa_admin on public.path_assets for all
  using ((auth.jwt()->>'email') = 'berkaysayir@gmail.com')
  with check ((auth.jwt()->>'email') = 'berkaysayir@gmail.com');

-- storage.objects policies for the bucket (public read, admin write).
drop policy if exists pa_obj_read on storage.objects;
create policy pa_obj_read on storage.objects for select using (bucket_id = 'path-assets');
drop policy if exists pa_obj_write on storage.objects;
create policy pa_obj_write on storage.objects for insert
  with check (bucket_id = 'path-assets' and (auth.jwt()->>'email') = 'berkaysayir@gmail.com');
drop policy if exists pa_obj_upd on storage.objects;
create policy pa_obj_upd on storage.objects for update
  using (bucket_id = 'path-assets' and (auth.jwt()->>'email') = 'berkaysayir@gmail.com');
drop policy if exists pa_obj_del on storage.objects;
create policy pa_obj_del on storage.objects for delete
  using (bucket_id = 'path-assets' and (auth.jwt()->>'email') = 'berkaysayir@gmail.com');
