-- N4: story links. A person makes one link at a time, on purpose. The published
-- words are read here from the person's own memos, so nothing else can be
-- published; the place and the time are what they typed. There is no amount, no
-- account, and no Wallet store or date (FinanceKit Addendum 3.2). Turning a link
-- off deletes its row. Deleting the memo, the theme, or the account deletes it too.
create table public.shares (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  code text not null unique check (code ~ '^[A-Za-z0-9_-]{22}$'),
  kind text not null check (kind in ('memo', 'theme')),
  memo_ids uuid[] not null check (cardinality(memo_ids) between 1 and 100),
  value_id uuid references public.life_values (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  payload jsonb not null check (octet_length(payload::text) <= 200000),
  created_at timestamptz not null default now()
);
create index shares_user on public.shares (user_id, created_at desc);
create index shares_value on public.shares (value_id);

alter table public.shares enable row level security;
revoke all on public.shares from anon, authenticated;
-- No insert and no update: make_share is the only way in, and a link never changes.
grant select, delete on public.shares to authenticated;
create policy owner_select on public.shares for select to authenticated using (user_id = (select auth.uid()));
create policy owner_delete on public.shares for delete to authenticated using (user_id = (select auth.uid()));
create policy agents_cannot_delete on public.shares as restrictive for delete to authenticated using ((select private.not_an_agent()));

create function private.one_of(v text, variadic allowed text[]) returns text
language sql immutable set search_path = '' as $$
  select case when v = any(allowed) then v else allowed[1] end;
$$;

create function public.make_share(p_kind text, p_items jsonb, p_design jsonb default '{}', p_value uuid default null, p_from text default null)
returns text
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := (select auth.uid());
  it jsonb; b text; n int; mark jsonb;
  ids uuid[] := '{}'; items jsonb := '[]';
  theme jsonb; v record; title text; secret text; words text[]; stop int;
  d jsonb := case when jsonb_typeof(p_design) = 'object' then p_design else '{}'::jsonb end;
  show_place boolean; show_when boolean; show_theme boolean; show_cover boolean; show_lines boolean; show_mems boolean;
begin
  show_place := coalesce(d ->> 'place', 'true') <> 'false'; show_when := coalesce(d ->> 'when', 'true') <> 'false'; show_theme := coalesce(d ->> 'theme', 'true') <> 'false';
  show_cover := coalesce(d ->> 'cover', 'true') <> 'false'; show_lines := coalesce(d ->> 'lines', 'true') <> 'false'; show_mems := coalesce(d ->> 'mems', 'true') <> 'false';
  if me is null then raise exception 'Sign in to make a link.'; end if;
  if not private.not_an_agent() then raise exception 'A link is made by the person, in CentMemo.'; end if;
  if p_kind not in ('memo', 'theme') then raise exception 'Unknown kind of link.'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 100 then raise exception 'Choose at least one memo.'; end if;
  if p_kind = 'memo' and jsonb_array_length(p_items) <> 1 then raise exception 'A memo link holds one memo.'; end if;
  if p_kind = 'theme' and not (show_cover or show_lines or show_mems) then raise exception 'Choose at least one part of the page.'; end if;
  if p_kind = 'theme' and p_value is null then raise exception 'A theme link needs its theme.'; end if;
  if (select count(*) from public.shares where user_id = me) >= 200 then raise exception 'Turn off a link before making another.'; end if;

  if p_value is not null then
    select l.name, coalesce(l.color, 'stone') as color into v from public.life_values l where l.id = p_value and l.user_id = me;
    if not found then raise exception 'That theme isn''t yours.'; end if;
    theme := jsonb_build_object('name', v.name, 'color', case when v.color ~ '^[a-z]{3,12}$' then v.color else 'stone' end);
  end if;

  for it in select * from jsonb_array_elements(p_items) loop
    select m.body into b from public.memos m where m.transaction_id = (it ->> 'txn')::uuid and m.user_id = me;
    if not found then raise exception 'That memo isn''t yours.'; end if;
    if p_value is not null and not exists (select 1 from public.memo_values mv where mv.transaction_id = (it ->> 'txn')::uuid and mv.value_id = p_value and mv.user_id = me) then
      raise exception 'That memo doesn''t have this theme.';
    end if;
    words := regexp_split_to_array(btrim(b), '\s+');
    n := coalesce(array_length(words, 1), 0);
    mark := null;
    if jsonb_typeof(it -> 'mark') = 'array' and jsonb_array_length(it -> 'mark') = 2 and (it -> 'mark' ->> 0) ~ '^\d{1,4}$' and (it -> 'mark' ->> 1) ~ '^\d{1,4}$' then
      mark := jsonb_build_array(least((it -> 'mark' ->> 0)::int, (it -> 'mark' ->> 1)::int, n - 1), least(greatest((it -> 'mark' ->> 0)::int, (it -> 'mark' ->> 1)::int), n - 1));
    end if;
    ids := ids || (it ->> 'txn')::uuid;
    title := coalesce(title, left(regexp_replace(btrim(b), '\s+', ' ', 'g'), 80));
    -- What the page hides is not published: a lines-only page carries only the lines.
    if p_kind = 'theme' and not show_mems then
      if show_lines then
        if mark is null then
          select min(i) into stop from generate_subscripts(words, 1) i where words[i] ~ '[.!?]$';
          b := array_to_string(words[1:coalesce(stop, n)], ' ');
        else
          b := array_to_string(words[(mark ->> 0)::int + 1 : (mark ->> 1)::int + 1], ' ');
        end if;
      else b := null; end if;
      mark := null;
    end if;
    items := items || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object('memo', b,
      'place', case when show_place and (p_kind = 'memo' or show_cover or show_mems) then nullif(left(btrim(coalesce(it ->> 'place', '')), 80), '') end,
      'when', case when show_when and (p_kind = 'memo' or show_mems) then nullif(left(btrim(coalesce(it ->> 'when', '')), 60), '') end, 'mark', mark)));
  end loop;

  secret := translate(rtrim(encode(extensions.gen_random_bytes(16), 'base64'), '='), '+/', '-_');
  if p_kind = 'theme' then title := v.name; end if;
  insert into public.shares (user_id, code, kind, memo_ids, value_id, title, payload) values (me, secret, p_kind, ids, p_value, title,
    jsonb_strip_nulls(jsonb_build_object('kind', p_kind, 'theme', case when p_kind = 'theme' or show_theme then theme end, 'from', nullif(left(btrim(coalesce(p_from, '')), 60), ''), 'items', items,
      'design', jsonb_build_object('color', coalesce(theme ->> 'color', 'clay'),
        'lead', private.one_of(d ->> 'lead', 'memory', 'setting', 'theme'),
        'paper', private.one_of(d ->> 'paper', 'bold', 'paper', 'night'),
        'pencil', private.one_of(d ->> 'pencil', 'underline', 'double', 'circle', 'highlight'),
        'cover', show_cover, 'lines', show_lines, 'mems', show_mems))));
  return secret;
end;
$$;
revoke execute on function public.make_share(text, jsonb, jsonb, uuid, text) from public, anon;
grant execute on function public.make_share(text, jsonb, jsonb, uuid, text) to authenticated;

-- The one public read: exactly one link, by a code nobody can guess. It returns the
-- published page and nothing about who made it.
create function public.get_share(p_code text) returns jsonb
language sql stable security definer set search_path = '' as $$
  select s.payload from public.shares s where s.code = p_code;
$$;
revoke execute on function public.get_share(text) from public;
grant execute on function public.get_share(text) to anon, authenticated;

create function private.memo_gone() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.shares where user_id = old.user_id and memo_ids @> array[old.transaction_id];
  return old;
end; $$;
create trigger memos_take_their_links after delete on public.memos for each row execute function private.memo_gone();
