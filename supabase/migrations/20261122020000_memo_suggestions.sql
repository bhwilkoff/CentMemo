-- D7: what to write about. At most one event per rule, chosen by data rules the
-- person can read (never a model): first time at a place, the biggest purchase
-- this month, the busiest day, and a memo from a year ago. One algorithm here;
-- every client shows the result (shared-data-plane: publish the computed value).
-- "Today" is the person's latest event date, so an imported history works too.
-- Details never count: deposits, interest, payments, transfers, refunds, skipped.
create or replace function public.memo_suggestions()
returns table (kind text, transaction_id uuid, memo_body text)
language sql stable security invoker set search_path = public as $$
  with base as (
    select t.*, lower(coalesce(nullif(t.merchant, ''), t.description)) as place
    from public.transactions t
    where t.user_id = (select auth.uid())
  ),
  anchor as (select max(txn_date) as d from base),
  open_events as (
    select b.* from base b, anchor
    where b.amount_minor < 0 and b.status <> 'rejected' and b.skipped_at is null
      and coalesce(b.txn_type, '') not in ('deposit', 'interest', 'billPayment', 'transfer', 'refund', 'Standard Transfer')
      and not exists (select 1 from public.memos m where m.transaction_id = b.id)
      and b.txn_date >= anchor.d - 60
  ),
  first_visit as (
    select 'first_visit'::text as kind, o.id, null::text as memo_body from open_events o
    where not exists (select 1 from base b2 where b2.place = o.place and b2.txn_date < o.txn_date)
    order by o.txn_date desc, o.amount_minor asc limit 1
  ),
  biggest as (
    select 'biggest_month'::text, o.id, null::text from open_events o, anchor
    where date_trunc('month', o.txn_date) = date_trunc('month', anchor.d)
    order by o.amount_minor asc limit 1
  ),
  busy as (
    select 'busy_day'::text, o.id, null::text from open_events o
    where o.txn_date = (select txn_date from open_events group by txn_date having count(*) >= 3
                        order by count(*) desc, txn_date desc limit 1)
    order by o.amount_minor asc limit 1
  ),
  year_ago as (
    select 'year_ago'::text, b.id, m.body from base b join public.memos m on m.transaction_id = b.id, anchor
    where b.txn_date between anchor.d - 372 and anchor.d - 358
    order by abs((anchor.d - 365) - b.txn_date) limit 1
  )
  select * from first_visit union all select * from biggest union all select * from busy union all select * from year_ago;
$$;
revoke all on function public.memo_suggestions() from public, anon;
grant execute on function public.memo_suggestions() to authenticated;
