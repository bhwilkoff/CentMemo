-- FinanceKit Addendum 3.2, held by the database and not only by the connector's code
-- (Decision 068): the token an agent holds reads nothing from Wallet, however it asks.
-- These are restrictive and speak only to agents; the person's own token is unchanged.
create policy agents_never_read_wallet on public.accounts as restrictive for select to authenticated
  using ((select private.not_an_agent()) or source <> 'financekit');
create policy agents_never_read_wallet on public.transactions as restrictive for select to authenticated
  using ((select private.not_an_agent()) or source <> 'financekit');
-- What hangs off a purchase or an account goes with it.
create policy agents_never_read_wallet on public.balances as restrictive for select to authenticated
  using ((select private.not_an_agent()) or exists (select 1 from public.accounts a where a.id = balances.account_id and a.source <> 'financekit'));
create policy agents_never_read_wallet on public.memos as restrictive for select to authenticated
  using ((select private.not_an_agent()) or exists (select 1 from public.transactions t where t.id = memos.transaction_id and t.source <> 'financekit'));
create policy agents_never_read_wallet on public.memo_values as restrictive for select to authenticated
  using ((select private.not_an_agent()) or exists (select 1 from public.transactions t where t.id = memo_values.transaction_id and t.source <> 'financekit'));
-- A place's name is keyed by the bank's text: an agent sees it only when a purchase
-- it may see carries that text.
create policy agents_never_read_wallet on public.setting_names as restrictive for select to authenticated
  using ((select private.not_an_agent()) or exists (select 1 from public.transactions t where t.source <> 'financekit'
    and position(regexp_replace(lower(setting_names.setting), '[^a-z0-9]', '', 'g') in regexp_replace(lower(t.merchant || ' ' || t.description), '[^a-z0-9]', '', 'g')) > 0));
-- The connector never reads these, so no agent does.
create policy agents_cannot_read on public.attachments as restrictive for select to authenticated using ((select private.not_an_agent()));
create policy agents_cannot_read on public.import_batches as restrictive for select to authenticated using ((select private.not_an_agent()));
create policy agents_cannot_read on public.setting_places as restrictive for select to authenticated using ((select private.not_an_agent()));
create policy attachments_agents_cannot_read on storage.objects as restrictive for select to authenticated
  using (bucket_id <> 'attachments' or (select private.not_an_agent()));
