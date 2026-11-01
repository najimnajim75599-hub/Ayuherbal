-- Distributor account, inventory, and ledger foundation.
-- Apply after the existing AYU LIFE HEARBAL schema and binary-network migration.

alter table public.ayu_products
  add column if not exists account_sale_price numeric(12,2) not null default 0,
  add column if not exists distributor_commission_rate numeric(5,2) not null default 0;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'ayu_products_account_sale_price_check') then
    alter table public.ayu_products add constraint ayu_products_account_sale_price_check check (account_sale_price >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'ayu_products_distributor_commission_rate_check') then
    alter table public.ayu_products add constraint ayu_products_distributor_commission_rate_check check (distributor_commission_rate between 0 and 100);
  end if;
end;
$$;

create table if not exists public.ayu_distributor_inventory (
  distributor_id uuid not null references public.ayu_distributors(user_id) on delete cascade,
  product_id uuid not null references public.ayu_products(id) on delete restrict,
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (distributor_id, product_id)
);

create table if not exists public.ayu_distributor_ledger (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null default gen_random_uuid() unique,
  distributor_id uuid not null references public.ayu_distributors(user_id) on delete restrict,
  product_id uuid references public.ayu_products(id) on delete restrict,
  transaction_type text not null check (transaction_type in (
    'PRODUCT_RECEIVED', 'PRODUCT_SOLD', 'PRODUCT_RETURNED', 'STOCK_ADJUSTMENT',
    'COMMISSION_EARNED', 'PAYMENT_RECEIVED', 'PAYMENT_PENDING', 'REFUND',
    'COMMISSION_REVERSAL'
  )),
  quantity integer not null default 0,
  selling_price numeric(12,2),
  total_amount numeric(12,2) not null default 0,
  commission_amount numeric(12,2) not null default 0,
  payment_status text not null default 'NOT_APPLICABLE'
    check (payment_status in ('NOT_APPLICABLE', 'PENDING', 'PAID')),
  payment_method text,
  customer_name text,
  customer_phone text,
  product_name text,
  description text,
  related_transaction_id uuid references public.ayu_distributor_ledger(id) on delete restrict,
  record_status text not null default 'VERIFIED'
    check (record_status in ('VERIFIED', 'CANCELLED')),
  request_id uuid unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  sale_date date
);

