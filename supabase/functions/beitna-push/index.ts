// Beitna reminders: delivers due push_items as Web Push notifications. Called every 10 minutes by pg_cron (see push.sql).
// Secrets (Edge Functions → Secrets): VAPID_PUBLIC, VAPID_PRIVATE. SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// Deploy with "Verify JWT" turned off: the function only sends reminders that are already due, so calling it early is harmless.
import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
webpush.setVapidDetails('https://bfbanayoti.github.io/Beitna/', Deno.env.get('VAPID_PUBLIC')!, Deno.env.get('VAPID_PRIVATE')!);

Deno.serve(async () => {
  const now = new Date().toISOString();
  const { data: items, error } = await db.from('push_items')
    .select('id,title,body,tag,url,sub:push_subs(id,endpoint,p256dh,auth)')
    .is('sent_at', null).lte('due_at', now).order('due_at').limit(300);
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  let sent = 0, gone = 0, failed = 0;
  for (const it of items ?? []) {
    const s = it.sub as { id: string; endpoint: string; p256dh: string; auth: string } | null;
    if (!s) continue;
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        JSON.stringify({ title: it.title, body: it.body, tag: it.tag, url: it.url }), { TTL: 12 * 3600, urgency: 'normal' });
      sent++;
    } catch (e) {
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) { await db.from('push_subs').delete().eq('id', s.id); gone++; continue; } // phone unsubscribed
      failed++;
      if (code && code < 500) { /* bad request: don't retry */ } else continue; // server error: retry next run
    }
    await db.from('push_items').update({ sent_at: new Date().toISOString() }).eq('id', it.id);
  }
  // housekeeping: forget delivered reminders after 60 days
  await db.from('push_items').delete().lt('due_at', new Date(Date.now() - 60 * 864e5).toISOString());
  return new Response(JSON.stringify({ sent, gone, failed }), { headers: { 'Content-Type': 'application/json' } });
});
