-- Distributor identity-card photo storage.
-- Apply after supabase-distributor-accounts.sql.

alter table public.ayu_distributors
  add column if not exists profile_photo_path text;

drop policy if exists ayu_docs_identity_read on storage.objects;
create policy ayu_docs_identity_read on storage.objects
  for select to authenticated using (
    bucket_id = 'ayu-docs'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.ayu_profiles p
        where p.id = (select auth.uid()) and p.role = 'admin'
      )
    )
  );

notify pgrst, 'reload schema';