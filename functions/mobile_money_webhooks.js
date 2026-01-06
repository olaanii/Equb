const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();
const firestore = admin.firestore();

// Telebirr webhook handler
exports.telebirrWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Only accept POST requests
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const signature = req.headers['x-telebirr-signature'] || '';
    const payload = req.body;

    // Get Telebirr public key from environment or config
    const telebirrPublicKey = functions.config().telebirr?.public_key ||
      process.env.TELEBIRR_PUBLIC_KEY;

    if (!telebirrPublicKey) {
      console.error('Telebirr public key not configured');
      return res.status(500).send({ error: 'Configuration error' });
    }

    // Verify signature
    const verify = crypto.createVerify('SHA256');
    verify.update(JSON.stringify(payload));
    verify.end();

    const validSignature = verify.verify(telebirrPublicKey, signature, 'base64');

    if (!validSignature) {
      console.warn('Invalid Telebirr signature');
      return res.status(401).send({ error: 'Invalid signature' });
    }

    const { merchantOrderId, status, amount, payer, payee } = payload;

    if (!merchantOrderId) {
      return res.status(400).send({ error: 'Missing merchantOrderId' });
    }

    // Map Telebirr status to internal status
    let internalStatus;
    switch (status?.toLowerCase()) {
      case 'success':
      case 'completed':
        internalStatus = 'success';
        break;
      case 'failed':
      case 'error':
        internalStatus = 'failed';
        break;
      case 'pending':
      case 'processing':
      default:
        internalStatus = 'pending';
        break;
    }

    // Update transaction in Realtime Database
    const transactionRef = db.ref(`users/${payee}/transactions/${merchantOrderId}`);
    const transactionSnapshot = await transactionRef.once('value');

    if (transactionSnapshot.exists()) {
      await transactionRef.update({
        status: internalStatus,
        gatewayResponse: payload,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
    } else {
      // If transaction not found in user transactions, try to find it in general transactions
      const generalTxRef = firestore.collection('transactions').doc(merchantOrderId);
      const generalTxDoc = await generalTxRef.get();

      if (generalTxDoc.exists) {
        await generalTxRef.update({
          status: internalStatus,
          gatewayResponse: payload,
          updatedAt: new Date(),
        });
      } else {
        console.warn(`Transaction ${merchantOrderId} not found`);
        return res.status(404).send({ error: 'Transaction not found' });
      }
    }

    // Log the webhook event
    await firestore.collection('webhook_logs').add({
      gateway: 'telebirr',
      merchantOrderId,
      status,
      internalStatus,
      amount,
      payer,
      payee,
      payload,
      receivedAt: new Date(),
    });

    console.log(`Telebirr webhook processed: ${merchantOrderId} -> ${internalStatus}`);

    return res.status(200).send({ success: true });

  } catch (error) {
    console.error('Telebirr webhook error:', error);
    return res.status(500).send({ error: 'Internal server error' });
  }
});

// CBE Birr webhook handler
exports.cbeBirrWebhook = functions.https.onRequest(async (req, res) => {
  try {
    // Only accept POST requests
    if (req.method !== 'POST') {
      return res.status(405).send({ error: 'Method not allowed' });
    }

    const signature = req.headers['x-cbe-signature'] || '';
    const payload = req.body;

    // Get CBE secret from environment or config
    const cbeSecret = functions.config().cbe?.secret || process.env.CBE_SECRET;

    if (!cbeSecret) {
      console.error('CBE secret not configured');
      return res.status(500).send({ error: 'Configuration error' });
    }

    // Verify signature (HMAC-SHA256)
    const expectedSignature = crypto
      .createHmac('sha256', cbeSecret)
      .update(JSON.stringify(payload))
      .digest('base64');

    if (signature !== expectedSignature) {
      console.warn('Invalid CBE signature');
      return res.status(401).send({ error: 'Invalid signature' });
    }

    const { merchantOrderId, state, amount, payerId, payeeId } = payload;

    if (!merchantOrderId) {
      return res.status(400).send({ error: 'Missing merchantOrderId' });
    }

    // Map CBE state to internal status
    let internalStatus;
    switch (state?.toLowerCase()) {
      case 'completed':
      case 'success':
        internalStatus = 'success';
        break;
      case 'failed':
      case 'error':
        internalStatus = 'failed';
        break;
      case 'pending':
      case 'processing':
      default:
        internalStatus = 'pending';
        break;
    }

    // Update transaction in Realtime Database
    const transactionRef = db.ref(`users/${payeeId}/transactions/${merchantOrderId}`);
    const transactionSnapshot = await transactionRef.once('value');

    if (transactionSnapshot.exists()) {
      await transactionRef.update({
        status: internalStatus,
        gatewayResponse: payload,
        updatedAt: admin.database.ServerValue.TIMESTAMP,
      });
    } else {
      // If transaction not found in user transactions, try to find it in general transactions
      const generalTxRef = firestore.collection('transactions').doc(merchantOrderId);
      const generalTxDoc = await generalTxRef.get();

      if (generalTxDoc.exists) {
        await generalTxRef.update({
          status: internalStatus,
          gatewayResponse: payload,
          updatedAt: new Date(),
        });
      } else {
        console.warn(`Transaction ${merchantOrderId} not found`);
        return res.status(404).send({ error: 'Transaction not found' });
      }
    }

    // Log the webhook event
    await firestore.collection('webhook_logs').add({
      gateway: 'cbe_birr',
      merchantOrderId,
      state,
      internalStatus,
      amount,
      payerId,
      payeeId,
      payload,
      receivedAt: new Date(),
    });

    console.log(`CBE Birr webhook processed: ${merchantOrderId} -> ${internalStatus}`);

    return res.status(200).send({ success: true });

  } catch (error) {
    console.error('CBE Birr webhook error:', error);
    return res.status(500).send({ error: 'Internal server error' });
  }
});

