-- D7, after Ben (2026-11-23): "the questions are often incredibly irrelevant
-- (State Farm Insurance - 'What was the day about?')".
-- Two readable rules added to memo_suggestions():
--   1. A bill is never a suggestion: insurance, utilities, phone and cable,
--      digital subscriptions (by merchant category code), or the same charge
--      at the same place in two earlier months.
--   2. No two picks at the same place.
--   3. Each pick names its moment (a meal, a trip, a show...), from the merchant
--      category code or the Apple Card category, so the client can ask a question
--      that fits the purchase. The words stay on the clients (human-written).
-- The return type gains a column, so the function is dropped and recreated.
drop function if exists public.memo_suggestions();

create function public.memo_suggestions()
returns table (kind text, transaction_id uuid, memo_body text, moment text)
language sql stable security invoker set search_path = public as $$
  with base as (
    select t.*, lower(coalesce(nullif(t.merchant, ''), t.description)) as place
    from public.transactions t
    where t.user_id = (select auth.uid())
  ),
  anchor as (select max(txn_date) as d from base),
  candidates as (
    select b.*,
      case
        when b.mcc in (5812, 5813, 5814) or b.category = 'Restaurants' then 'meal'
        when b.mcc in (5411, 5422, 5441, 5451, 5462, 5499) or b.category = 'Grocery' then 'groceries'
        when b.mcc between 3000 and 3999 or b.mcc in (4511, 4722, 7011, 4411) or b.category in ('Airlines', 'Hotels') then 'trip'
        when b.mcc in (4111, 4121, 4131, 4789, 7523) or b.category = 'Transportation' then 'ride'
        when b.mcc in (5541, 5542, 5983) or b.category = 'Gas' then 'fuel'
        when b.mcc in (5511, 5521, 5531, 5532, 5533, 7531, 7534, 7535, 7538, 7542, 7549) then 'car'
        when b.mcc in (7832, 7922, 7929, 7932, 7933, 7941, 7991, 7996, 7998, 7999) or b.category = 'Entertainment' then 'outing'
        when b.mcc in (5735, 5942, 5945, 5970, 5971, 5733, 5946) then 'find'
        when b.mcc in (5912, 8011, 8021, 8031, 8041, 8042, 8043, 8049, 8050, 8062, 8071, 8099) or b.category = 'Medical' then 'care'
        when b.mcc in (8398, 8661) then 'giving'
        when b.mcc in (5992, 5193, 5947) then 'gift'
        when b.mcc is not null or b.category = 'Shopping' then 'shop'
        else null
      end as moment
    from base b, anchor
    where b.amount_minor < 0 and b.status <> 'rejected' and b.skipped_at is null
      and coalesce(b.txn_type, '') not in ('deposit', 'interest', 'billPayment', 'transfer', 'refund', 'Standard Transfer')
      and not exists (select 1 from public.memos m where m.transaction_id = b.id)
      and b.txn_date >= anchor.d - 60
      -- Bills: insurance and finance, utilities, phone and cable, subscriptions.
      and coalesce(b.mcc, 0) not in (4814, 4816, 4899, 4900, 5815, 5816, 5817, 5818, 5960, 6012, 6051, 6211, 6300, 6381, 6399, 9311, 9399)
      and coalesce(b.category, '') not in ('Insurance', 'Utilities', 'Payment', 'Installment', 'Interest')
      -- The same charge at the same place in two earlier months is a bill too.
      and (select count(distinct date_trunc('month', p.txn_date)) from base p
           where p.place = b.place and p.amount_minor = b.amount_minor
             and date_trunc('month', p.txn_date) < date_trunc('month', b.txn_date)) < 2
  ),
  first_visit as (
    select 'first_visit'::text as kind, o.id, null::text as memo_body, o.moment from candidates o
    where not exists (select 1 from base b2 where b2.place = o.place and b2.txn_date < o.txn_date)
    order by o.txn_date desc, o.amount_minor asc limit 1
  ),
  biggest as (
    select 'biggest_month'::text, o.id, null::text, o.moment from candidates o, anchor
    where date_trunc('month', o.txn_date) = date_trunc('month', anchor.d)
      and o.place not in (select c.place from candidates c where c.id in (select id from first_visit))
    order by o.amount_minor asc limit 1
  ),
  busy as (
    select 'busy_day'::text, o.id, null::text, o.moment from candidates o
    where o.txn_date = (select txn_date from candidates group by txn_date having count(*) >= 3
                        order by count(*) desc, txn_date desc limit 1)
      and o.place not in (select c.place from candidates c where c.id in (select id from first_visit union all select id from biggest))
    order by o.amount_minor asc limit 1
  ),
  year_ago as (
    select 'year_ago'::text, b.id, m.body, null::text from base b join public.memos m on m.transaction_id = b.id, anchor
    where b.txn_date between anchor.d - 372 and anchor.d - 358
    order by abs((anchor.d - 365) - b.txn_date) limit 1
  )
  select * from first_visit union all select * from biggest union all select * from busy union all select * from year_ago;
$$;
revoke all on function public.memo_suggestions() from public, anon;
grant execute on function public.memo_suggestions() to authenticated;
