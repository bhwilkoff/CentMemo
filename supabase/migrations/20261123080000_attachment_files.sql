-- Item 10: files (a receipt, a ticket) join photo copies in the private
-- bucket. A file's reference only works on the device that chose it, so a
-- file the person adds is kept as a copy; images are re-encoded as JPEG on the
-- phone first (no location metadata), PDFs are kept as they are.
update storage.buckets set allowed_mime_types = array['image/jpeg','application/pdf'] where id = 'attachments';