// Mobile money transaction status checker (for polling fallback)
exports.checkMobileMoneyTransaction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const { transactionId, gateway } = data;

    if (!transactionId || !gateway) {
      throw new functions.https.HttpsError('invalid-argument', 'transactionId and gateway required');
    }

    let status = 'unknown';
    let details = {};

    // Check transaction status based on gateway
    if (gateway === 'telebirr') {
      // This would call Telebirr API to check status
      // For now, return pending
      status = 'pending';
      details = { message: 'Telebirr status check not yet implemented' };
    } else if (gateway === 'cbe_birr') {
      // This would call CBE API to check status
      // For now, return pending
      status = 'pending';
      details = { message: 'CBE Birr status check not yet implemented' };
    } else {
      throw new functions.https.HttpsError('invalid-argument', 'Unsupported gateway');
    }

    return {
      success: true,
      transactionId,
      gateway,
      status,
      details,
      checkedAt: new Date().toISOString(),
    };

  } catch (error) {
    console.error('Mobile money transaction check error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to check transaction status');
  }
});

// Process pending mobile money transactions (scheduled function)
exports.processPendingMobileMoneyTransactions = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Processing pending mobile money transactions...');

    try {
      // Get pending transactions from Firestore
      const pendingTransactions = await firestore
        .collection('transactions')
        .where('gateway', 'in', ['telebirr', 'cbe_birr'])
        .where('status', '==', 'pending')
        .where('createdAt', '<', new Date(Date.now() - 5 * 60 * 1000)) // Older than 5 minutes
        .limit(50)
        .get();

      console.log(`Found ${pendingTransactions.size} pending transactions to check`);

      for (const doc of pendingTransactions.docs) {
        const transaction = doc.data();

        try {
          // Call the status check function
          const result = await checkMobileMoneyTransaction({
            transactionId: transaction.id,
            gateway: transaction.gateway,
          }, { auth: { uid: 'system' } }); // System context

          if (result.status !== 'pending') {
            await doc.ref.update({
              status: result.status,
              lastChecked: new Date(),
              statusDetails: result.details,
            });
          }
        } catch (error) {
          console.error(`Failed to check transaction ${doc.id}:`, error);
        }
      }

      console.log('Finished processing pending transactions');
      return null;

    } catch (error) {
      console.error('Error processing pending transactions:', error);
      return null;
    }
  });

// Helper function for internal use
async function checkMobileMoneyTransaction(data, context) {
  const { transactionId, gateway } = data;

  if (gateway === 'telebirr') {
    // Implement Telebirr API status check
    // This would make HTTP request to Telebirr API
    return {
      success: true,
      transactionId,
      gateway,
      status: 'pending', // Placeholder
      details: { message: 'API check not implemented' },
      checkedAt: new Date().toISOString(),
    };
  } else if (gateway === 'cbe_birr') {
    // Implement CBE API status check
    // This would make HTTP request to CBE API
    return {
      success: true,
      transactionId,
      gateway,
      status: 'pending', // Placeholder
      details: { message: 'API check not implemented' },
      checkedAt: new Date().toISOString(),
    };
  }

  throw new Error('Unsupported gateway');
}

