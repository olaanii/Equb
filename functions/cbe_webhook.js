// Example CBE Birr webhook handler for serverless platforms
const { createClient } = require('@supabase/supabase-js');
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const CBE_SECRET = process.env.CBE_SECRET || 'replace_with_secret';
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

module.exports = async (req, res) => {
  try {
  // verify payload signature per CBE docs (provider-specific). Example HMAC placeholder:
  const crypto = require('crypto');
  const payload = req.body;
  const raw = JSON.stringify(payload);
  const expected = crypto.createHmac('sha256', CBE_SECRET).update(raw).digest('base64');
  const signature = req.headers['x-cbe-signature'] || '';
  if (signature !== expected) return res.status(401).send({ error: 'invalid signature' });
    const { merchantOrderId, state } = payload;
    const txStatus = state === 'COMPLETED' ? 'success' : (state === 'PENDING' ? 'pending' : 'failed');
    await supabase.from('transactions').update({ status: txStatus }).eq('id', merchantOrderId);
    await supabase.from('audit_logs').insert([{ event: 'cbe_webhook', meta: { merchantOrderId, state } }]);
    return res.status(200).send({ ok: true });
  } catch (err) {
    console.error(err);
    return res.status(500).send({ error: 'server error' });
  }
};
