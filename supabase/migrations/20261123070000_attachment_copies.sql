-- Item 10: a copy of a photo the person chooses to keep in CentMemo (so the
-- web can show it). Private bucket; each person's files live under their own
-- user id and only they can read, add, or remove them; agents (the Claude
-- connector) never write. 5 MB per file, images only; the iPhone strips
-- location metadata and resizes before upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attachments', 'attachments', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

create policy attachments_owner_select on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy attachments_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy attachments_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy attachments_agents_cannot_insert on storage.objects as restrictive for insert to authenticated
  with check (bucket_id <> 'attachments' or (select private.not_an_agent()));
create policy attachments_agents_cannot_delete on storage.objects as restrictive for delete to authenticated
  using (bucket_id <> 'attachments' or (select private.not_an_agent()));
