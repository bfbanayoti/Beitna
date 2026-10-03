-- Beitna sync: shared household between partners. Run once in Supabase → SQL Editor.
-- Each partner signs in with their own account. A household has up to two members (partner slots A and B).
-- household_docs holds the shared household (one JSON document, versioned for safe merging).
-- private_docs holds each partner's hidden accounts + their transactions: only that partner can ever read it.

create table if not exists public.households (
  id         uuid primary key default gen_random_uuid(),
  name       text not null default 'Beitna',
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.household_members (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  slot         text not null check (slot in ('A','B')),
  joined_at    timestamptz not null default now(),
  primary key (household_id, user_id),
  unique (household_id, slot)
);
create table if not exists public.household_docs (
  household_id uuid primary key references public.households(id) on delete cascade,
  data         jsonb not null,
  version      bigint not null default 1,
  updated_at   timestamptz not null default now(),
  updated_by   uuid references auth.users(id)
);
create table if not exists public.private_docs (
  household_id uuid not null references public.households(id) on delete cascade,
  user_id      uuid not null references auth.users(id) on delete cascade,
  data         jsonb not null default '{}'::jsonb,
  version      bigint not null default 1,
  updated_at   timestamptz not null default now(),
  primary key (household_id, user_id)
);
create table if not exists public.invites (
  code         text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  slot         text not null check (slot in ('A','B')),
  created_by   uuid not null references auth.users(id) on delete cascade,
  expires_at   timestamptz not null default now() + interval '7 days',
  used_by      uuid references auth.users(id),
  used_at      timestamptz
);

-- membership check used by the policies (security definer avoids recursive policy lookups)
create or replace function public.is_member(h uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.household_members where household_id = h and user_id = auth.uid())
$$;

alter table public.households        enable row level security;
alter table public.household_members enable row level security;
alter table public.household_docs    enable row level security;
alter table public.private_docs      enable row level security;
alter table public.invites           enable row level security;
revoke all on public.households, public.household_members, public.household_docs, public.private_docs, public.invites from anon, authenticated;
grant select on public.households, public.household_members, public.household_docs, public.private_docs to authenticated;

drop policy if exists "members read household" on public.households;
create policy "members read household" on public.households for select to authenticated using (public.is_member(id));
drop policy if exists "members read members" on public.household_members;
create policy "members read members" on public.household_members for select to authenticated using (public.is_member(household_id));
drop policy if exists "members read doc" on public.household_docs;
create policy "members read doc" on public.household_docs for select to authenticated using (public.is_member(household_id));
drop policy if exists "owner reads private doc" on public.private_docs;
create policy "owner reads private doc" on public.private_docs for select to authenticated using (user_id = auth.uid());
-- all writes go through the functions below

-- create a household from this phone's data; the creator becomes partner A
create or replace function public.create_household(p_data jsonb, p_private jsonb default '{}'::jsonb, p_name text default 'Beitna')
returns jsonb language plpgsql security definer set search_path = public as $$
declare h uuid;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then raise exception 'already in a household'; end if;
  insert into public.households (name, created_by) values (left(coalesce(p_name,'Beitna'),60), auth.uid()) returning id into h;
  insert into public.household_members (household_id, user_id, slot) values (h, auth.uid(), 'A');
  insert into public.household_docs (household_id, data, updated_by) values (h, p_data, auth.uid());
  insert into public.private_docs (household_id, user_id, data) values (h, auth.uid(), coalesce(p_private,'{}'::jsonb));
  return jsonb_build_object('household', h, 'slot', 'A', 'version', 1, 'pversion', 1);
end $$;

-- save the shared document only if nobody else saved since base_version; otherwise return theirs to merge
create or replace function public.save_doc(p_household uuid, p_data jsonb, p_base bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cur public.household_docs;
begin
  if not public.is_member(p_household) then raise exception 'not a member'; end if;
  select * into cur from public.household_docs where household_id = p_household for update;
  if cur.version <> p_base then
    return jsonb_build_object('ok', false, 'version', cur.version, 'data', cur.data);
  end if;
  update public.household_docs set data = p_data, version = cur.version + 1, updated_at = now(), updated_by = auth.uid()
    where household_id = p_household;
  return jsonb_build_object('ok', true, 'version', cur.version + 1);
end $$;

create or replace function public.save_private(p_household uuid, p_data jsonb, p_base bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare cur public.private_docs;
begin
  if not public.is_member(p_household) then raise exception 'not a member'; end if;
  insert into public.private_docs (household_id, user_id, data, version) values (p_household, auth.uid(), '{}'::jsonb, 0)
    on conflict (household_id, user_id) do nothing;
  select * into cur from public.private_docs where household_id = p_household and user_id = auth.uid() for update;
  if cur.version <> p_base then return jsonb_build_object('ok', false, 'version', cur.version, 'data', cur.data); end if;
  update public.private_docs set data = p_data, version = cur.version + 1, updated_at = now()
    where household_id = p_household and user_id = auth.uid();
  return jsonb_build_object('ok', true, 'version', cur.version + 1);
end $$;

-- invite the partner: a 6-character code for the free slot, valid 7 days
create or replace function public.create_invite(p_household uuid)
returns text language plpgsql security definer set search_path = public as $$
declare free text; c text;
begin
  if not public.is_member(p_household) then raise exception 'not a member'; end if;
  select s into free from (values ('A'),('B')) v(s)
    where not exists (select 1 from public.household_members m where m.household_id = p_household and m.slot = v.s) limit 1;
  if free is null then raise exception 'household is full'; end if;
  delete from public.invites where household_id = p_household and used_by is null;
  loop
    c := upper(substr(translate(encode(extensions.gen_random_bytes(8), 'base64'), '+/=0O1Il', ''), 1, 6));
    exit when length(c) = 6 and not exists (select 1 from public.invites where code = c);
  end loop;
  insert into public.invites (code, household_id, slot, created_by) values (c, p_household, free, auth.uid());
  return c;
end $$;

create or replace function public.join_household(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare inv public.invites;
begin
  if auth.uid() is null then raise exception 'sign in first'; end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then raise exception 'already in a household'; end if;
  select * into inv from public.invites where code = upper(trim(p_code)) for update;
  if inv is null or inv.used_by is not null or inv.expires_at < now() then raise exception 'invalid or expired code'; end if;
  insert into public.household_members (household_id, user_id, slot) values (inv.household_id, auth.uid(), inv.slot);
  insert into public.private_docs (household_id, user_id, data) values (inv.household_id, auth.uid(), '{}'::jsonb) on conflict do nothing;
  update public.invites set used_by = auth.uid(), used_at = now() where code = inv.code;
  return jsonb_build_object('household', inv.household_id, 'slot', inv.slot);
end $$;

-- leave the household (the other partner keeps everything)
create or replace function public.leave_household(p_household uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.private_docs where household_id = p_household and user_id = auth.uid();
  delete from public.household_members where household_id = p_household and user_id = auth.uid();
  delete from public.households h where h.id = p_household and not exists (select 1 from public.household_members m where m.household_id = h.id);
end $$;

revoke all on function public.create_household, public.save_doc, public.save_private, public.create_invite, public.join_household, public.leave_household from public, anon;
grant execute on function public.create_household, public.save_doc, public.save_private, public.create_invite, public.join_household, public.leave_household, public.is_member to authenticated;

-- live updates to the other phone (row-level security still applies)
alter table public.household_docs replica identity full;
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='household_docs') then
    alter publication supabase_realtime add table public.household_docs;
  end if;
end $$;
