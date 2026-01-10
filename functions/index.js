const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

function assertAuthed(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  return context.auth.uid;
}

function isPlainObject(value) {
  return !!value && typeof value === 'object' && !Array.isArray(value);
}

function inferCycle(days) {
  const d = Number(days || 30);
  if (d === 1) return 'daily';
  if (d === 7) return 'weekly';
  if (d === 14) return 'biWeekly';
  if ([28, 29, 30, 31].includes(d)) return 'monthly';
  return 'custom';
}

async function assertAdminUid(db, callerUid) {
  const adminSnap = await db.ref(`admins/${callerUid}`).get();
  if (adminSnap.exists() && adminSnap.val() === true) return;
  throw new functions.https.HttpsError('permission-denied', 'Admin privileges required.');
}

async function assertSuperAdminUid(db, callerUid) {
  const snap = await db.ref(`superadmins/${callerUid}`).get();
  if (snap.exists() && snap.val() === true) return;
  throw new functions.https.HttpsError('permission-denied', 'Super admin privileges required.');
}

exports.bootstrapAdmin = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const setupCode = (data && data.setupCode ? String(data.setupCode) : '').trim();

  // Prefer Firebase Functions config: firebase functions:config:set app.admin_setup_code="..."
  const expected = (functions.config().app && functions.config().app.admin_setup_code)
    ? String(functions.config().app.admin_setup_code).trim()
    : '';

  if (!expected) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Admin bootstrap is not configured. Set functions config app.admin_setup_code.'
    );
  }

  if (!setupCode || setupCode !== expected) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid setup code.');
  }

  const db = admin.database();
  const updates = {};
  updates[`admins/${callerUid}`] = true;

  await db.ref().update(updates);
  return { ok: true, uid: callerUid, admin: true };
});

exports.adminReviewDeposit = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);

  const targetUserId = (data && data.targetUserId ? String(data.targetUserId) : '').trim();
  const txId = (data && data.txId ? String(data.txId) : '').trim();
  const action = (data && data.action ? String(data.action) : '').trim();
  const reason = (data && data.reason ? String(data.reason) : '').trim();

  if (!targetUserId || !txId || (action !== 'approve' && action !== 'reject')) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId, txId, action required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const userRef = db.ref(`users/${targetUserId}`);
  const txRef = userRef.child(`transactions/${txId}`);
  const queueId = `${targetUserId}_${txId}`;
  const queueRef = db.ref(`review_queue/deposits/${queueId}`);

  const txSnap = await txRef.get();
  if (!txSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'Transaction not found.');
  }

  const tx = txSnap.val() || {};
  const status = (tx.status || '').toString();
  const toUserId = (tx.toUserId || '').toString();
  const requiresReview = tx.requiresReview === true;

  if (toUserId !== 'wallet' || !requiresReview) {
    throw new functions.https.HttpsError('failed-precondition', 'Transaction is not a reviewable deposit.');
  }

  // Idempotent handling
  if (action === 'approve' && status === 'success') return { ok: true, already: true, status: 'success' };
  if (action === 'reject' && status === 'failed') return { ok: true, already: true, status: 'failed' };
  if (status !== 'pending') {
    throw new functions.https.HttpsError('failed-precondition', `Transaction status is ${status}.`);
  }

  const amount = Number(tx.amount || 0);
  const net = Number(tx.netAmount || amount);
  const fee = Number(tx.feeAmount || 0);

  // Points for deposits are based on amount.
  const points = Math.max(0, Math.floor(amount / 10));

  const nowMs = admin.database.ServerValue.TIMESTAMP;
  const notificationId = userRef.child('notifications').push().key;
  const ledgerId = userRef.child('points_ledger').push().key;

  const result = await userRef.transaction((current) => {
    if (!current || typeof current !== 'object') return;

    const walletBalance = Number(current.walletBalance || 0);
    const currentPoints = Number(current.points || 0);

    const transactions = current.transactions && typeof current.transactions === 'object'
      ? current.transactions
      : {};

    const existing = transactions[txId];
    if (!existing || typeof existing !== 'object') return;

    if ((existing.status || '').toString() !== 'pending') {
      return current; // idempotent
    }

    if (action === 'approve') {
      current.walletBalance = walletBalance + net;
      current.points = currentPoints + points;

      existing.status = 'success';
      existing.approvedAtMs = nowMs;
      existing.approvedBy = callerUid;
      existing.verificationStatus = 'success';

      if (ledgerId && points > 0) {
        const ledger = current.points_ledger && typeof current.points_ledger === 'object'
          ? current.points_ledger
          : {};
        ledger[ledgerId] = {
          delta: points,
          action: 'deposit_approved',
          createdAtMs: nowMs,
          relatedTransactionId: txId,
          metadata: { amount, fee, net }
        };
        current.points_ledger = ledger;
      }

      if (notificationId) {
        const notifications = current.notifications && typeof current.notifications === 'object'
          ? current.notifications
          : {};
        notifications[notificationId] = {
          id: notificationId,
          userId: targetUserId,
          title: 'Deposit approved',
          body: `Your deposit of ETB ${amount.toFixed(2)} has been approved.`,
          type: 'success',
          isRead: false,
          createdAt: new Date().toISOString(),
          createdAtMs: nowMs,
          metadata: { transactionId: txId }
        };
        current.notifications = notifications;
      }

    } else {
      existing.status = 'failed';
      existing.rejectedAtMs = nowMs;
      existing.rejectedBy = callerUid;
      existing.verificationStatus = 'failed';
      if (reason) existing.rejectionReason = reason;

      if (notificationId) {
        const notifications = current.notifications && typeof current.notifications === 'object'
          ? current.notifications
          : {};
        notifications[notificationId] = {
          id: notificationId,
          userId: targetUserId,
          title: 'Deposit rejected',
          body: `Your deposit of ETB ${amount.toFixed(2)} was rejected.`,
          type: 'error',
          isRead: false,
          createdAt: new Date().toISOString(),
          createdAtMs: nowMs,
          metadata: { transactionId: txId, ...(reason ? { reason } : {}) }
        };
        current.notifications = notifications;
      }
    }

    transactions[txId] = existing;
    current.transactions = transactions;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError('aborted', 'Transaction could not be committed.');
  }

  // Best-effort remove from queue after decision.
  try {
    await queueRef.remove();
  } catch (_) {}

  return { ok: true, status: action === 'approve' ? 'success' : 'failed' };
});

