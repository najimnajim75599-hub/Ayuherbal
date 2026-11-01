-- Permanently remove a distributor and their account data.
-- Apply after supabase-binary-network.sql and supabase-distributor-accounts.sql.

create or replace function public.admin_remove_ayu_distributor(target_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.ayu_profiles
    where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Administrator access required';
  end if;

  if target_id is null or target_id = auth.uid() then
    raise exception 'Invalid distributor account';
  end if;

  if not exists (
    select 1 from public.ayu_distributors where user_id = target_id
  ) then
    raise exception 'Distributor not found';
  end if;

  if exists (
    select 1 from public.ayu_profiles where id = target_id and role = 'admin'
  ) then
    raise exception 'Administrator accounts cannot be removed as distributors';
  end if;

  if not exists (select 1 from auth.users where id = target_id) then
    raise exception 'Distributor sign-in account not found';
  end if;

  update public.ayu_distributors
  set parent_id = null, position = null
  where parent_id = target_id;

  update public.ayu_distributors
  set sponsor_id = null
  where sponsor_id = target_id;

  delete from public.ayu_distributor_adjustment_requests
  where distributor_id = target_id;

  delete from public.ayu_distributor_inventory
  where distributor_id = target_id;

  delete from public.ayu_distributor_commissions
  where distributor_id = target_id;

  delete from public.ayu_distributor_payments
  where distributor_id = target_id;

  update public.ayu_distributor_ledger
  set related_transaction_id = null
  where related_transaction_id in (
    select id from public.ayu_distributor_ledger where distributor_id = target_id
  );

  delete from public.ayu_distributor_ledger
  where distributor_id = target_id;

  delete from public.ayu_distributors
  where user_id = target_id;

  delete from public.ayu_profiles
  where id = target_id;

  delete from auth.users
  where id = target_id;
end;
$$;

revoke all on function public.admin_remove_ayu_distributor(uuid) from public, anon;
grant execute on function public.admin_remove_ayu_distributor(uuid) to authenticated;

notify pgrst, 'reload schema';