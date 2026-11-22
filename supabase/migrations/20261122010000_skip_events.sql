-- Skip (Decision 065, D13): a person swipes an event out of the Narrative as a
-- detail that stays out of the Story. Never a delete: null brings it back.
-- Imports and the Wallet sync upsert only the columns they send, so a skip
-- survives every re-sync.
alter table public.transactions add column skipped_at timestamptz;

-- Unexamined leaves skipped events out. (t.* now ends with skipped_at, so the
-- view can be replaced in place.)
create or replace view public.unexamined_transactions with (security_invoker = on) as
  select t.* from public.transactions t
  where t.amount_minor < 0
    and t.status <> 'rejected'
    and t.skipped_at is null
    and not exists (select 1 from public.memos m where m.transaction_id = t.id);