exports.adminListPendingDeposits = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(200, Number((data && data.limit) || 50)));

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref('review_queue/deposits').orderByChild('createdAtMs').limitToLast(limit).get();
  const raw = snap.val() || {};
  const items = Object.keys(raw).map((k) => raw[k]).filter(Boolean);
  items.sort((a, b) => Number(b.createdAtMs || 0) - Number(a.createdAtMs || 0));
  return { ok: true, items };
});

exports.adminListUsers = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(500, Number((data && data.limit) || 200)));

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref('users').limitToFirst(limit).get();
  const users = snap.val() || {};
  const items = Object.keys(users).map((uid) => {
    const u = users[uid] || {};
    return {
      id: uid,
      name: u.name || '',
      email: u.email || null,
      phone: u.phone || null,
      role: u.role || 'user',
      walletBalance: Number(u.walletBalance || 0),
      points: Number(u.points || 0),
      isVerified: !!u.isVerified,
    };
  });

  return { ok: true, items };
});

exports.adminSetUserRole = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.targetUserId ? String(data.targetUserId) : '').trim();
  const role = (data && data.role ? String(data.role) : '').trim();

  if (!targetUserId || !role) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId and role required.');
  }

  const allowed = new Set(['user', 'equbAdmin', 'superAdmin']);
  if (!allowed.has(role)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  await db.ref(`users/${targetUserId}/role`).set(role);
  await db.ref(`users/${targetUserId}/roleUpdatedAtMs`).set(admin.database.ServerValue.TIMESTAMP);
  await db.ref(`users/${targetUserId}/roleUpdatedBy`).set(callerUid);

  return { ok: true, targetUserId, role };
});

exports.adminSendUserNotification = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.targetUserId ? String(data.targetUserId) : '').trim();
  const title = (data && data.title ? String(data.title) : '').trim();
  const body = (data && data.body ? String(data.body) : '').trim();
  const type = (data && data.type ? String(data.type) : 'info').trim();
  const metadata = (data && data.metadata && typeof data.metadata === 'object') ? data.metadata : {};

  if (!targetUserId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId, title, body required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const userRef = db.ref(`users/${targetUserId}`);
  const notificationId = userRef.child('notifications').push().key;
  if (!notificationId) {
    throw new functions.https.HttpsError('internal', 'Failed to create notification id.');
  }

  await userRef.child(`notifications/${notificationId}`).set({
    id: notificationId,
    userId: targetUserId,
    title,
    body,
    type,
    isRead: false,
    createdAt: new Date().toISOString(),
    createdAtMs: admin.database.ServerValue.TIMESTAMP,
    metadata,
    createdBy: callerUid,
  });

  return { ok: true, id: notificationId };
});