create table if not exists public.ayu_distributor_commissions (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references public.ayu_distributors(user_id) on delete restrict,
  ledger_id uuid not null unique references public.ayu_distributor_ledger(id) on delete restrict,
  commission_amount numeric(12,2) not null check (commission_amount >= 0),
  commission_type text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.ayu_distributor_payments (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references public.ayu_distributors(user_id) on delete restrict,
  ledger_id uuid not null unique references public.ayu_distributor_ledger(id) on delete restrict,
  payment_amount numeric(12,2) not null check (payment_amount > 0),
  method text not null,
  reference text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.ayu_distributor_adjustment_requests (
  id uuid primary key default gen_random_uuid(),
  distributor_id uuid not null references public.ayu_distributors(user_id) on delete cascade,
  product_id uuid not null references public.ayu_products(id) on delete restrict,
  quantity_delta integer not null check (quantity_delta <> 0),
  description text not null,
  status text not null default 'PENDING' check (status in ('PENDING', 'APPROVED', 'REJECTED')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.ayu_distributor_ledger
  add column if not exists product_name text,
  add column if not exists related_transaction_id uuid references public.ayu_distributor_ledger(id) on delete restrict;

create index if not exists ayu_distributor_ledger_owner_date_idx
  on public.ayu_distributor_ledger(distributor_id, created_at desc);
create index if not exists ayu_distributor_ledger_product_idx
  on public.ayu_distributor_ledger(product_id, created_at desc);
create index if not exists ayu_distributor_ledger_type_idx
  on public.ayu_distributor_ledger(distributor_id, transaction_type, created_at desc);
create index if not exists ayu_distributor_adjustment_status_idx
  on public.ayu_distributor_adjustment_requests(status, created_at);

alter table public.ayu_distributor_inventory enable row level security;
alter table public.ayu_distributor_ledger enable row level security;
alter table public.ayu_distributor_commissions enable row level security;
alter table public.ayu_distributor_payments enable row level security;
alter table public.ayu_distributor_adjustment_requests enable row level security;

drop policy if exists ayu_distributor_inventory_read on public.ayu_distributor_inventory;
create policy ayu_distributor_inventory_read on public.ayu_distributor_inventory
  for select to authenticated using (
    distributor_id = (select auth.uid()) or exists (
      select 1 from public.ayu_profiles p where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists ayu_distributor_ledger_read on public.ayu_distributor_ledger;
create policy ayu_distributor_ledger_read on public.ayu_distributor_ledger
  for select to authenticated using (
    distributor_id = (select auth.uid()) or exists (
      select 1 from public.ayu_profiles p where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists ayu_distributor_commissions_read on public.ayu_distributor_commissions;
create policy ayu_distributor_commissions_read on public.ayu_distributor_commissions
  for select to authenticated using (
    distributor_id = (select auth.uid()) or exists (
      select 1 from public.ayu_profiles p where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists ayu_distributor_payments_read on public.ayu_distributor_payments;
create policy ayu_distributor_payments_read on public.ayu_distributor_payments
  for select to authenticated using (
    distributor_id = (select auth.uid()) or exists (
      select 1 from public.ayu_profiles p where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists ayu_distributor_adjustments_read on public.ayu_distributor_adjustment_requests;
create policy ayu_distributor_adjustments_read on public.ayu_distributor_adjustment_requests
  for select to authenticated using (
    distributor_id = (select auth.uid()) or exists (
      select 1 from public.ayu_profiles p where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

revoke all on public.ayu_distributor_inventory, public.ayu_distributor_ledger,
  public.ayu_distributor_commissions, public.ayu_distributor_payments,
  public.ayu_distributor_adjustment_requests from anon, authenticated;
grant select on public.ayu_distributor_inventory, public.ayu_distributor_ledger,
  public.ayu_distributor_commissions, public.ayu_distributor_payments,
  public.ayu_distributor_adjustment_requests to authenticated;

create or replace function public.admin_distributor_stock_receipt(
  target_distributor uuid,
  target_product uuid,
  received_quantity integer,
  transaction_request uuid,
  notes text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  ledger_id uuid;
  prior public.ayu_distributor_ledger%rowtype;
begin
  if auth.uid() is null or not exists (
    select 1 from public.ayu_profiles p where p.id = auth.uid() and p.role = 'admin'
  ) then raise exception 'Administrator access required'; end if;
  if received_quantity is null or received_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  if transaction_request is null then raise exception 'Transaction request ID is required'; end if;
  select * into prior from public.ayu_distributor_ledger l where l.request_id = transaction_request;
  if found then
    if prior.distributor_id <> target_distributor or prior.product_id <> target_product or prior.quantity <> received_quantity or prior.transaction_type <> 'PRODUCT_RECEIVED' or prior.description is distinct from coalesce(notes, 'Stock received from company') then
      raise exception 'Request ID was already used for a different transaction';
    end if;
    return prior.id;
  end if;
  if not exists (select 1 from public.ayu_distributors d where d.user_id = target_distributor) then
    raise exception 'Distributor not found';
  end if;
  insert into public.ayu_distributor_inventory(distributor_id, product_id, quantity)
    values (target_distributor, target_product, received_quantity)
    on conflict (distributor_id, product_id) do update
      set quantity = public.ayu_distributor_inventory.quantity + excluded.quantity, updated_at = now();
  insert into public.ayu_distributor_ledger(
    distributor_id, product_id, product_name, transaction_type, quantity, description, request_id, created_by
  ) values (
    target_distributor, target_product, (select p.name from public.ayu_products p where p.id = target_product), 'PRODUCT_RECEIVED', received_quantity,
    coalesce(notes, 'Stock received from company'), transaction_request, auth.uid()
  ) returning id into ledger_id;
  return ledger_id;
end;
$$;

drop function if exists public.sell_distributor_product(uuid, integer, numeric, text, text, text, date, uuid);
create or replace function public.sell_distributor_product(
  target_product uuid,
  sold_quantity integer,
  customer text,
  customer_phone_value text,
  method text,
  customer_payment_status text,
  transaction_date date,
  transaction_request uuid
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  current_quantity integer;
  distributor_status text;
  ledger_id uuid;
  commission_ledger_id uuid;
  product_label text;
  authoritative_price numeric(12,2);
  commission_rate numeric(5,2);
  sale_total numeric(12,2);
  commission_total numeric(12,2);
  prior public.ayu_distributor_ledger%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if transaction_request is null then raise exception 'Transaction request ID is required'; end if;
  select * into prior from public.ayu_distributor_ledger l where l.request_id = transaction_request;
  if found then
    if prior.distributor_id <> auth.uid() or prior.product_id <> target_product or prior.quantity <> sold_quantity or prior.transaction_type <> 'PRODUCT_SOLD' or prior.payment_method is distinct from method or prior.customer_name is distinct from nullif(trim(customer), '') or prior.customer_phone is distinct from nullif(trim(customer_phone_value), '') or prior.payment_status is distinct from customer_payment_status or prior.sale_date is distinct from coalesce(transaction_date, current_date) then
      raise exception 'Request ID was already used for a different transaction';
    end if;
    return prior.id;
  end if;
  if sold_quantity is null or sold_quantity <= 0 then raise exception 'Quantity must be positive'; end if;
  if method not in ('CASH', 'UPI', 'BANK_TRANSFER', 'OTHER') then raise exception 'Invalid payment method'; end if;
  if customer_payment_status not in ('PAID', 'PENDING') then raise exception 'Invalid payment status'; end if;
  select d.status into distributor_status from public.ayu_distributors d
    where d.user_id = auth.uid() for update;
  if distributor_status is distinct from 'approved' then raise exception 'Approved distributor account required'; end if;
  select p.name, p.account_sale_price, p.distributor_commission_rate into product_label, authoritative_price, commission_rate
    from public.ayu_products p where p.id = target_product and p.is_published = true for share;
  if not found then raise exception 'Product is unavailable for sale'; end if;
  if authoritative_price <= 0 then raise exception 'This product has no distributor sale price yet'; end if;
  if commission_rate < 0 or commission_rate > 100 then raise exception 'Product commission rate is invalid'; end if;
  insert into public.ayu_distributor_inventory(distributor_id, product_id, quantity)
    values (auth.uid(), target_product, 0) on conflict do nothing;
  select i.quantity into current_quantity from public.ayu_distributor_inventory i
    where i.distributor_id = auth.uid() and i.product_id = target_product for update;
  if current_quantity < sold_quantity then raise exception 'Insufficient stock'; end if;
  sale_total := round(sold_quantity * authoritative_price, 2);
  commission_total := round(sale_total * commission_rate / 100, 2);
  update public.ayu_distributor_inventory i set quantity = i.quantity - sold_quantity, updated_at = now()
    where i.distributor_id = auth.uid() and i.product_id = target_product;
  insert into public.ayu_distributor_ledger(
    distributor_id, product_id, product_name, transaction_type, quantity, selling_price, total_amount,
    payment_status, payment_method, customer_name, customer_phone, description,
    request_id, created_by, sale_date
  ) values (
    auth.uid(), target_product, product_label, 'PRODUCT_SOLD', sold_quantity, authoritative_price,
    sale_total, customer_payment_status, method,
    nullif(trim(customer), ''), nullif(trim(customer_phone_value), ''),
    'Personal product sale; excluded from binary business volume.',
    transaction_request, auth.uid(), coalesce(transaction_date, current_date)
  ) returning id into ledger_id;
  if commission_total > 0 then
    insert into public.ayu_distributor_ledger(
      distributor_id, product_id, product_name, transaction_type, total_amount, commission_amount,
      description, related_transaction_id, created_by, sale_date
    ) values (
      auth.uid(), target_product, product_label, 'COMMISSION_EARNED', commission_total, commission_total,
      'Personal product sale commission at ' || commission_rate::text || '%', ledger_id, auth.uid(), coalesce(transaction_date, current_date)
    ) returning id into commission_ledger_id;
    insert into public.ayu_distributor_commissions(distributor_id, ledger_id, commission_amount, commission_type)
    values (auth.uid(), commission_ledger_id, commission_total, 'PERSONAL_PRODUCT_SALE');
  end if;
  if customer_payment_status = 'PENDING' then
    insert into public.ayu_distributor_ledger(
      distributor_id, product_id, product_name, transaction_type, total_amount, payment_status,
      description, related_transaction_id, created_by, sale_date
    ) values (
      auth.uid(), target_product, product_label, 'PAYMENT_PENDING', sale_total, 'PENDING',
      'Customer payment pending for transaction ' || ledger_id::text, ledger_id, auth.uid(), coalesce(transaction_date, current_date)
    );
  end if;
  return ledger_id;
end;
$$;

create or replace function public.admin_record_distributor_payment(
  target_distributor uuid,
  payment_amount numeric,
  method text,
  transaction_request uuid,
  notes text default null
)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  ledger_id uuid;
  prior public.ayu_distributor_ledger%rowtype;
begin
  if auth.uid() is null or not exists (
    select 1 from public.ayu_profiles p where p.id = auth.uid() and p.role = 'admin'
  ) then raise exception 'Administrator access required'; end if;
  if payment_amount is null or payment_amount <= 0 or transaction_request is null then raise exception 'Payment amount and request ID are required'; end if;
  if not exists (select 1 from public.ayu_distributors d where d.user_id = target_distributor) then raise exception 'Distributor not found'; end if;
  select * into prior from public.ayu_distributor_ledger l where l.request_id = transaction_request;
  if found then
    if prior.distributor_id <> target_distributor or prior.transaction_type <> 'PAYMENT_RECEIVED' or prior.total_amount <> payment_amount or prior.payment_method is distinct from method then
      raise exception 'Request ID was already used for a different transaction';
    end if;
    return prior.id;
  end if;
  insert into public.ayu_distributor_ledger(
    distributor_id, transaction_type, total_amount, payment_status, payment_method,
    description, request_id, created_by
  ) values (
    target_distributor, 'PAYMENT_RECEIVED', payment_amount, 'PAID', method,
    coalesce(notes, 'Payment recorded by administrator'), transaction_request, auth.uid()
  ) returning id into ledger_id;
  insert into public.ayu_distributor_payments(distributor_id, ledger_id, payment_amount, method, reference, created_by)
  values (target_distributor, ledger_id, payment_amount, method, notes, auth.uid());
  return ledger_id;
end;
$$;

create or replace function public.distributor_request_stock_adjustment(target_product uuid, quantity_delta integer, notes text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare request_id uuid;
begin
  if auth.uid() is null or not exists (select 1 from public.ayu_distributors d where d.user_id = auth.uid() and d.status = 'approved') then
    raise exception 'Approved distributor account required';
  end if;
  if quantity_delta is null or quantity_delta = 0 or nullif(trim(notes), '') is null then raise exception 'Quantity and reason are required'; end if;
  insert into public.ayu_distributor_adjustment_requests(distributor_id, product_id, quantity_delta, description)
  values (auth.uid(), target_product, quantity_delta, trim(notes)) returning id into request_id;
  return request_id;
end;
$$;

create or replace function public.admin_review_stock_adjustment(request_id uuid, approve boolean, notes text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare request_row public.ayu_distributor_adjustment_requests%rowtype; available integer; product_label text;
begin
  if auth.uid() is null or not exists (select 1 from public.ayu_profiles p where p.id = auth.uid() and p.role = 'admin') then
    raise exception 'Administrator access required';
  end if;
  select * into request_row from public.ayu_distributor_adjustment_requests r where r.id = request_id for update;
  if not found or request_row.status <> 'PENDING' then raise exception 'Pending adjustment request not found'; end if;
  if approve then
    select p.name into product_label from public.ayu_products p where p.id = request_row.product_id;
    insert into public.ayu_distributor_inventory(distributor_id, product_id, quantity)
    values (request_row.distributor_id, request_row.product_id, greatest(request_row.quantity_delta, 0)) on conflict do nothing;
    select i.quantity into available from public.ayu_distributor_inventory i
      where i.distributor_id = request_row.distributor_id and i.product_id = request_row.product_id for update;
    if available + request_row.quantity_delta < 0 then raise exception 'Adjustment would make stock negative'; end if;
    update public.ayu_distributor_inventory i set quantity = available + request_row.quantity_delta, updated_at = now()
      where i.distributor_id = request_row.distributor_id and i.product_id = request_row.product_id;
    insert into public.ayu_distributor_ledger(distributor_id, product_id, product_name, transaction_type, quantity, description, created_by)
    values (request_row.distributor_id, request_row.product_id, product_label, 'STOCK_ADJUSTMENT', request_row.quantity_delta,
      coalesce(nullif(trim(notes), ''), request_row.description), auth.uid());
    update public.ayu_distributor_adjustment_requests set status = 'APPROVED', reviewed_by = auth.uid(), reviewed_at = now() where id = request_id;
  else
    update public.ayu_distributor_adjustment_requests set status = 'REJECTED', reviewed_by = auth.uid(), reviewed_at = now() where id = request_id;
  end if;
end;
$$;

revoke all on function public.admin_distributor_stock_receipt(uuid, uuid, integer, uuid, text) from public, anon;
revoke all on function public.sell_distributor_product(uuid, integer, text, text, text, text, date, uuid) from public, anon;
revoke all on function public.admin_record_distributor_payment(uuid, numeric, text, uuid, text) from public, anon;
revoke all on function public.distributor_request_stock_adjustment(uuid, integer, text) from public, anon;
revoke all on function public.admin_review_stock_adjustment(uuid, boolean, text) from public, anon;
grant execute on function public.admin_distributor_stock_receipt(uuid, uuid, integer, uuid, text) to authenticated;
grant execute on function public.sell_distributor_product(uuid, integer, text, text, text, text, date, uuid) to authenticated;
grant execute on function public.admin_record_distributor_payment(uuid, numeric, text, uuid, text) to authenticated;
grant execute on function public.distributor_request_stock_adjustment(uuid, integer, text) to authenticated;
grant execute on function public.admin_review_stock_adjustment(uuid, boolean, text) to authenticated;

notify pgrst, 'reload schema';