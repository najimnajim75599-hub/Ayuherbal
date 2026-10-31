-- Binary distributor network migration for AYU LIFE HEARBAL
-- Run this in Supabase Dashboard > SQL Editor once.

alter table public.ayu_distributors
  add column if not exists full_name text,
  add column if not exists sponsor_id uuid,
  add column if not exists parent_id uuid,
  add column if not exists position text,
  add column if not exists network_status text not null default 'ACTIVE',
  add column if not exists hierarchy_path text not null default '';

update public.ayu_distributors
set full_name = coalesce(full_name, contact_person, business_name),
    network_status = case when network_status in ('ACTIVE', 'INACTIVE') then network_status else 'ACTIVE' end
where full_name is null or network_status is null;

alter table public.ayu_distributors
  drop constraint if exists ayu_distributors_position_check,
  add constraint ayu_distributors_position_check check (position in ('LEFT', 'RIGHT')),
  drop constraint if exists ayu_distributors_network_status_check,
  add constraint ayu_distributors_network_status_check check (network_status in ('ACTIVE', 'INACTIVE'));

create unique index if not exists ayu_distributors_parent_position_uidx
  on public.ayu_distributors(parent_id, position)
  where parent_id is not null and position is not null;
create unique index if not exists ayu_distributors_root_position_uidx
  on public.ayu_distributors(position)
  where parent_id is null and position is not null;

alter table public.ayu_distributors
  drop constraint if exists ayu_distributors_sponsor_fk;
alter table public.ayu_distributors
  add constraint ayu_distributors_sponsor_fk
  foreign key (sponsor_id) references public.ayu_distributors(user_id) on delete set null;
alter table public.ayu_distributors
  drop constraint if exists ayu_distributors_parent_fk;
alter table public.ayu_distributors
  add constraint ayu_distributors_parent_fk
  foreign key (parent_id) references public.ayu_distributors(user_id) on delete set null;

create or replace function public.prevent_distributor_cycles()
returns trigger language plpgsql as $$
declare cursor_id uuid := coalesce(new.parent_id, new.sponsor_id);
begin
  if cursor_id = new.user_id then raise exception 'A distributor cannot sponsor or parent itself'; end if;
  while cursor_id is not null loop
    if cursor_id = new.user_id then raise exception 'Circular distributor relationship is not allowed'; end if;
    select parent_id into cursor_id from public.ayu_distributors where user_id = cursor_id;
  end loop;
  return new;
end; $$;

drop trigger if exists prevent_distributor_cycles on public.ayu_distributors;
create trigger prevent_distributor_cycles
before insert or update of parent_id, sponsor_id on public.ayu_distributors
for each row execute function public.prevent_distributor_cycles();

create or replace function public.assign_distributor_code()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.distributor_code is null or new.distributor_code = '' then
    loop
      new.distributor_code := 'AYU' || lpad((floor(random() * 900000000)::bigint + 100000000)::text, 9, '0');
      exit when not exists(select 1 from public.ayu_distributors where distributor_code = new.distributor_code);
    end loop;
  end if;
  return new;
end; $$;

drop trigger if exists assign_distributor_code on public.ayu_distributors;
create trigger assign_distributor_code
before insert on public.ayu_distributors
for each row execute function public.assign_distributor_code();

create or replace function public.refresh_hierarchy_path(target_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare parent_path text; parent_id_value uuid; code text;
begin
  select distributor_code, parent_id into code, parent_id_value
  from public.ayu_distributors where user_id = target_id;
  if parent_id_value is null then
    update public.ayu_distributors set hierarchy_path = coalesce(code, target_id::text) where user_id = target_id;
  else
    select hierarchy_path into parent_path from public.ayu_distributors where user_id = parent_id_value;
    update public.ayu_distributors set hierarchy_path = coalesce(parent_path,'') || '/' || coalesce(code,target_id::text) where user_id = target_id;
  end if;
end; $$;

create index if not exists ayu_distributors_parent_idx on public.ayu_distributors(parent_id);
create index if not exists ayu_distributors_sponsor_idx on public.ayu_distributors(sponsor_id);
create index if not exists ayu_distributors_hierarchy_path_idx on public.ayu_distributors(hierarchy_path text_pattern_ops);

notify pgrst, 'reload schema';