exports.adminGetUserAudit = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.targetUserId ? String(data.targetUserId) : '').trim();
  const limit = Math.max(1, Math.min(100, Number((data && data.limit) || 25)));

  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUserId required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const userSnap = await db.ref(`users/${targetUserId}`).get();
  if (!userSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'User not found.');
  }
  const u = userSnap.val() || {};

  const txSnap = await db.ref(`users/${targetUserId}/transactions`).orderByChild('timestampMs').limitToLast(limit).get();
  const ledgerSnap = await db.ref(`users/${targetUserId}/points_ledger`).orderByChild('createdAtMs').limitToLast(limit).get();

  const txRaw = txSnap.val() || {};
  const ledgerRaw = ledgerSnap.val() || {};
  const transactions = Object.keys(txRaw).map((k) => txRaw[k]).filter(Boolean)
    .sort((a, b) => Number(b.timestampMs || 0) - Number(a.timestampMs || 0));
  const pointsLedger = Object.keys(ledgerRaw).map((k) => ledgerRaw[k]).filter(Boolean)
    .sort((a, b) => Number(b.createdAtMs || 0) - Number(a.createdAtMs || 0));

  return {
    ok: true,
    user: {
      id: targetUserId,
      name: u.name || '',
      email: u.email || null,
      phone: u.phone || null,
      role: u.role || 'user',
      walletBalance: Number(u.walletBalance || 0),
      points: Number(u.points || 0),
      isVerified: !!u.isVerified,
    },
    transactions,
    pointsLedger,
  };
});

// --- Admin config (backend source of truth) ---

exports.adminGetFeatureFlags = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref('admin_config/feature_flags').get();
  const raw = snap.val();
  const value = isPlainObject(raw) ? raw : {};
  const gatewayFlags = isPlainObject(value.gatewayFlags) ? value.gatewayFlags : {};

  return {
    ok: true,
    flags: {
      gemini25ProEnabled: !!value.gemini25ProEnabled,
      gatewayFlags,
    },
  };
});

exports.adminSetFeatureFlags = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const flags = data && data.flags;
  if (!isPlainObject(flags)) {
    throw new functions.https.HttpsError('invalid-argument', 'flags object required.');
  }

  const gatewayFlags = isPlainObject(flags.gatewayFlags) ? flags.gatewayFlags : {};
  await db.ref('admin_config/feature_flags').set({
    gemini25ProEnabled: !!flags.gemini25ProEnabled,
    gatewayFlags,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
  });

  return { ok: true };
});

exports.adminListGatewayOverrides = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref('admin_config/gateway_overrides').get();
  return { ok: true, items: snap.val() || {} };
});

exports.adminSetGatewayOverride = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const gatewayId = (data && data.gatewayId ? String(data.gatewayId) : '').trim();
  const override = data && data.override;
  if (!gatewayId || !isPlainObject(override)) {
    throw new functions.https.HttpsError('invalid-argument', 'gatewayId and override required.');
  }

  const meta = isPlainObject(override.meta) ? override.meta : {};
  const environment = (override.environment ? String(override.environment) : '').trim() || 'mock';

  await db.ref(`admin_config/gateway_overrides/${gatewayId}`).set({
    id: gatewayId,
    enabled: !!override.enabled,
    environment,
    meta,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
  });

  return { ok: true };
});

exports.adminSetGatewaySecret = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const gatewayId = (data && data.gatewayId ? String(data.gatewayId) : '').trim();
  const secrets = data && data.secrets;
  if (!gatewayId || !isPlainObject(secrets)) {
    throw new functions.https.HttpsError('invalid-argument', 'gatewayId and secrets object required.');
  }

  // Note: RTDB is not ideal for secrets. Prefer Secret Manager/KMS in production.
  await db.ref(`admin_config/gateway_secrets/${gatewayId}`).set({
    secrets,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
  });

  return { ok: true };
});

