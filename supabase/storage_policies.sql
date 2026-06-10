-- Production WashDesk cloud backup Storage policies.
--
-- Backups are private and scoped to the authenticated Supabase user:
--
--   manager/{auth.uid()}/carwash_manager.db
--   manager/{auth.uid()}/metadata.json
--
-- Run this in Supabase Dashboard > SQL Editor, or create equivalent policies in
-- Storage > Policies. Do not use anon read/write policies for production.

drop policy if exists "WashDesk backup read" on storage.objects;
drop policy if exists "WashDesk backup insert" on storage.objects;
drop policy if exists "WashDesk backup update" on storage.objects;
drop policy if exists "WashDesk backup delete" on storage.objects;

create policy "WashDesk backup read"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'washdesk-backups'
  and (storage.foldername(name))[1] = 'manager'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "WashDesk backup insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'washdesk-backups'
  and (storage.foldername(name))[1] = 'manager'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "WashDesk backup update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'washdesk-backups'
  and (storage.foldername(name))[1] = 'manager'
  and (storage.foldername(name))[2] = auth.uid()::text
)
with check (
  bucket_id = 'washdesk-backups'
  and (storage.foldername(name))[1] = 'manager'
  and (storage.foldername(name))[2] = auth.uid()::text
);

create policy "WashDesk backup delete"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'washdesk-backups'
  and (storage.foldername(name))[1] = 'manager'
  and (storage.foldername(name))[2] = auth.uid()::text
);
