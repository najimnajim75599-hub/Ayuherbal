-- Owner-scoped distributor profile updates that do not grant clients direct table writes.
-- Apply after supabase-distributor-identity-card.sql.

create or replace function public.update_my_distributor_profile(profile_data jsonb, submit_application boolean default false)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  distributor_id uuid := auth.uid();
  updated_distributor public.ayu_distributors%rowtype;
begin
  if distributor_id is null then raise exception 'Sign in required'; end if;
  if profile_data is null or jsonb_typeof(profile_data) <> 'object' then
    raise exception 'Profile details are required';
  end if;

  update public.ayu_distributors d
  set business_name = case when profile_data ? 'business_name' then nullif(btrim(profile_data->>'business_name'), '') else d.business_name end,
      business_type = case when profile_data ? 'business_type' then nullif(btrim(profile_data->>'business_type'), '') else d.business_type end,
      contact_person = case when profile_data ? 'contact_person' then nullif(btrim(profile_data->>'contact_person'), '') else d.contact_person end,
      phone = case when profile_data ? 'phone' then nullif(btrim(profile_data->>'phone'), '') else d.phone end,
      whatsapp = case when profile_data ? 'whatsapp' then nullif(btrim(profile_data->>'whatsapp'), '') else d.whatsapp end,
      email = case when profile_data ? 'email' then nullif(btrim(profile_data->>'email'), '') else d.email end,
      address = case when profile_data ? 'address' then nullif(btrim(profile_data->>'address'), '') else d.address end,
      city = case when profile_data ? 'city' then nullif(btrim(profile_data->>'city'), '') else d.city end,
      state = case when profile_data ? 'state' then nullif(btrim(profile_data->>'state'), '') else d.state end,
      pincode = case when profile_data ? 'pincode' then nullif(btrim(profile_data->>'pincode'), '') else d.pincode end,
      doc_id_proof = case when profile_data ? 'doc_id_proof' then nullif(btrim(profile_data->>'doc_id_proof'), '') else d.doc_id_proof end,
      declaration_accepted = case when profile_data ? 'declaration_accepted' then (profile_data->>'declaration_accepted')::boolean else d.declaration_accepted end
  where d.user_id = distributor_id
  returning d.* into updated_distributor;

  if not found then raise exception 'Distributor account not found'; end if;

  if submit_application then
    if nullif(btrim(updated_distributor.business_name), '') is null
      or nullif(btrim(updated_distributor.contact_person), '') is null
      or nullif(btrim(updated_distributor.phone), '') is null
      or nullif(btrim(updated_distributor.address), '') is null
      or nullif(btrim(updated_distributor.city), '') is null
      or nullif(btrim(updated_distributor.state), '') is null
      or nullif(btrim(updated_distributor.pincode), '') is null
      or nullif(btrim(updated_distributor.doc_id_proof), '') is null
      or not coalesce(updated_distributor.declaration_accepted, false) then
      raise exception 'Complete all required application fields and upload ID proof before submitting';
    end if;

    update public.ayu_distributors
    set status = 'submitted', submitted_at = now()
    where user_id = distributor_id;
  end if;

  return distributor_id;
end;
$$;

create or replace function public.update_my_distributor_bank_details(bank_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  distributor_id uuid := auth.uid();
begin
  if distributor_id is null then raise exception 'Sign in required'; end if;
  if bank_data is null or jsonb_typeof(bank_data) <> 'object' then
    raise exception 'Bank details are required';
  end if;

  update public.ayu_distributors d
  set bank_holder = case when bank_data ? 'bank_holder' then nullif(btrim(bank_data->>'bank_holder'), '') else d.bank_holder end,
      bank_name = case when bank_data ? 'bank_name' then nullif(btrim(bank_data->>'bank_name'), '') else d.bank_name end,
      bank_account = case when bank_data ? 'bank_account' then nullif(btrim(bank_data->>'bank_account'), '') else d.bank_account end,
      bank_ifsc = case when bank_data ? 'bank_ifsc' then nullif(btrim(bank_data->>'bank_ifsc'), '') else d.bank_ifsc end
  where d.user_id = distributor_id;

  if not found then raise exception 'Distributor account not found'; end if;
  return distributor_id;
end;
$$;

create or replace function public.update_my_distributor_photo(photo_path text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  distributor_id uuid := auth.uid();
  expected_prefix text;
begin
  if distributor_id is null then raise exception 'Sign in required'; end if;
  expected_prefix := distributor_id::text || '/profile-photo-';
  if photo_path is null or left(photo_path, length(expected_prefix)) <> expected_prefix then
    raise exception 'Invalid profile photo path';
  end if;

  update public.ayu_distributors
  set profile_photo_path = photo_path
  where user_id = distributor_id;

  if not found then raise exception 'Distributor account not found'; end if;
  return distributor_id;
end;
$$;

revoke all on function public.update_my_distributor_profile(jsonb, boolean) from public, anon;
revoke all on function public.update_my_distributor_bank_details(jsonb) from public, anon;
revoke all on function public.update_my_distributor_photo(text) from public, anon;
grant execute on function public.update_my_distributor_profile(jsonb, boolean) to authenticated;
grant execute on function public.update_my_distributor_bank_details(jsonb) to authenticated;
grant execute on function public.update_my_distributor_photo(text) to authenticated;

notify pgrst, 'reload schema';