exports.adminGetGatewaySecretMetadata = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const gatewayId = (data && data.gatewayId ? String(data.gatewayId) : '').trim();
  if (!gatewayId) {
    throw new functions.https.HttpsError('invalid-argument', 'gatewayId required.');
  }

  const snap = await db.ref(`admin_config/gateway_secrets/${gatewayId}`).get();
  if (!snap.exists()) return { ok: true, exists: false };
  const raw = snap.val() || {};
  const secrets = isPlainObject(raw.secrets) ? raw.secrets : {};
  return {
    ok: true,
    exists: true,
    keys: Object.keys(secrets),
    updatedAtMs: raw.updatedAtMs || null,
    updatedBy: raw.updatedBy || null,
  };
});

// --- Super Admin (highest privilege) ---

exports.superAdminSetAdmin = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUid = (data && data.targetUid ? String(data.targetUid) : '').trim();
  const isAdmin = !!(data && data.isAdmin);

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required.');
  }

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  if (isAdmin) {
    await db.ref(`admins/${targetUid}`).set(true);
  } else {
    await db.ref(`admins/${targetUid}`).remove();
  }

  return { ok: true, targetUid, isAdmin };
});

exports.superAdminSetSuperAdmin = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUid = (data && data.targetUid ? String(data.targetUid) : '').trim();
  const isSuperAdmin = !!(data && data.isSuperAdmin);

  if (!targetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required.');
  }

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  if (isSuperAdmin) {
    await db.ref(`superadmins/${targetUid}`).set(true);
    // Ensure super admins are also admins.
    await db.ref(`admins/${targetUid}`).set(true);
  } else {
    await db.ref(`superadmins/${targetUid}`).remove();
  }

  return { ok: true, targetUid, isSuperAdmin };
});

exports.superAdminListAdmins = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(1000, Number((data && data.limit) || 500)));

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const [adminsSnap, superSnap] = await Promise.all([
    db.ref('admins').limitToFirst(limit).get(),
    db.ref('superadmins').limitToFirst(limit).get(),
  ]);

  const adminsRaw = adminsSnap.val() || {};
  const superRaw = superSnap.val() || {};

  const adminUids = new Set(Object.keys(adminsRaw));
  const superUids = new Set(Object.keys(superRaw));

  const items = Array.from(new Set([...adminUids, ...superUids]))
    .map((uid) => ({
      uid,
      isAdmin: adminUids.has(uid),
      isSuperAdmin: superUids.has(uid),
    }))
    .sort((a, b) => a.uid.localeCompare(b.uid));

  return { ok: true, items };
});

exports.superAdminSetFeatureFlags = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const flags = data && data.flags;
  if (!isPlainObject(flags)) {
    throw new functions.https.HttpsError('invalid-argument', 'flags object required.');
  }

  const gatewayFlags = isPlainObject(flags.gatewayFlags) ? flags.gatewayFlags : {};
  await db.ref('admin_config/feature_flags').set({
    gemini25ProEnabled: !!flags.gemini25ProEnabled,
    gatewayFlags,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
    updatedByRole: 'superAdmin',
  });

  return { ok: true };
});

exports.superAdminSetGatewaySecret = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const gatewayId = (data && data.gatewayId ? String(data.gatewayId) : '').trim();
  const secrets = data && data.secrets;
  if (!gatewayId || !isPlainObject(secrets)) {
    throw new functions.https.HttpsError('invalid-argument', 'gatewayId and secrets object required.');
  }

  await db.ref(`admin_config/gateway_secrets/${gatewayId}`).set({
    secrets,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
    updatedByRole: 'superAdmin',
  });

  return { ok: true };
});

// --- FenanPay (web CORS-safe intent creation) ---

