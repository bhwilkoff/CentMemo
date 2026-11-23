-- D15: where a Setting is. CentMemo predicts the place on the person's phone
-- (statement text + Apple Maps); the person confirms it once and every visit
-- there inherits it. Keyed like setting_names (the cleaned name). It is the
-- business's location, never the person's. Only the person writes it.
create table public.setting_places (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  setting text not null check (char_length(setting) between 1 and 200),
  name text not null check (char_length(btrim(name)) between 1 and 200),
  address text check (char_length(address) <= 400),
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180),
  updated_at timestamptz not null default now(),
  primary key (user_id, setting)
);

alter table public.setting_places enable row level security;
revoke all on public.setting_places from anon;
grant select, insert, update, delete on public.setting_places to authenticated;
create policy owner_select on public.setting_places for select to authenticated using (user_id = (select auth.uid()));
create policy owner_insert on public.setting_places for insert to authenticated with check (user_id = (select auth.uid()));
create policy owner_update on public.setting_places for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.setting_places for delete to authenticated using (user_id = (select auth.uid()));
create policy agents_cannot_insert on public.setting_places as restrictive for insert to authenticated with check ((select private.not_an_agent()));
create policy agents_cannot_update on public.setting_places as restrictive for update to authenticated using ((select private.not_an_agent()));
create policy agents_cannot_delete on public.setting_places as restrictive for delete to authenticated using ((select private.not_an_agent()));
