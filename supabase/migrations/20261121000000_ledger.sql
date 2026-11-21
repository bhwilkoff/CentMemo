-- CentMemo's ledger: accounts, balances, transactions, the person's memos,
-- the values they name, and attachments. Every row belongs to one person
-- and only that person can see it (Decision 055). Money is signed integer
-- minor units: negative left the account (Decision 057). Child rows carry
-- user_id in a composite foreign key so nobody can hang a row on another
-- person's account.

create schema if not exists private;

-- A token from Claude (or any agent) signing in through the OAuth server
-- carries a client_id claim; a token from signing in on centmemo.com does
-- not. Agents read; only the person writes (Decision 056).
create function private.not_an_agent() returns boolean
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt() ->> 'client_id', '') = '';
$$;
grant usage on schema private to authenticated;
grant execute on function private.not_an_agent() to authenticated;

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  source text not null check (source in ('financekit', 'csv')),
  source_id text not null check (char_length(source_id) between 1 and 200),
  kind text not null check (kind in ('asset', 'liability')),
  display_name text not null check (char_length(display_name) between 1 and 120),
  institution text not null default '' check (char_length(institution) <= 120),
  currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
  credit_limit_minor bigint,
  created_at timestamptz not null default now(),
  unique (user_id, source, source_id),
  unique (id, user_id)
);

create table public.balances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  account_id uuid not null,
  as_of timestamptz not null,
  available_minor bigint,
  booked_minor bigint,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  unique (account_id, as_of),
  foreign key (account_id, user_id) references public.accounts (id, user_id) on delete cascade
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  source text not null check (source in ('financekit', 'csv')),
  filename text not null default '' check (char_length(filename) <= 255),
  row_count int not null default 0,
  inserted_count int not null default 0,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  account_id uuid not null,
  source text not null check (source in ('financekit', 'csv')),
  source_id text not null check (char_length(source_id) between 1 and 200),
  import_batch_id uuid references public.import_batches (id) on delete set null,
  txn_date date not null,
  posted_date date,
  amount_minor bigint not null,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  description text not null default '' check (char_length(description) <= 500),
  merchant text not null default '' check (char_length(merchant) <= 200),
  category text not null default '' check (char_length(category) <= 80),
  mcc int check (mcc between 0 and 9999),
  txn_type text not null default '' check (char_length(txn_type) <= 40),
  status text not null default 'booked' check (status in ('authorized', 'pending', 'booked', 'memo', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, source, source_id),
  unique (id, user_id),
  foreign key (account_id, user_id) references public.accounts (id, user_id) on delete cascade
);
create index transactions_by_date on public.transactions (user_id, txn_date desc);

-- The story: one memo per transaction, in the person's own words.
create table public.memos (
  transaction_id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  body text not null check (char_length(body) between 1 and 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (transaction_id, user_id),
  foreign key (transaction_id, user_id) references public.transactions (id, user_id) on delete cascade
);

-- What a person says they invest in ("time with my kids", "great meals").
-- Named by them; never suggested by a model.
create table public.life_values (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);
create unique index life_values_name on public.life_values (user_id, lower(btrim(name)));

create table public.memo_values (
  transaction_id uuid not null,
  value_id uuid not null,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  primary key (transaction_id, value_id),
  foreign key (transaction_id, user_id) references public.memos (transaction_id, user_id) on delete cascade,
  foreign key (value_id, user_id) references public.life_values (id, user_id) on delete cascade
);

-- Photos and files that help tell a purchase's story. device_ref points at
-- the original on the person's device (a PhotoKit local identifier);
-- storage_path is set only when they choose to upload a copy.
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  transaction_id uuid not null,
  kind text not null check (kind in ('photo', 'file')),
  device_ref text check (char_length(device_ref) <= 300),
  storage_path text check (char_length(storage_path) <= 300),
  caption text not null default '' check (char_length(caption) <= 500),
  created_at timestamptz not null default now(),
  foreign key (transaction_id, user_id) references public.transactions (id, user_id) on delete cascade
);

-- Row-level security: owner only, every operation; agents never write.
do $$
declare t text;
begin
  foreach t in array array['accounts', 'balances', 'import_batches', 'transactions',
                           'memos', 'life_values', 'memo_values', 'attachments'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy owner_select on public.%I for select to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy owner_insert on public.%I for insert to authenticated with check (user_id = (select auth.uid()))', t);
    execute format('create policy owner_update on public.%I for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()))', t);
    execute format('create policy owner_delete on public.%I for delete to authenticated using (user_id = (select auth.uid()))', t);
    execute format('create policy agents_cannot_insert on public.%I as restrictive for insert to authenticated with check ((select private.not_an_agent()))', t);
    execute format('create policy agents_cannot_update on public.%I as restrictive for update to authenticated using ((select private.not_an_agent()))', t);
    execute format('create policy agents_cannot_delete on public.%I as restrictive for delete to authenticated using ((select private.not_an_agent()))', t);
  end loop;
end $$;

create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
create trigger transactions_touch before update on public.transactions
  for each row execute function private.touch_updated_at();
create trigger memos_touch before update on public.memos
  for each row execute function private.touch_updated_at();

-- Spending grouped by month, category, or value, computed as the caller
-- (security invoker), so row-level security still applies.
create function public.spending_summary(from_date date, to_date date, group_by text)
returns table (label text, spent_minor bigint, received_minor bigint, count bigint)
language sql stable security invoker set search_path = '' as $$
  select
    case group_by
      when 'month' then to_char(t.txn_date, 'YYYY-MM')
      when 'category' then coalesce(nullif(t.category, ''), 'Uncategorized')
      when 'value' then coalesce(v.name, 'No value named')
    end as label,
    coalesce(sum(-t.amount_minor) filter (where t.amount_minor < 0), 0)::bigint,
    coalesce(sum(t.amount_minor) filter (where t.amount_minor > 0), 0)::bigint,
    count(*)
  from public.transactions t
  left join public.memo_values mv on group_by = 'value' and mv.transaction_id = t.id
  left join public.life_values v on v.id = mv.value_id
  where t.txn_date between from_date and to_date
    and t.status <> 'rejected'
    and group_by in ('month', 'category', 'value')
  group by 1
  order by 2 desc;
$$;
grant execute on function public.spending_summary(date, date, text) to authenticated;

-- In-app account deletion (Decision 035). Cascades remove every row.
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.not_an_agent() then
    raise exception 'Deleting an account is done by the person, in CentMemo.';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