exports.fenanpayCreateIntent = functions.https.onCall(async (data, context) => {
  // Any authenticated user can initiate a checkout; the secret is kept server-side.
  assertAuthed(context);

  const amount = Number(data && data.amount);
  const currency = (data && data.currency ? String(data.currency) : 'ETB').trim() || 'ETB';
  const paymentIntentUniqueId = (data && data.paymentIntentUniqueId ? String(data.paymentIntentUniqueId) : '').trim();

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'amount must be > 0');
  }
  if (!paymentIntentUniqueId) {
    throw new functions.https.HttpsError('invalid-argument', 'paymentIntentUniqueId required');
  }

  const methods = Array.isArray(data && data.methods) ? data.methods.map(String) : [];
  const returnUrl = (data && data.returnUrl ? String(data.returnUrl) : '').trim();
  const expireIn = Math.max(60, Math.min(86400, Number((data && data.expireIn) || 3600)));
  const commissionPaidByCustomer = !!(data && data.commissionPaidByCustomer);
  const callbackUrl = (data && data.callbackUrl ? String(data.callbackUrl) : '').trim();

  const db = admin.database();
  const secretSnap = await db.ref('admin_config/gateway_secrets/fenanpay/secrets').get();
  const secrets = secretSnap.exists() ? (secretSnap.val() || {}) : {};
  const apiKey = (secrets.depositKey || secrets.apiKey || '').toString().trim();
  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'FenanPay deposit key not configured. Set admin_config/gateway_secrets/fenanpay/secrets.depositKey (or apiKey).'
    );
  }

  const endpoint = 'https://api.fenanpay.com/api/v1/payment/sandbox/intent';
  const body = {
    amount,
    currency,
    paymentIntentUniqueId,
    methods,
    returnUrl,
    expireIn,
    commissionPaidByCustomer,
    ...(callbackUrl ? { callbackUrl } : {}),
    customerInfo: { name: context.auth.uid },
  };

  let resp;
  try {
    resp = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apiKey,
      },
      body: JSON.stringify(body),
    });
  } catch (e) {
    throw new functions.https.HttpsError('internal', `FenanPay request failed: ${e}`);
  }

  const text = await resp.text();
  if (!resp.ok) {
    throw new functions.https.HttpsError('internal', `FenanPay intent failed: ${resp.status} ${text}`);
  }

  let decoded;
  try {
    decoded = JSON.parse(text);
  } catch (_) {
    throw new functions.https.HttpsError('internal', 'FenanPay response was not valid JSON');
  }

  // Match the client extractor loosely.
  let checkoutUrl = '';
  if (decoded && typeof decoded === 'object') {
    const content = decoded.content;
    if (typeof content === 'string') checkoutUrl = content.trim();
    if (!checkoutUrl && content && typeof content === 'object') {
      checkoutUrl =
        (content.checkoutUrl || content.checkout_url || content.url || content.redirectUrl || content.redirect_url || '').toString().trim();
    }
    if (!checkoutUrl) {
      checkoutUrl = (decoded.checkoutUrl || decoded.url || decoded.redirectUrl || '').toString().trim();
    }
  }

  if (!checkoutUrl) {
    throw new functions.https.HttpsError('internal', 'FenanPay response missing checkout URL');
  }

  return { ok: true, checkoutUrl };
});

// --- Advanced Admin Functions ---

const {
  getAdminDashboardStats,
  getAdminAuditLogs,
  logAdminAction,
  performSystemMaintenance,
  generateComplianceReport,
} = require('./advanced_admin');

const {
  telebirrWebhook,
  cbeBirrWebhook,
  checkMobileMoneyTransaction,
  processPendingMobileMoneyTransactions,
} = require('./mobile_money_webhooks');

const {
  schedulePushNotification,
  sendImmediateNotification,
  cancelScheduledNotifications,
  sendScheduledNotifications,
  scheduleContributionReminders,
  schedulePayoutNotifications,
} = require('./push_notifications');

// --- Email Notifications ---

const { EmailService } = require('./email_service');
const emailService = new EmailService();

// Send welcome email when user is created
exports.sendWelcomeEmail = functions.database.ref('users/{userId}')
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const userData = snapshot.val();

    if (!userData || !userData.email) {
      console.log('No email found for user:', userId);
      return;
    }

    try {
      await emailService.sendWelcomeEmail(
        userData.email,
        userData.name || 'User'
      );
      console.log('Welcome email sent to:', userData.email);
    } catch (error) {
      console.error('Failed to send welcome email:', error);
    }
  });

