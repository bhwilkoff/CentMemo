-- The person's chosen ground (Decision 059), stored with their account so it
-- follows them between the website and the iPhone. Owner-only; agents read,
-- never write (Decision 056).
create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  ground text not null default 'aqua'
    check (ground in ('aqua', 'sky', 'salmon', 'apricot', 'citron', 'pistachio')),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
revoke all on public.profiles from anon;
grant select, insert, update, delete on public.profiles to authenticated;
create policy owner_select on public.profiles for select to authenticated using (user_id = (select auth.uid()));
create policy owner_insert on public.profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy owner_update on public.profiles for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy owner_delete on public.profiles for delete to authenticated using (user_id = (select auth.uid()));
create policy agents_cannot_insert on public.profiles as restrictive for insert to authenticated with check ((select private.not_an_agent()));
create policy agents_cannot_update on public.profiles as restrictive for update to authenticated using ((select private.not_an_agent()));
create policy agents_cannot_delete on public.profiles as restrictive for delete to authenticated using ((select private.not_an_agent()));
create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();
