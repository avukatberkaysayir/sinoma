-- Per-language landmark photo descriptions. The admin can now override the
-- bundled translation for every UI language, not just TR/EN. Stored as a
-- {lang: text} JSON map; desc_tr/desc_en stay as a mirror for legacy reads.
alter table public.path_assets
  add column if not exists desc_i18n jsonb not null default '{}'::jsonb;

-- Backfill the map from any existing TR/EN overrides.
update public.path_assets
   set desc_i18n = (
         coalesce(desc_i18n, '{}'::jsonb)
         || case when coalesce(desc_tr,'') <> '' then jsonb_build_object('tr', desc_tr) else '{}'::jsonb end
         || case when coalesce(desc_en,'') <> '' then jsonb_build_object('en', desc_en) else '{}'::jsonb end
       )
 where kind = 'photo' and (coalesce(desc_tr,'') <> '' or coalesce(desc_en,'') <> '');

notify pgrst, 'reload schema';