// Send contribution reminder emails
exports.scheduleContributionReminders = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const db = admin.database();
    const now = new Date();
    const reminderDate = new Date(now.getTime() + (24 * 60 * 60 * 1000)); // 24 hours from now

    try {
      // Get all groups with upcoming contribution dates
      const groupsSnapshot = await db.ref('groups').get();
      if (!groupsSnapshot.exists()) return;

      const groups = groupsSnapshot.val();

      for (const [groupId, groupData] of Object.entries(groups)) {
        if (!groupData.nextPayoutDate) continue;

        const nextPayout = new Date(groupData.nextPayoutDate);
        const timeDiff = nextPayout.getTime() - reminderDate.getTime();

        // If next payout is within 24 hours, send reminders
        if (timeDiff > 0 && timeDiff <= (24 * 60 * 60 * 1000)) {
          await sendGroupContributionReminders(db, groupId, groupData);
        }
      }

      console.log('Contribution reminders processed');
    } catch (error) {
      console.error('Failed to process contribution reminders:', error);
    }
  });

// Send payout notification emails
exports.sendPayoutNotification = functions.database
  .ref('auto_topup_executions/{executionId}')
  .onCreate(async (snapshot, context) => {
    const executionData = snapshot.val();
    if (!executionData || executionData.status !== 'success') return;

    // This is for auto top-up success - you might want different logic for actual payouts
    // For now, this serves as an example of how to trigger email notifications
    console.log('Auto top-up successful, could send notification:', executionData);
  });

// Manual email sending function for admins
exports.adminSendEmail = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const to = (data && data.to ? String(data.to) : '').trim();
  const subject = (data && data.subject ? String(data.subject) : '').trim();
  const html = (data && data.html ? String(data.html) : '').trim();
  const text = (data && data.text ? String(data.text) : '').trim();

  if (!to || !subject || (!html && !text)) {
    throw new functions.https.HttpsError('invalid-argument', 'to, subject, and html/text required.');
  }

  try {
    const result = await emailService.sendEmail(to, subject, html, text);
    return { ok: true, result };
  } catch (error) {
    console.error('Failed to send email:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send email');
  }
});

// --- User Email Preferences Management ---

exports.getUserEmailPreferences = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.userId ? String(data.userId) : '').trim();

  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId required.');
  }

  // Users can only get their own preferences, admins can get any user's
  const db = admin.database();
  const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
  const isSuperAdmin = (await db.ref(`superadmins/${callerUid}`).get()).exists();

  if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Can only access your own email preferences.');
  }

  try {
    const prefsSnapshot = await db.ref(`user_email_preferences/${targetUserId}`).get();
    const preferences = prefsSnapshot.exists()
      ? prefsSnapshot.val()
      : {}; // Return empty object for defaults

    return { success: true, preferences };
  } catch (error) {
    console.error('Failed to get email preferences:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get email preferences');
  }
});

exports.updateUserEmailPreferences = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.userId ? String(data.userId) : '').trim();
  const preferences = data && data.preferences;

  if (!targetUserId || !isPlainObject(preferences)) {
    throw new functions.https.HttpsError('invalid-argument', 'userId and preferences required.');
  }

  // Users can only update their own preferences, admins can update any user's
  const db = admin.database();
  const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
  const isSuperAdmin = (await db.ref(`superadmins/${callerUid}`).get()).exists();

  if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Can only update your own email preferences.');
  }

  try {
    // Validate preferences structure
    const validKeys = [
      'contributionReminders', 'payoutNotifications', 'groupInvitations',
      'transactionConfirmations', 'weeklySummaries', 'marketingEmails',
      'lowBalanceWarnings', 'systemUpdates'
    ];

    const sanitizedPrefs = {};
    for (const key of validKeys) {
      if (preferences[key] !== undefined) {
        sanitizedPrefs[key] = preferences[key];
      }
    }

    await db.ref(`user_email_preferences/${targetUserId}`).set({
      ...sanitizedPrefs,
      updatedAt: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
    });

    console.log('Email preferences updated for user:', targetUserId);
    return { success: true };
  } catch (error) {
    console.error('Failed to update email preferences:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update email preferences');
  }
});

exports.getUserEmailHistory = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.userId ? String(data.userId) : '').trim();
  const limit = Math.max(1, Math.min(100, Number((data && data.limit) || 50)));

  if (!targetUserId) {
    throw new functions.https.HttpsError('invalid-argument', 'userId required.');
  }

  // Users can only get their own history, admins can get any user's
  const db = admin.database();
  const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
  const isSuperAdmin = (await db.ref(`superadmins/${callerUid}`).get()).exists();

  if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Can only access your own email history.');
  }

  try {
    const historySnapshot = await db.ref('email_notifications')
      .orderByChild('userId')
      .equalTo(targetUserId)
      .limitToLast(limit)
      .get();

    const emails = [];
    if (historySnapshot.exists()) {
      const rawData = historySnapshot.val();
      for (const [id, emailData] of Object.entries(rawData)) {
        emails.push({ id, ...emailData });
      }
      emails.sort((a, b) => new Date(b.sentAt) - new Date(a.sentAt));
    }

    return { success: true, emails };
  } catch (error) {
    console.error('Failed to get email history:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get email history');
  }
});

