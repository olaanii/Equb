// Example scheduler that runs periodically (cron) to send reminders and process payouts.
// This is a sample Node.js script intended for serverless cron or a small worker.

const { createClient } = require('@supabase/supabase-js');
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY; // server key to call FCM HTTP API

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function run() {
  // Find groups with upcoming contribution due (example: where next_due <= now + 1 day)
  const { data: groups } = await supabase.rpc('get_due_groups'); // assumes a Postgres function
  if (!groups || groups.length === 0) return;

  for (const g of groups) {
    // find members and their device tokens
    const { data: members } = await supabase.from('users').select('id,device_token').in('id', g.member_ids || []);
    // send FCM notifications
    for (const m of members) {
      if (!m.device_token) continue;
      await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `key=${FCM_SERVER_KEY}` },
        body: JSON.stringify({ to: m.device_token, notification: { title: 'Equb reminder', body: `Contribution due for ${g.name}` } }),
      });
    }
  }
}

run().catch((e) => console.error(e));
