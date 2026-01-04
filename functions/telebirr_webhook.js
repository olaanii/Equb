// Example Telebirr webhook handler for serverless platforms (Supabase Edge Function, Vercel, Netlify)
// This is a minimal example showing how to verify a signature and update a transaction record in Supabase.

const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');

// Configure via environment variables
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY; // Use service role for server-side updates
const TELEBIRR_PUBLIC_KEY = process.env.TELEBIRR_PUBLIC_KEY || `-----BEGIN PUBLIC KEY-----
YOUR_PUBLIC_KEY_HERE
-----END PUBLIC KEY-----`;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

module.exports = async (req, res) => {
  try {
    const signature = req.headers['x-telebirr-signature'] || '';
    const payload = req.body;

    // Verify signature (example using RSA-SHA256 with TELEBIRR_PUBLIC_KEY)
    const verify = crypto.createVerify('SHA256');
    verify.update(JSON.stringify(payload));
    verify.end();
    const valid = verify.verify(TELEBIRR_PUBLIC_KEY, signature, 'base64');

    if (!valid) {
      return res.status(401).send({ error: 'invalid signature' });
    }

    const { orderId, status } = payload;
    // Map provider status to your transaction status and update Supabase
    const txStatus = status === 'SUCCESS' ? 'success' : (status === 'PENDING' ? 'pending' : 'failed');

    await supabase.from('transactions').update({ status: txStatus }).eq('id', orderId);

    // insert audit log
    await supabase.from('audit_logs').insert([{ event: 'telebirr_webhook', meta: { orderId, status } }]);

    return res.status(200).send({ ok: true });
  } catch (err) {
    console.error('webhook error', err);
    return res.status(500).send({ error: 'server error' });
  }
};