// Helper function to send contribution reminders for a group
async function sendGroupContributionReminders(db, groupId, groupData) {
  if (!groupData.members || !Array.isArray(groupData.members)) return;

  for (const memberId of groupData.members) {
    try {
      // Get user data
      const userSnapshot = await db.ref(`users/${memberId}`).get();
      if (!userSnapshot.exists()) continue;

      const userData = userSnapshot.val();
      if (!userData.email) continue;

      // Check email preferences
      const prefsSnapshot = await db.ref(`user_email_preferences/${memberId}`).get();
      const prefs = prefsSnapshot.exists() ? prefsSnapshot.val() : {};
      const reminderPref = prefs.contributionReminders || 'immediate';

      if (reminderPref === 'never') continue;

      // Get user's contribution status (simplified)
      const contributionAmount = groupData.contributionAmount || 0;
      const nextPayoutDate = groupData.nextPayoutDate;

      await emailService.sendContributionReminder(
        userData.email,
        userData.name || 'User',
        groupData.name || 'Savings Group',
        contributionAmount,
        new Date(nextPayoutDate).toLocaleDateString()
      );

      console.log('Contribution reminder sent to:', userData.email);
    } catch (error) {
      console.error('Failed to send contribution reminder to member:', memberId, error);
    }
  }
}

// --- Advanced Admin Functions ---

exports.getAdminDashboardStats = getAdminDashboardStats;
exports.getAdminAuditLogs = getAdminAuditLogs;
exports.logAdminAction = logAdminAction;
exports.performSystemMaintenance = performSystemMaintenance;
exports.generateComplianceReport = generateComplianceReport;

// --- Groups management (admin) ---

exports.adminListGroups = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(500, Number((data && data.limit) || 200)));

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref('groups').limitToFirst(limit).get();
  const raw = snap.val() || {};
  const items = Object.keys(raw).map((id) => {
    const g = raw[id] || {};
    const members = Array.isArray(g.members) ? g.members : [];
    return {
      id: g.id || id,
      name: g.name || '',
      contributionAmount: Number(g.contributionAmount || 0),
      frequencyDays: Number(g.frequencyDays || 0),
      payoutStrategy: g.payoutStrategy || 'fixedOrder',
      membersCount: members.length,
      bannerUrl: g.bannerUrl || null,
    };
  });
  items.sort((a, b) => String(a.name).localeCompare(String(b.name)));
  return { ok: true, items };
});

exports.adminGetGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : '').trim();
  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref(`groups/${groupId}`).get();
  if (!snap.exists()) throw new functions.https.HttpsError('not-found', 'Group not found.');
  return { ok: true, group: snap.val() };
});

exports.adminUpdateGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : '').trim();
  const patch = data && data.patch;
  if (!groupId || !isPlainObject(patch)) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and patch required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const ref = db.ref(`groups/${groupId}`);
  const result = await ref.transaction((current) => {
    if (!current || typeof current !== 'object') return;

    if (patch.name != null) current.name = String(patch.name);
    if (patch.bannerUrl !== undefined) current.bannerUrl = patch.bannerUrl ? String(patch.bannerUrl) : null;
    if (patch.contributionAmount != null) current.contributionAmount = Number(patch.contributionAmount);

    if (patch.frequencyDays != null) {
      const days = Number(patch.frequencyDays);
      current.frequencyDays = days;
      if (!current.scheduleConfig || typeof current.scheduleConfig !== 'object') current.scheduleConfig = {};
      current.scheduleConfig.cycleLengthDays = days;
      current.scheduleConfig.cycle = inferCycle(days);
    }

    if (patch.payoutStrategy != null) {
      const strategy = String(patch.payoutStrategy);
      current.payoutStrategy = strategy;
      if (!current.scheduleConfig || typeof current.scheduleConfig !== 'object') current.scheduleConfig = {};
      current.scheduleConfig.strategy = strategy;
    }

    current.updatedAtMs = admin.database.ServerValue.TIMESTAMP;
    current.updatedBy = callerUid;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError('aborted', 'Group update could not be committed.');
  }

  return { ok: true };
});

