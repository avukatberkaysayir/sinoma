-- 022_word_lists.sql
-- Dictionary-only word lists (Berkay 2026-07-17): the learner can collect words
-- found in Sözlük into their own lists — create / rename / delete a list, add or
-- drop words. Deliberately SEPARATE from `playlists` (those hold video clips);
-- same shape and same own-rows-only RLS so both read the same way.

create table if not exists public.word_lists (
  id         uuid primary key default gen_random_uuid(),
  uid        uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.word_list_items (
  list_id  uuid not null references public.word_lists(id) on delete cascade,
  word_id  text not null references public.dictionary(id) on delete cascade,
  uid      uuid not null references auth.users(id) on delete cascade,
  added_at timestamptz not null default now(),
  primary key (list_id, word_id)
);

create index if not exists word_lists_uid_idx      on public.word_lists(uid);
create index if not exists word_list_items_uid_idx on public.word_list_items(uid);

alter table public.word_lists      enable row level security;
alter table public.word_list_items enable row level security;

-- Own rows only (mirrors the playlists policies).
drop policy if exists "Own word lists select" on public.word_lists;
create policy "Own word lists select" on public.word_lists
  for select using (auth.uid() = uid);
drop policy if exists "Own word lists insert" on public.word_lists;
create policy "Own word lists insert" on public.word_lists
  for insert with check (auth.uid() = uid);
drop policy if exists "Own word lists update" on public.word_lists;
create policy "Own word lists update" on public.word_lists
  for update using (auth.uid() = uid) with check (auth.uid() = uid);
drop policy if exists "Own word lists delete" on public.word_lists;
create policy "Own word lists delete" on public.word_lists
  for delete using (auth.uid() = uid);

drop policy if exists "Own word items select" on public.word_list_items;
create policy "Own word items select" on public.word_list_items
  for select using (auth.uid() = uid);
drop policy if exists "Own word items insert" on public.word_list_items;
create policy "Own word items insert" on public.word_list_items
  for insert with check (auth.uid() = uid);
drop policy if exists "Own word items delete" on public.word_list_items;
create policy "Own word items delete" on public.word_list_items
  for delete using (auth.uid() = uid);
