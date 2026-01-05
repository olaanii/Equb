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
