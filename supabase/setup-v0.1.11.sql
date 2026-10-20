-- Beitna v0.1.11 setup: paste this whole file into Supabase → SQL Editor and press Run (safe to run again).
-- 1) Partner sync
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

-- 2) Reminders (Web Push)
-- Beitna reminders (Web Push). Run once in Supabase → SQL Editor (safe to run again).
-- Each phone that turns on reminders registers its push subscription plus the next ~5 weeks of reminders
-- (worked out on the phone: bill names and dates, payday, Friday money date — never amounts).
-- The beitna-push Edge Function, called every 10 minutes by pg_cron, delivers the ones that are due.
create table if not exists public.push_subs (
  id uuid primary key default gen_random_uuid(),
  endpoint text unique not null,
  p256dh text not null,
  auth text not null,
  lang text,
  updated_at timestamptz not null default now()
);
create table if not exists public.push_items (
  id bigserial primary key,
  sub_id uuid not null references public.push_subs(id) on delete cascade,
  due_at timestamptz not null,
  title text not null,
  body text,
  tag text,
  url text,
  sent_at timestamptz
);
create index if not exists push_items_due on public.push_items (due_at) where sent_at is null;
create index if not exists push_items_sub_tag on public.push_items (sub_id, tag);
-- no policies: the tables are only reachable through the two functions below and the service role
alter table public.push_subs enable row level security;
alter table public.push_items enable row level security;

create or replace function public.push_register(p_endpoint text, p_p256dh text, p_auth text, p_lang text, p_items jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare sid uuid; n int;
begin
  if p_endpoint is null or length(p_endpoint) > 1000 or p_endpoint !~ '^https://' then raise exception 'bad endpoint'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) > 80 then raise exception 'too many items'; end if;
  insert into push_subs (endpoint, p256dh, auth, lang, updated_at)
  values (p_endpoint, left(p_p256dh, 200), left(p_auth, 100), left(p_lang, 5), now())
  on conflict (endpoint) do update set p256dh = excluded.p256dh, auth = excluded.auth, lang = excluded.lang, updated_at = now()
  returning id into sid;
  -- replace this phone's unsent reminders; anything already delivered (same tag) is never sent twice
  delete from push_items where sub_id = sid and sent_at is null;
  insert into push_items (sub_id, due_at, title, body, tag, url)
  select sid, (x->>'at')::timestamptz, left(x->>'title', 80), left(x->>'body', 180), left(x->>'tag', 60), left(x->>'url', 200)
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) x
  where (x->>'at')::timestamptz between now() - interval '1 hour' and now() + interval '40 days'
    and not exists (select 1 from push_items p where p.sub_id = sid and p.tag = x->>'tag' and p.sent_at is not null);
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function public.push_unregister(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from push_subs where endpoint = p_endpoint;
$$;

revoke all on function public.push_register(text, text, text, text, jsonb) from public;
revoke all on function public.push_unregister(text) from public;
grant execute on function public.push_register(text, text, text, text, jsonb) to anon, authenticated;
grant execute on function public.push_unregister(text) to anon, authenticated;

-- every 10 minutes, ask the beitna-push function to deliver what's due (it only ever sends due, unsent items)
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.unschedule('beitna-push') where exists (select 1 from cron.job where jobname = 'beitna-push');
select cron.schedule('beitna-push', '*/10 * * * *', $$
  select net.http_post(url := 'https://ojxaxcxdamhqeggfgmkr.supabase.co/functions/v1/beitna-push',
                       headers := '{"Content-Type":"application/json"}'::jsonb, body := '{}'::jsonb);
$$);

-- 3) Analytics milestones
-- Beitna Analytics: record the app's milestone events (kind 'goal': trial started, statement imported, partner invited,
-- reminders on, Friday money date done, recap shared, trial-ended paywall seen). Safe to run again.
alter table public.events drop constraint if exists events_kind_check;
alter table public.events add constraint events_kind_check check (kind in ('page','sheet','action','error','goal'));

create or replace function public.log_events(p_session uuid, p_events jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if p_session is null or jsonb_typeof(p_events) <> 'array' then return; end if;
  insert into public.sessions (id) values (p_session) on conflict (id) do nothing;   -- if events arrive before start_session
  if (select started_at from public.sessions where id = p_session) < now() - interval '24 hours' then return; end if;
  insert into public.events (session_id, at, kind, name, detail)
  select p_session, least(coalesce((e->>'at')::timestamptz, now()), now()), e->>'kind', left(e->>'name',40), left(e->>'detail',60)
  from jsonb_array_elements(p_events) with ordinality as x(e, i)
  where i <= 50 and e->>'kind' in ('page','sheet','action','error','goal') and coalesce(e->>'name','') <> '';
  get diagnostics n = row_count;
  update public.sessions set last_at = now(), events = events + n where id = p_session;
end $$;
revoke all on function public.log_events from public;
grant execute on function public.log_events to anon, authenticated;
