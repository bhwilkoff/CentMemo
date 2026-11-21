-- Purchases the person has not written a memo for yet: CentMemo's home.
-- security_invoker keeps row-level security in force.
create view public.unexamined_transactions with (security_invoker = on) as
  select t.* from public.transactions t
  where t.amount_minor < 0
    and t.status <> 'rejected'
    and not exists (select 1 from public.memos m where m.transaction_id = t.id);
revoke all on public.unexamined_transactions from anon;
grant select on public.unexamined_transactions to authenticated;
