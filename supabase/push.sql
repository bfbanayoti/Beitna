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
