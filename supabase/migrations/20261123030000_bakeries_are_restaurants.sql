-- Bakeries (MCC 5462: Crumbl) read as Restaurants and a meal, not Grocery
-- (seen on Ben's Duo, 2026-11-23). Postgres 17 changes a generated column's
-- expression in place.
alter table public.transactions alter column plain_category set expression as (
  coalesce(nullif(category, ''), case
    when mcc is null then null
    when mcc in (5812, 5813, 5814, 5462) then 'Restaurants'
    when mcc in (5411, 5422, 5441, 5451, 5499) then 'Grocery'
    when mcc in (5541, 5542, 5983) then 'Gas'
    when mcc between 3000 and 3299 or mcc = 4511 then 'Airlines'
    when mcc between 3500 and 3999 or mcc in (7011, 7012) then 'Hotels'
    when mcc between 3300 and 3499 or mcc in (4111, 4112, 4121, 4131, 4411, 4457, 4468, 4722, 4784, 4789,
         5511, 5521, 5531, 5532, 5533, 5571, 7511, 7512, 7513, 7519, 7523, 7531, 7534, 7535, 7538, 7542, 7549) then 'Transportation'
    when mcc in (4812, 4814, 4816, 4821, 4899, 4900) then 'Utilities'
    when mcc in (5960, 6300, 6381, 6399) then 'Insurance'
    when mcc in (5912, 5975, 5976, 8011, 8021, 8031, 8041, 8042, 8043, 8049, 8050, 8062, 8071, 8099) then 'Medical'
    when mcc in (5815, 5816, 5817, 5818, 7829, 7832, 7841, 7911, 7922, 7929, 7932, 7933, 7941, 7991, 7992, 7993, 7994, 7996, 7997, 7998, 7999) then 'Entertainment'
    when mcc between 5000 and 5999 then 'Shopping'
    when mcc between 7000 and 8999 or mcc between 1500 and 2999 then 'Services'
    else 'Other'
  end)
);

create or replace function public.memo_suggestions()
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
        when b.mcc in (5812, 5813, 5814, 5462) or b.category = 'Restaurants' then 'meal'
        when b.mcc in (5411, 5422, 5441, 5451, 5499) or b.category = 'Grocery' then 'groceries'
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
