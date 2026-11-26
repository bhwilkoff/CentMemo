-- W8 (Decision 069): a memo's photo is styled as part of the memo: Plate (its own shape),
-- Mounted (on a paper mat, as an archival print), or Strip (beside the photos next to it).
-- The caption column already holds the person's words under it.
alter table public.attachments add column if not exists style text not null default 'plate'
  check (style in ('plate', 'mounted', 'strip'));
