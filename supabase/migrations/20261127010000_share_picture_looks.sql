-- W8 on links: each picture on a memo link keeps how it sat in the memo. 'mounted' keeps
-- its paper mat, 'whole' (a drawing) shows entire on its paper, 'plate' fills its frame.
-- Set in the same one call as the count; builds that send no looks get plates.
drop function public.set_share_pictures(text, int);
create function public.set_share_pictures(p_code text, p_count int, p_looks text[] default null) returns void
language plpgsql security definer set search_path = '' as $$
declare
  looks jsonb;
begin
  if not private.not_an_agent() then raise exception 'A link is made by the person, in CentMemo.'; end if;
  if p_count not between 1 and 3 then raise exception 'A link holds one to three pictures.'; end if;
  select jsonb_agg(private.one_of(l, 'plate', 'mounted', 'whole') order by i) into looks
    from unnest(p_looks[1:p_count]) with ordinality as t(l, i);
  update public.shares set payload = payload || jsonb_strip_nulls(jsonb_build_object('pictures', p_count, 'looks', looks))
   where code = p_code and user_id = (select auth.uid()) and kind = 'memo'
     and not payload ? 'pictures' and created_at > now() - interval '10 minutes';
  if not found then raise exception 'That link can''t take pictures now.'; end if;
end; $$;
revoke execute on function public.set_share_pictures(text, int, text[]) from public, anon;
grant execute on function public.set_share_pictures(text, int, text[]) to authenticated;
