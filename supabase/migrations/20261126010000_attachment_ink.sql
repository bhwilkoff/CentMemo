-- W5 (Decision 069): ink drawn with Apple Pencil (or a finger) is a memo part. Kept
-- in the person's private folder as the PencilKit drawing (to draw on again) and a
-- PNG of it on paper (for the Mac, the web and shares). Same owner-only policies;
-- the connector never reads attachments.
alter table public.attachments drop constraint if exists attachments_kind_check;
alter table public.attachments add constraint attachments_kind_check check (kind in ('photo', 'file', 'ink'));
update storage.buckets
   set allowed_mime_types = array['image/jpeg', 'application/pdf', 'image/png', 'application/octet-stream']
 where id = 'attachments';
