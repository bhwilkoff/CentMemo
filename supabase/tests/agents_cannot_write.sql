-- Run inside a transaction that is rolled back. Impersonates the owner
-- twice: once as a site session (may write), once as an OAuth agent token
-- carrying client_id (must be refused). Replace :owner with the owner's id.
begin;
select set_config('request.jwt.claims', json_build_object('sub', :'owner', 'role', 'authenticated')::text, true);
set local role authenticated;
update public.transactions set category = category where user_id = :'owner'::uuid;  -- allowed (person)
select set_config('request.jwt.claims', json_build_object('sub', :'owner', 'role', 'authenticated', 'client_id', 'probe-agent')::text, true);
-- each of these must raise or touch 0 rows:
select count(*) as agent_can_read from public.transactions;            -- > 0 expected
insert into public.life_values (name) values ('agent probe');          -- must fail
rollback;
