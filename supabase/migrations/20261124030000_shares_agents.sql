-- A link's page can hold a memo on a Wallet purchase, which an agent must never see
-- (Addendum 3.2). The list of links is the person's alone.
create policy agents_cannot_read on public.shares as restrictive for select to authenticated using ((select private.not_an_agent()));
