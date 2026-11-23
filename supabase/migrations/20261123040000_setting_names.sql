-- D8 renames: the person names a Setting ("SQ *JOES COFFEE 1234" -> "Joe's").
-- Keyed by the cleaned name every client already computes (cleanMerchant, one
-- algorithm with a golden), so every past and future visit there takes the
-- person's name; the bank's text stays untouched beside it. Only the person
-- writes it; agents are refused like every other table.
create table public.setting_names (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  setting text not null check (char_length(setting) between 1 and 200),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  updated_at timestamptz not null default now(),
  primary key (user_id, setting)
);

alter table public.setting_names enable row level security;
revoke all on public.setting_names from anon;
grant select, insert, update, delete on public.setting_names to authenticated;
create policy owner_select on public.setting_names for select to authenticated using (user_id = (select auth.uid()));
create policy owner_insert on public.setting_names for insert to authenticated with check (user_id = (select auth.uid()));
create policy owner_update on public.setting_names for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.setting_names for delete to authenticated using (user_id = (select auth.uid()));
create policy agents_cannot_insert on public.setting_names as restrictive for insert to authenticated with check ((select private.not_an_agent()));
create policy agents_cannot_update on public.setting_names as restrictive for update to authenticated using ((select private.not_an_agent()));
create policy agents_cannot_delete on public.setting_names as restrictive for delete to authenticated using ((select private.not_an_agent()));