exports.adminAddGroupMember = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : '').trim();
  const memberId = (data && data.memberId ? String(data.memberId) : '').trim();
  if (!groupId || !memberId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and memberId required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const ref = db.ref(`groups/${groupId}`);
  const result = await ref.transaction((current) => {
    if (!current || typeof current !== 'object') return;

    const members = Array.isArray(current.members) ? current.members.slice() : [];
    if (!members.includes(memberId)) members.push(memberId);
    current.members = members;

    if (!current.scheduleConfig || typeof current.scheduleConfig !== 'object') current.scheduleConfig = {};
    current.scheduleConfig.preferredOrder = members;

    if (!current.rotationState || typeof current.rotationState !== 'object') current.rotationState = {};
    const payoutQueue = Array.isArray(current.rotationState.payoutQueue)
      ? current.rotationState.payoutQueue.slice()
      : [];
    if (!payoutQueue.includes(memberId)) payoutQueue.push(memberId);
    current.rotationState.payoutQueue = payoutQueue;

    const progress = isPlainObject(current.rotationState.contributionProgress)
      ? { ...current.rotationState.contributionProgress }
      : {};
    if (progress[memberId] == null) progress[memberId] = 0.0;
    current.rotationState.contributionProgress = progress;

    current.updatedAtMs = admin.database.ServerValue.TIMESTAMP;
    current.updatedBy = callerUid;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError('aborted', 'Member add could not be committed.');
  }
  return { ok: true };
});

exports.adminRemoveGroupMember = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : '').trim();
  const memberId = (data && data.memberId ? String(data.memberId) : '').trim();
  if (!groupId || !memberId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId and memberId required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const ref = db.ref(`groups/${groupId}`);
  const result = await ref.transaction((current) => {
    if (!current || typeof current !== 'object') return;

    const members = Array.isArray(current.members) ? current.members.slice() : [];
    current.members = members.filter((m) => String(m) !== memberId);

    if (current.scheduleConfig && typeof current.scheduleConfig === 'object') {
      if (Array.isArray(current.scheduleConfig.preferredOrder)) {
        current.scheduleConfig.preferredOrder = current.scheduleConfig.preferredOrder
          .filter((m) => String(m) !== memberId);
      }
      if (isPlainObject(current.scheduleConfig.adminAssignments)) {
        const assignments = { ...current.scheduleConfig.adminAssignments };
        for (const k of Object.keys(assignments)) {
          if (String(assignments[k]) === memberId) delete assignments[k];
        }
        current.scheduleConfig.adminAssignments = assignments;
      }
    }

    if (current.rotationState && typeof current.rotationState === 'object') {
      if (Array.isArray(current.rotationState.payoutQueue)) {
        current.rotationState.payoutQueue = current.rotationState.payoutQueue
          .filter((m) => String(m) !== memberId);
      }
      if (isPlainObject(current.rotationState.contributionProgress)) {
        const progress = { ...current.rotationState.contributionProgress };
        delete progress[memberId];
        current.rotationState.contributionProgress = progress;
      }
    }

    current.updatedAtMs = admin.database.ServerValue.TIMESTAMP;
    current.updatedBy = callerUid;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError('aborted', 'Member removal could not be committed.');
  }
  return { ok: true };
});

exports.adminDeleteGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : '').trim();
  if (!groupId) {
    throw new functions.https.HttpsError('invalid-argument', 'groupId required.');
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  await db.ref(`groups/${groupId}`).remove();
  return { ok: true };
});

// --- Mobile Money Webhooks ---

exports.telebirrWebhook = telebirrWebhook;
exports.cbeBirrWebhook = cbeBirrWebhook;
exports.checkMobileMoneyTransaction = checkMobileMoneyTransaction;
exports.processPendingMobileMoneyTransactions = processPendingMobileMoneyTransactions;

// --- Push Notifications ---

exports.schedulePushNotification = schedulePushNotification;
exports.sendImmediateNotification = sendImmediateNotification;
exports.cancelScheduledNotifications = cancelScheduledNotifications;
exports.sendScheduledNotifications = sendScheduledNotifications;
exports.scheduleContributionReminders = scheduleContributionReminders;
exports.schedulePayoutNotifications = schedulePayoutNotifications;
