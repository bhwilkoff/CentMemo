-- W7 (Decision 069): a memo link can carry up to three pictures the person chose (each
-- checked on their device for money first). They live in a public bucket under the
-- link's own code, so only someone holding the link can find them, and they are
-- deleted when the link is turned off. Only the link's maker can add or remove them;
-- the connector never can.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shared', 'shared', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

create policy shared_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'shared' and exists (
    select 1 from public.shares s where s.code = (storage.foldername(name))[1] and s.user_id = (select auth.uid()) and s.kind = 'memo'));
create policy shared_owner_select on storage.objects for select to authenticated
  using (bucket_id = 'shared' and owner_id = (select auth.uid())::text);
create policy shared_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'shared' and owner_id = (select auth.uid())::text);
create policy shared_agents_cannot_insert on storage.objects as restrictive for insert to authenticated
  with check (bucket_id <> 'shared' or (select private.not_an_agent()));
create policy shared_agents_cannot_delete on storage.objects as restrictive for delete to authenticated
  using (bucket_id <> 'shared' or (select private.not_an_agent()));

-- The page learns how many pictures to show. Set once, by the maker, right after the
-- link is made (the link itself still never changes its words).
create function public.set_share_pictures(p_code text, p_count int) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.not_an_agent() then raise exception 'A link is made by the person, in CentMemo.'; end if;
  if p_count not between 1 and 3 then raise exception 'A link holds one to three pictures.'; end if;
  update public.shares set payload = payload || jsonb_build_object('pictures', p_count)
   where code = p_code and user_id = (select auth.uid()) and kind = 'memo'
     and not payload ? 'pictures' and created_at > now() - interval '10 minutes';
  if not found then raise exception 'That link can''t take pictures now.'; end if;
end; $$;
revoke execute on function public.set_share_pictures(text, int) from public, anon;
grant execute on function public.set_share_pictures(text, int) to authenticated;
