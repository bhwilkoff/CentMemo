-- delete_my_account removes the person and everything they own, and nothing of
-- anyone else's. Run as the STRANGER synthetic user inside a transaction that is
-- always rolled back (Supabase SQL editor or the MCP execute_sql tool).
-- Expected: user before 1, values before 1, user after 0, values after 0, owner 1.
-- Seen 2026-11-21 with exactly those numbers.
begin;
create temp table probe(step text, n int) on commit drop;
grant all on probe to authenticated;
insert into probe select 'stranger user before', (select count(*) from auth.users where id='ecae8408-e689-4cea-a8a3-05dbe57aa728');
set local role authenticated;
set local request.jwt.claims = '{"sub":"ecae8408-e689-4cea-a8a3-05dbe57aa728","role":"authenticated"}';
insert into public.life_values(user_id, name) values ('ecae8408-e689-4cea-a8a3-05dbe57aa728','deletion probe');
insert into probe select 'stranger values before', (select count(*) from public.life_values);
select public.delete_my_account();
reset role;
insert into probe select 'stranger user after', (select count(*) from auth.users where id='ecae8408-e689-4cea-a8a3-05dbe57aa728');
insert into probe select 'stranger values after', (select count(*) from public.life_values where user_id='ecae8408-e689-4cea-a8a3-05dbe57aa728');
insert into probe select 'owner untouched', (select count(*) from auth.users where id='d08963dd-f1b5-4411-b8cd-53a92080a373');
select * from probe;
rollback;
