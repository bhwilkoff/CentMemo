-- D8 categories: Apple Wallet (FinanceKit) rows carry a merchant category code
-- but no category, so most of the Narrative showed none. plain_category names
-- each event in Apple Card's own category words (Restaurants, Grocery, Gas...),
-- the bank's category when it gave one, otherwise read from the code. A
-- generated column: one rule in the database, nothing rewritten, every client
-- reads the same value (shared-data-plane: publish the computed value).
alter table public.transactions add column plain_category text generated always as (
  coalesce(nullif(category, ''), case
    when mcc is null then null
    when mcc in (5812, 5813, 5814) then 'Restaurants'
    when mcc in (5411, 5422, 5441, 5451, 5462, 5499) then 'Grocery'
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
) stored;

-- The view lists t.*, so the new column is appended and the view is replaced in place.
create or replace view public.unexamined_transactions with (security_invoker = on) as
  select t.* from public.transactions t
  where t.amount_minor < 0
    and t.status <> 'rejected'
    and t.skipped_at is null
    and not exists (select 1 from public.memos m where m.transaction_id = t.id);
