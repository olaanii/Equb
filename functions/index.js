const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch (_) {
    return null;
  }
}

function redactSensitive(value) {
  const SENSITIVE_KEYS = new Set([
    "apiKey",
    "apikey",
    "depositKey",
    "secret",
    "token",
    "authorization",
    "password",
  ]);

  if (Array.isArray(value)) {
    return value.map(redactSensitive);
  }
  if (!value || typeof value !== "object") {
    return value;
  }

  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SENSITIVE_KEYS.has(String(k))) {
      out[k] = "[REDACTED]";
    } else {
      out[k] = redactSensitive(v);
    }
  }
  return out;
}

function assertAuthed(context) {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Sign in required."
    );
  }
  return context.auth.uid;
}

function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

function inferCycle(days) {
  const d = Number(days || 30);
  if (d === 1) return "daily";
  if (d === 7) return "weekly";
  if (d === 14) return "biWeekly";
  if ([28, 29, 30, 31].includes(d)) return "monthly";
  return "custom";
}

async function assertAdminUid(db, callerUid) {
  const adminSnap = await db.ref(`admins/${callerUid}`).get();
  if (adminSnap.exists() && adminSnap.val() === true) return;
  throw new functions.https.HttpsError(
    "permission-denied",
    "Admin privileges required."
  );
}

async function assertSuperAdminUid(db, callerUid) {
  const snap = await db.ref(`superadmins/${callerUid}`).get();
  if (snap.exists() && snap.val() === true) return;
  throw new functions.https.HttpsError(
    "permission-denied",
    "Super admin privileges required."
  );
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function emailKey(email) {
  const normalized = normalizeEmail(email);
  if (!normalized) return "";
  // RTDB keys cannot contain '.', '#', '$', '[', ']', or '/'.
  // Use base64url to ensure a safe key.
  return Buffer.from(normalized, "utf8").toString("base64url");
}

function generateApiKey() {
  // Human-recognizable prefix + enough entropy.
  return `eqb_${crypto.randomBytes(24).toString("base64url")}`;
}

function hashApiKey(apiKey) {
  return crypto.createHash("sha256").update(String(apiKey)).digest("hex");
}

function sanitizeScopes(scopes) {
  if (!Array.isArray(scopes)) return [];
  return scopes
    .map((s) => String(s || "").trim())
    .filter((s) => s.length > 0)
    .slice(0, 25);
}

exports.bootstrapAdmin = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const setupCode = (
    data && data.setupCode ? String(data.setupCode) : ""
  ).trim();

  // Prefer Firebase Functions config: firebase functions:config:set app.admin_setup_code="..."
  const expected =
    functions.config().app && functions.config().app.admin_setup_code
      ? String(functions.config().app.admin_setup_code).trim()
      : "";

  if (!expected) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Admin bootstrap is not configured. Set functions config app.admin_setup_code."
    );
  }

  if (!setupCode || setupCode !== expected) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Invalid setup code."
    );
  }

  const db = admin.database();
  const updates = {};
  updates[`admins/${callerUid}`] = true;

  await db.ref().update(updates);
  return { ok: true, uid: callerUid, admin: true };
});

// --- User email sync/index (server-managed) ---

exports.onAuthUserCreateSyncEmail = functions.auth.user().onCreate(async (user) => {
  const uid = user && user.uid ? String(user.uid) : "";
  if (!uid) return null;

  const email = normalizeEmail(user.email || "");
  if (!email) return null;

  const db = admin.database();
  const now = admin.database.ServerValue.TIMESTAMP;

  const updates = {};
  updates[`users/${uid}/email`] = email;
  updates[`users/${uid}/emailNormalized`] = email;

  const key = emailKey(email);
  if (key) {
    updates[`admin_config/user_email_index/${key}`] = {
      uid,
      email,
      updatedAtMs: now,
      source: "auth.onCreate",
    };
  }

  await db.ref().update(updates);
  return { ok: true };
});

exports.adminReviewDeposit = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);

  const targetUserId = (
    data && data.targetUserId ? String(data.targetUserId) : ""
  ).trim();
  const txId = (data && data.txId ? String(data.txId) : "").trim();
  const action = (data && data.action ? String(data.action) : "").trim();
  const reason = (data && data.reason ? String(data.reason) : "").trim();

  if (!targetUserId || !txId || (action !== "approve" && action !== "reject")) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "targetUserId, txId, action required."
    );
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const userRef = db.ref(`users/${targetUserId}`);
  const txRef = userRef.child(`transactions/${txId}`);
  const queueId = `${targetUserId}_${txId}`;
  const queueRef = db.ref(`review_queue/deposits/${queueId}`);

  const txSnap = await txRef.get();
  if (!txSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "Transaction not found.");
  }

  const tx = txSnap.val() || {};
  const status = (tx.status || "").toString();
  const toUserId = (tx.toUserId || "").toString();
  const requiresReview = tx.requiresReview === true;

  if (toUserId !== "wallet" || !requiresReview) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Transaction is not a reviewable deposit."
    );
  }

  // Idempotent handling
  if (action === "approve" && status === "success")
    return { ok: true, already: true, status: "success" };
  if (action === "reject" && status === "failed")
    return { ok: true, already: true, status: "failed" };
  if (status !== "pending") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      `Transaction status is ${status}.`
    );
  }

  const amount = Number(tx.amount || 0);
  const net = Number(tx.netAmount || amount);
  const fee = Number(tx.feeAmount || 0);

  // Points for deposits are based on amount.
  const points = Math.max(0, Math.floor(amount / 10));

  const nowMs = admin.database.ServerValue.TIMESTAMP;
  const notificationId = userRef.child("notifications").push().key;
  const ledgerId = userRef.child("points_ledger").push().key;

  const result = await userRef.transaction((current) => {
    if (!current || typeof current !== "object") return;

    const walletBalance = Number(current.walletBalance || 0);
    const currentPoints = Number(current.points || 0);

    const transactions =
      current.transactions && typeof current.transactions === "object"
        ? current.transactions
        : {};

    const existing = transactions[txId];
    if (!existing || typeof existing !== "object") return;

    if ((existing.status || "").toString() !== "pending") {
      return current; // idempotent
    }

    if (action === "approve") {
      current.walletBalance = walletBalance + net;
      current.points = currentPoints + points;

      existing.status = "success";
      existing.approvedAtMs = nowMs;
      existing.approvedBy = callerUid;
      existing.verificationStatus = "success";

      if (ledgerId && points > 0) {
        const ledger =
          current.points_ledger && typeof current.points_ledger === "object"
            ? current.points_ledger
            : {};
        ledger[ledgerId] = {
          delta: points,
          action: "deposit_approved",
          createdAtMs: nowMs,
          relatedTransactionId: txId,
          metadata: { amount, fee, net },
        };
        current.points_ledger = ledger;
      }

      if (notificationId) {
        const notifications =
          current.notifications && typeof current.notifications === "object"
            ? current.notifications
            : {};
        notifications[notificationId] = {
          id: notificationId,
          userId: targetUserId,
          title: "Deposit approved",
          body: `Your deposit of ETB ${amount.toFixed(2)} has been approved.`,
          type: "success",
          isRead: false,
          createdAt: new Date().toISOString(),
          createdAtMs: nowMs,
          metadata: { transactionId: txId },
        };
        current.notifications = notifications;
      }
    } else {
      existing.status = "failed";
      existing.rejectedAtMs = nowMs;
      existing.rejectedBy = callerUid;
      existing.verificationStatus = "failed";
      if (reason) existing.rejectionReason = reason;

      if (notificationId) {
        const notifications =
          current.notifications && typeof current.notifications === "object"
            ? current.notifications
            : {};
        notifications[notificationId] = {
          id: notificationId,
          userId: targetUserId,
          title: "Deposit rejected",
          body: `Your deposit of ETB ${amount.toFixed(2)} was rejected.`,
          type: "error",
          isRead: false,
          createdAt: new Date().toISOString(),
          createdAtMs: nowMs,
          metadata: { transactionId: txId, ...(reason ? { reason } : {}) },
        };
        current.notifications = notifications;
      }
    }

    transactions[txId] = existing;
    current.transactions = transactions;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError(
      "aborted",
      "Transaction could not be committed."
    );
  }

  // Best-effort remove from queue after decision.
  try {
    await queueRef.remove();
  } catch (_) {}

  return { ok: true, status: action === "approve" ? "success" : "failed" };
});

exports.adminListPendingDeposits = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const limit = Math.max(
      1,
      Math.min(200, Number((data && data.limit) || 50))
    );

    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const snap = await db
      .ref("review_queue/deposits")
      .orderByChild("createdAtMs")
      .limitToLast(limit)
      .get();
    const raw = snap.val() || {};
    const items = Object.keys(raw)
      .map((k) => raw[k])
      .filter(Boolean);
    items.sort(
      (a, b) => Number(b.createdAtMs || 0) - Number(a.createdAtMs || 0)
    );
    return { ok: true, items };
  }
);

exports.adminListUsers = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(500, Number((data && data.limit) || 200)));

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref("users").limitToFirst(limit).get();
  const users = snap.val() || {};
  const items = Object.keys(users).map((uid) => {
    const u = users[uid] || {};
    return {
      id: uid,
      name: u.name || "",
      email: u.email || null,
      phone: u.phone || null,
      role: u.role || "user",
      walletBalance: Number(u.walletBalance || 0),
      points: Number(u.points || 0),
      isVerified: !!u.isVerified,
    };
  });

  return { ok: true, items };
});

exports.adminSetUserRole = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (
    data && data.targetUserId ? String(data.targetUserId) : ""
  ).trim();
  const role = (data && data.role ? String(data.role) : "").trim();

  if (!targetUserId || !role) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "targetUserId and role required."
    );
  }

  const allowed = new Set(["user", "equbAdmin", "superAdmin"]);
  if (!allowed.has(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Invalid role.");
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  await db.ref(`users/${targetUserId}/role`).set(role);
  await db
    .ref(`users/${targetUserId}/roleUpdatedAtMs`)
    .set(admin.database.ServerValue.TIMESTAMP);
  await db.ref(`users/${targetUserId}/roleUpdatedBy`).set(callerUid);

  return { ok: true, targetUserId, role };
});

exports.adminSendUserNotification = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const targetUserId = (
      data && data.targetUserId ? String(data.targetUserId) : ""
    ).trim();
    const title = (data && data.title ? String(data.title) : "").trim();
    const body = (data && data.body ? String(data.body) : "").trim();
    const type = (data && data.type ? String(data.type) : "info").trim();
    const metadata =
      data && data.metadata && typeof data.metadata === "object"
        ? data.metadata
        : {};

    if (!targetUserId || !title || !body) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUserId, title, body required."
      );
    }

    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const userRef = db.ref(`users/${targetUserId}`);
    const notificationId = userRef.child("notifications").push().key;
    if (!notificationId) {
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create notification id."
      );
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
  }
);

exports.adminGetUserAudit = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (
    data && data.targetUserId ? String(data.targetUserId) : ""
  ).trim();
  const limit = Math.max(1, Math.min(100, Number((data && data.limit) || 25)));

  if (!targetUserId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "targetUserId required."
    );
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const userSnap = await db.ref(`users/${targetUserId}`).get();
  if (!userSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "User not found.");
  }
  const u = userSnap.val() || {};

  const txSnap = await db
    .ref(`users/${targetUserId}/transactions`)
    .orderByChild("timestampMs")
    .limitToLast(limit)
    .get();
  const ledgerSnap = await db
    .ref(`users/${targetUserId}/points_ledger`)
    .orderByChild("createdAtMs")
    .limitToLast(limit)
    .get();

  const txRaw = txSnap.val() || {};
  const ledgerRaw = ledgerSnap.val() || {};
  const transactions = Object.keys(txRaw)
    .map((k) => txRaw[k])
    .filter(Boolean)
    .sort((a, b) => Number(b.timestampMs || 0) - Number(a.timestampMs || 0));
  const pointsLedger = Object.keys(ledgerRaw)
    .map((k) => ledgerRaw[k])
    .filter(Boolean)
    .sort((a, b) => Number(b.createdAtMs || 0) - Number(a.createdAtMs || 0));

  return {
    ok: true,
    user: {
      id: targetUserId,
      name: u.name || "",
      email: u.email || null,
      phone: u.phone || null,
      role: u.role || "user",
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

  const snap = await db.ref("admin_config/feature_flags").get();
  const raw = snap.val();
  const value = isPlainObject(raw) ? raw : {};
  const gatewayFlags = isPlainObject(value.gatewayFlags)
    ? value.gatewayFlags
    : {};

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
    throw new functions.https.HttpsError(
      "invalid-argument",
      "flags object required."
    );
  }

  const gatewayFlags = isPlainObject(flags.gatewayFlags)
    ? flags.gatewayFlags
    : {};
  await db.ref("admin_config/feature_flags").set({
    gemini25ProEnabled: !!flags.gemini25ProEnabled,
    gatewayFlags,
    updatedAtMs: admin.database.ServerValue.TIMESTAMP,
    updatedBy: callerUid,
  });

  return { ok: true };
});

exports.adminListGatewayOverrides = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const snap = await db.ref("admin_config/gateway_overrides").get();
    return { ok: true, items: snap.val() || {} };
  }
);

exports.adminSetGatewayOverride = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const gatewayId = (
      data && data.gatewayId ? String(data.gatewayId) : ""
    ).trim();
    const override = data && data.override;
    if (!gatewayId || !isPlainObject(override)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "gatewayId and override required."
      );
    }

    const meta = isPlainObject(override.meta) ? override.meta : {};
    const environment =
      (override.environment ? String(override.environment) : "").trim() ||
      "mock";

    await db.ref(`admin_config/gateway_overrides/${gatewayId}`).set({
      id: gatewayId,
      enabled: !!override.enabled,
      environment,
      meta,
      updatedAtMs: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
    });

    return { ok: true };
  }
);

exports.adminSetGatewaySecret = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const gatewayId = (
      data && data.gatewayId ? String(data.gatewayId) : ""
    ).trim();
    const secrets = data && data.secrets;
    if (!gatewayId || !isPlainObject(secrets)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "gatewayId and secrets object required."
      );
    }

    // Note: RTDB is not ideal for secrets. Prefer Secret Manager/KMS in production.
    await db.ref(`admin_config/gateway_secrets/${gatewayId}`).set({
      secrets,
      updatedAtMs: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
    });

    return { ok: true };
  }
);

exports.adminGetGatewaySecretMetadata = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const gatewayId = (
      data && data.gatewayId ? String(data.gatewayId) : ""
    ).trim();
    if (!gatewayId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "gatewayId required."
      );
    }

    const snap = await db
      .ref(`admin_config/gateway_secrets/${gatewayId}`)
      .get();
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
  }
);

// --- Super Admin (highest privilege) ---

exports.superAdminSetAdmin = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUid = (
    data && data.targetUid ? String(data.targetUid) : ""
  ).trim();
  const isAdmin = !!(data && data.isAdmin);

  if (!targetUid) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "targetUid required."
    );
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

exports.superAdminSetSuperAdmin = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const targetUid = (
      data && data.targetUid ? String(data.targetUid) : ""
    ).trim();
    const isSuperAdmin = !!(data && data.isSuperAdmin);

    if (!targetUid) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "targetUid required."
      );
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
  }
);

// --- Super Admin API Keys (external API access) ---

exports.superAdminCreateApiKey = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const label = (data && data.label ? String(data.label) : "").trim();
  const principalEmail = normalizeEmail((data && data.principalEmail) || "");
  const scopes = sanitizeScopes(data && data.scopes);

  if (!label) {
    throw new functions.https.HttpsError("invalid-argument", "label required.");
  }

  const keyId = db.ref("admin_config/api_keys").push().key;
  if (!keyId) {
    throw new functions.https.HttpsError("internal", "Failed to allocate key id.");
  }

  const apiKey = generateApiKey();
  const record = {
    id: keyId,
    label,
    enabled: true,
    scopes,
    principalEmail: principalEmail || null,
    keyPrefix: apiKey.slice(0, 8),
    keyHash: hashApiKey(apiKey),
    createdAtMs: admin.database.ServerValue.TIMESTAMP,
    createdBy: callerUid,
    revokedAtMs: null,
    revokedBy: null,
    lastUsedAtMs: null,
  };

  await db.ref(`admin_config/api_keys/${keyId}`).set(record);

  // NOTE: apiKey is only returned once. Store it securely client-side.
  return {
    ok: true,
    id: keyId,
    apiKey,
    keyPrefix: record.keyPrefix,
    label,
    enabled: true,
    scopes,
    principalEmail: record.principalEmail,
  };
});

exports.superAdminListApiKeys = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(1, Math.min(1000, Number((data && data.limit) || 200)));

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const snap = await db.ref("admin_config/api_keys").limitToFirst(limit).get();
  const raw = snap.val() || {};

  const items = Object.entries(raw)
    .map(([id, value]) => {
      const row = isPlainObject(value) ? value : {};
      return {
        id,
        label: row.label || id,
        enabled: !!row.enabled,
        scopes: Array.isArray(row.scopes) ? row.scopes : [],
        principalEmail: row.principalEmail || null,
        keyPrefix: row.keyPrefix || null,
        createdAtMs: row.createdAtMs || null,
        createdBy: row.createdBy || null,
        revokedAtMs: row.revokedAtMs || null,
        revokedBy: row.revokedBy || null,
        lastUsedAtMs: row.lastUsedAtMs || null,
      };
    })
    .sort((a, b) => String(a.label).localeCompare(String(b.label)));

  return { ok: true, items };
});

exports.superAdminRevokeApiKey = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const id = (data && data.id ? String(data.id) : "").trim();
  if (!id) {
    throw new functions.https.HttpsError("invalid-argument", "id required.");
  }

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const ref = db.ref(`admin_config/api_keys/${id}`);
  const snap = await ref.get();
  if (!snap.exists()) {
    throw new functions.https.HttpsError("not-found", "API key not found.");
  }

  await ref.update({
    enabled: false,
    revokedAtMs: admin.database.ServerValue.TIMESTAMP,
    revokedBy: callerUid,
  });

  return { ok: true, id, enabled: false };
});

exports.superAdminListAdmins = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const limit = Math.max(
    1,
    Math.min(1000, Number((data && data.limit) || 500))
  );

  const db = admin.database();
  await assertSuperAdminUid(db, callerUid);

  const [adminsSnap, superSnap] = await Promise.all([
    db.ref("admins").limitToFirst(limit).get(),
    db.ref("superadmins").limitToFirst(limit).get(),
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

exports.superAdminSetFeatureFlags = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertSuperAdminUid(db, callerUid);

    const flags = data && data.flags;
    if (!isPlainObject(flags)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "flags object required."
      );
    }

    const gatewayFlags = isPlainObject(flags.gatewayFlags)
      ? flags.gatewayFlags
      : {};
    await db.ref("admin_config/feature_flags").set({
      gemini25ProEnabled: !!flags.gemini25ProEnabled,
      gatewayFlags,
      updatedAtMs: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
      updatedByRole: "superAdmin",
    });

    return { ok: true };
  }
);

exports.superAdminSetGatewaySecret = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertSuperAdminUid(db, callerUid);

    const gatewayId = (
      data && data.gatewayId ? String(data.gatewayId) : ""
    ).trim();
    const secrets = data && data.secrets;
    if (!gatewayId || !isPlainObject(secrets)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "gatewayId and secrets object required."
      );
    }

    await db.ref(`admin_config/gateway_secrets/${gatewayId}`).set({
      secrets,
      updatedAtMs: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
      updatedByRole: "superAdmin",
    });

    return { ok: true };
  }
);

// --- Chapa (web CORS-safe initialize) ---

exports.chapaInitializePayment = functions.https.onCall(
  async (data, context) => {
    // Any authenticated user can initiate a checkout; the secret is kept server-side.
    assertAuthed(context);

    const amount = Number(data && data.amount);
    const currency =
      (data && data.currency ? String(data.currency) : "ETB").trim() || "ETB";
    const txRef = (data && data.txRef ? String(data.txRef) : "").trim();
    const returnUrl = (data && data.returnUrl ? String(data.returnUrl) : "").trim();
    const callbackUrl = (
      data && data.callbackUrl ? String(data.callbackUrl) : ""
    ).trim();
    const email = (data && data.email ? String(data.email) : "").trim();
    const firstName = (
      data && data.firstName ? String(data.firstName) : ""
    ).trim();
    const lastName = (
      data && data.lastName ? String(data.lastName) : ""
    ).trim();
    const phoneNumber = (
      data && data.phoneNumber ? String(data.phoneNumber) : ""
    ).trim();

    if (!Number.isFinite(amount) || amount <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "amount must be > 0"
      );
    }
    if (!txRef) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "txRef required"
      );
    }
    if (!email) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "email required"
      );
    }
    if (!returnUrl || !/^https?:\/\//i.test(returnUrl)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "returnUrl must be a valid http(s) URL"
      );
    }
    if (callbackUrl && !/^https?:\/\//i.test(callbackUrl)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "callbackUrl must be a valid http(s) URL"
      );
    }

    const isEmulator =
      String(process.env.FUNCTIONS_EMULATOR || "").toLowerCase() === "true";

    // IMPORTANT:
    // When running the Functions emulator without the RTDB emulator, any call to
    // admin.database() will hit production. To keep local dev safe, never read
    // gateway secrets from RTDB in emulator mode.
    let secretKey = "";
    if (isEmulator) {
      secretKey = ((data && data.secretKey) || "").toString().trim();
      if (!secretKey) {
        secretKey = String(process.env.CHAPA_SECRET_KEY || "").trim();
      }
    } else {
      const db = admin.database();
      const secretSnap = await db
        .ref("admin_config/gateway_secrets/chapa/secrets")
        .get();
      const secrets = secretSnap.exists() ? secretSnap.val() || {} : {};
      secretKey = (secrets.secretKey || secrets.chapaSecretKey || "")
        .toString()
        .trim();
    }

    if (!secretKey) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        isEmulator
          ? "Chapa secretKey not provided for emulator. Pass secretKey from the client (dev-only) or set CHAPA_SECRET_KEY env var."
          : "Chapa secretKey not configured. Set admin_config/gateway_secrets/chapa/secrets.secretKey."
      );
    }

    const endpoint = "https://api.chapa.co/v1/transaction/initialize";

    async function postInitialize(requestBody) {
      const startedAtMs = Date.now();
      const controller = new AbortController();
      const timeoutMs = 45000;
      const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const resp = await fetch(endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${secretKey}`,
          },
          body: JSON.stringify(requestBody),
          signal: controller.signal,
        });
        const text = await resp.text();
        return { resp, text, elapsedMs: Date.now() - startedAtMs, timeoutMs };
      } catch (e) {
        const isAbort = e && typeof e === "object" && e.name === "AbortError";
        if (isAbort) {
          const elapsedMs = Date.now() - startedAtMs;
          throw new functions.https.HttpsError(
            "deadline-exceeded",
            `Chapa request timed out after ${timeoutMs}ms`,
            { timeoutMs, elapsedMs, endpoint }
          );
        }
        throw new functions.https.HttpsError(
          "internal",
          "Chapa request failed",
          { endpoint, cause: String(e) }
        );
      } finally {
        clearTimeout(timeoutId);
      }
    }

    const requestBody = {
      amount: amount.toFixed(2),
      currency,
      email,
      first_name: firstName || context.auth.uid,
      last_name: lastName || "",
      tx_ref: txRef,
      return_url: returnUrl,
      ...(callbackUrl ? { callback_url: callbackUrl } : {}),
      ...(phoneNumber ? { phone_number: phoneNumber } : {}),
    };

    const { resp, text, elapsedMs } = await postInitialize(requestBody);

    if (resp.ok) {
      const decoded = safeJsonParse(text);
      const checkoutUrl =
        decoded &&
        typeof decoded === "object" &&
        decoded.data &&
        typeof decoded.data === "object" &&
        decoded.data.checkout_url
          ? String(decoded.data.checkout_url).trim()
          : "";

      if (!checkoutUrl) {
        throw new functions.https.HttpsError(
          "internal",
          "Chapa response missing checkout_url",
          { endpoint }
        );
      }

      return { ok: true, checkoutUrl };
    }

    const upstream = safeJsonParse(text);
    const upstreamMessage =
      upstream && typeof upstream === "object" && upstream.message
        ? String(upstream.message)
        : "";

    console.error("Chapa initialize failed", {
      endpoint,
      status: resp.status,
      elapsedMs,
      upstreamMessage,
      request: redactSensitive(requestBody),
      upstream: upstream ? redactSensitive(upstream) : undefined,
      rawBodyBytes: text ? Buffer.byteLength(text, "utf8") : 0,
    });

    let code = "internal";
    if (resp.status === 400 || resp.status === 422) code = "invalid-argument";
    if (resp.status === 401 || resp.status === 403) code = "failed-precondition";
    if (resp.status === 404) code = "not-found";
    if (resp.status === 429) code = "resource-exhausted";
    if (resp.status >= 500) code = "unavailable";

    const safeMessage = upstreamMessage && upstreamMessage.trim().length
      ? upstreamMessage.trim()
      : "Chapa initialize failed";

    throw new functions.https.HttpsError(code, safeMessage, {
      endpoint,
      status: resp.status,
    });
  }
);

// --- Superadmin: Chapa test users fixtures ---

exports.superAdminListChapaTestUsers = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertSuperAdminUid(db, callerUid);

    const snap = await db.ref('admin_config/test_data/chapa_users').get();
    const raw = snap.exists() ? snap.val() : null;
    const users = [];

    if (raw && typeof raw === 'object') {
      for (const [id, v] of Object.entries(raw)) {
        if (!v || typeof v !== 'object') continue;
        users.push({
          id: String(id),
          label: v.label ? String(v.label) : '',
          email: v.email ? String(v.email) : '',
          phone: v.phone ? String(v.phone) : '',
          updatedAtMs: v.updatedAtMs || null,
        });
      }
    }

    users.sort((a, b) => String(a.label || a.email).localeCompare(String(b.label || b.email)));
    return { ok: true, users };
  }
);

exports.superAdminUpsertChapaTestUser = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertSuperAdminUid(db, callerUid);

    const id = (data && data.id ? String(data.id) : '').trim();
    const label = (data && data.label ? String(data.label) : '').trim();
    const email = (data && data.email ? String(data.email) : '').trim();
    const phone = (data && data.phone ? String(data.phone) : '').trim();

    if (!id || !label || !email || !phone) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'id, label, email, phone required.'
      );
    }

    await db.ref(`admin_config/test_data/chapa_users/${id}`).set({
      label,
      email,
      phone,
      updatedAtMs: admin.database.ServerValue.TIMESTAMP,
      updatedBy: callerUid,
    });

    return { ok: true };
  }
);

exports.superAdminDeleteChapaTestUser = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const db = admin.database();
    await assertSuperAdminUid(db, callerUid);

    const id = (data && data.id ? String(data.id) : '').trim();
    if (!id) {
      throw new functions.https.HttpsError('invalid-argument', 'id required.');
    }

    await db.ref(`admin_config/test_data/chapa_users/${id}`).remove();
    return { ok: true };
  }
);

function parseChapaTxRef(txRef) {
  const raw = String(txRef || "").trim();
  // Format generated by the Flutter app: chapa~<uid>~<ms>
  const parts = raw.split("~");
  if (parts.length >= 3 && parts[0] === "chapa") {
    const userId = String(parts[1] || "").trim();
    return { userId, txRef: raw };
  }
  return { userId: "", txRef: raw };
}

function calculateFee(amount) {
  const a = Number(amount || 0);
  const rate = a >= 10000 ? 0.005 : 0.001;
  let fee = a * rate;
  if (a >= 1000000) fee = fee * 0.1;
  return fee;
}

function calculatePoints(amount) {
  const a = Number(amount || 0);
  let points = Math.floor(a / 100);
  if (a >= 10000) points += 50;
  if (a >= 100000) points += 500;
  return Math.max(0, points);
}

async function getChapaSecretKey({ isEmulator, clientSecretKey }) {
  if (isEmulator) {
    const fromClient = String(clientSecretKey || "").trim();
    if (fromClient) return fromClient;
    return String(process.env.CHAPA_SECRET_KEY || "").trim();
  }

  const db = admin.database();
  const secretSnap = await db
    .ref("admin_config/gateway_secrets/chapa/secrets")
    .get();
  const secrets = secretSnap.exists() ? secretSnap.val() || {} : {};
  return String(secrets.secretKey || secrets.chapaSecretKey || "").trim();
}

async function verifyChapaTransaction(secretKey, txRef) {
  const endpoint = `https://api.chapa.co/v1/transaction/verify/${encodeURIComponent(
    String(txRef)
  )}`;
  const controller = new AbortController();
  const timeoutMs = 45000;
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const resp = await fetch(endpoint, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${secretKey}`,
      },
      signal: controller.signal,
    });
    const text = await resp.text();
    const decoded = safeJsonParse(text);
    return { resp, decoded, endpoint, rawTextBytes: text ? Buffer.byteLength(text, "utf8") : 0 };
  } finally {
    clearTimeout(timeoutId);
  }
}

function isChapaSuccess(decoded) {
  if (!decoded || typeof decoded !== "object") return false;
  const topStatus = decoded.status ? String(decoded.status).toLowerCase() : "";
  const dataStatus =
    decoded.data && typeof decoded.data === "object" && decoded.data.status
      ? String(decoded.data.status).toLowerCase()
      : "";
  return topStatus === "success" || dataStatus === "success";
}

function getVerifiedAmount(decoded) {
  if (!decoded || typeof decoded !== "object") return null;
  const candidate =
    decoded.data && typeof decoded.data === "object" ? decoded.data.amount : null;
  const n = Number(candidate);
  return Number.isFinite(n) ? n : null;
}

async function finalizeChapaTx({ txRef, verified, verifiedAmount }) {
  const parsed = parseChapaTxRef(txRef);
  const userId = parsed.userId;
  if (!userId) {
    console.warn("chapaFinalize: Unable to parse userId from txRef", { txRef });
    return { ok: false, reason: "bad-txref" };
  }

  const db = admin.database();
  const userRef = db.ref(`users/${userId}`);
  const txDbRef = userRef.child(`transactions/${txRef}`);
  const txSnap = await txDbRef.get();
  if (!txSnap.exists()) {
    console.warn("chapaFinalize: Transaction not found", { userId, txRef });
    return { ok: false, reason: "tx-not-found" };
  }

  const tx = txSnap.val() || {};
  const currentStatus = String(tx.status || "pending");
  if (currentStatus === "success" || currentStatus === "failed") {
    return { ok: true, already: true, status: currentStatus };
  }

  const toUserId = String(tx.toUserId || "");
  const amount = Number(tx.amount || 0);
  const effectiveAmount =
    Number.isFinite(verifiedAmount) && verifiedAmount > 0 ? verifiedAmount : amount;
  const fee = calculateFee(effectiveAmount);
  const net = effectiveAmount - fee;
  const points = calculatePoints(effectiveAmount);
  const nowMs = admin.database.ServerValue.TIMESTAMP;

  // Wallet top-up: credit wallet + points after verification.
  if (toUserId === "wallet") {
    const notificationId = userRef.child("notifications").push().key;
    const ledgerId = userRef.child("points_ledger").push().key;

    const result = await userRef.transaction((current) => {
      if (!current || typeof current !== "object") return;

      const transactions =
        current.transactions && typeof current.transactions === "object"
          ? current.transactions
          : {};
      const existing = transactions[txRef];
      if (!existing || typeof existing !== "object") return;
      if (String(existing.status || "pending") !== "pending") return current;

      if (verified) {
        current.walletBalance = Number(current.walletBalance || 0) + net;
        current.points = Number(current.points || 0) + points;

        existing.status = "success";
        existing.verificationStatus = "success";
        existing.verifiedAtMs = nowMs;
        existing.feeAmount = fee;
        existing.netAmount = net;
      } else {
        existing.status = "failed";
        existing.verificationStatus = "failed";
        existing.verifiedAtMs = nowMs;
      }

      transactions[txRef] = existing;
      current.transactions = transactions;

      if (verified && ledgerId && points > 0) {
        const ledger =
          current.points_ledger && typeof current.points_ledger === "object"
            ? current.points_ledger
            : {};
        ledger[ledgerId] = {
          delta: points,
          action: "deposit",
          createdAtMs: nowMs,
          relatedTransactionId: txRef,
          metadata: { amount: effectiveAmount, fee, net, gateway: "chapa" },
        };
        current.points_ledger = ledger;
      }

      if (notificationId) {
        const notifications =
          current.notifications && typeof current.notifications === "object"
            ? current.notifications
            : {};
        notifications[notificationId] = {
          id: notificationId,
          userId,
          title: verified ? "Deposit successful" : "Deposit failed",
          body: verified
            ? `Your wallet was credited (ETB ${net.toFixed(2)}).`
            : "Your deposit could not be verified.",
          type: verified ? "success" : "error",
          isRead: false,
          createdAt: new Date().toISOString(),
          createdAtMs: nowMs,
          metadata: { transactionId: txRef },
        };
        current.notifications = notifications;
      }

      return current;
    });

    if (!result.committed) {
      console.warn("chapaFinalize: Wallet transaction not committed", { userId, txRef });
      return { ok: false, reason: "not-committed" };
    }

    return { ok: true, status: verified ? "success" : "failed" };
  }

  // Group payment: apply to group ledger + rotation only after verification.
  if (!toUserId) {
    await txDbRef.update({
      status: verified ? "success" : "failed",
      verificationStatus: verified ? "success" : "failed",
      verifiedAtMs: nowMs,
    });
    return { ok: true, status: verified ? "success" : "failed" };
  }

  if (!verified) {
    await txDbRef.update({
      status: "failed",
      verificationStatus: "failed",
      verifiedAtMs: nowMs,
    });
    return { ok: true, status: "failed" };
  }

  const groupId = toUserId;
  const groupRef = db.ref(`groups/${groupId}`);

  const groupResult = await groupRef.transaction((current) => {
    if (!current || typeof current !== "object") return;

    const members = Array.isArray(current.members) ? current.members.map(String) : [];
    const contributionAmount = Number(current.contributionAmount || 0);

    if (!current.rotationState || typeof current.rotationState !== "object") {
      current.rotationState = {};
    }
    const rotationState = current.rotationState;

    const progress = isPlainObject(rotationState.contributionProgress)
      ? { ...rotationState.contributionProgress }
      : {};
    progress[userId] = Number(progress[userId] || 0) + effectiveAmount;
    rotationState.contributionProgress = progress;

    const payoutQueue = Array.isArray(rotationState.payoutQueue)
      ? rotationState.payoutQueue.map(String)
      : members.slice();
    if (!payoutQueue.includes(userId) && members.includes(userId)) {
      payoutQueue.push(userId);
    }
    rotationState.payoutQueue = payoutQueue;

    const ledger = Array.isArray(current.ledger) ? current.ledger.slice() : [];

    ledger.push({
      id: txRef,
      fromUserId: userId,
      toUserId: groupId,
      amount: effectiveAmount,
      timestamp: new Date().toISOString(),
      status: "success",
      gateway: "chapa",
      feeAmount: fee,
      netAmount: net,
      verificationStatus: "success",
    });

    const schedule =
      current.scheduleConfig && typeof current.scheduleConfig === "object"
        ? current.scheduleConfig
        : {};
    const autoAssign = schedule.autoAssign === true;
    const cycleLengthDays = Number(schedule.cycleLengthDays || current.frequencyDays || 30);

    const thresholdMet =
      members.length > 0 &&
      members.every((m) => Number(progress[m] || 0) + 1e-8 >= contributionAmount);

    if (thresholdMet && autoAssign && members.length > 0) {
      const currentRound = Number(rotationState.currentRound || 0);
      const nextRound = currentRound + 1;
      rotationState.currentRound = nextRound;

      const recipient = payoutQueue.length ? payoutQueue[0] : members[0];
      const payoutAmount = contributionAmount * members.length;
      const processedAt = new Date().toISOString();
      const scheduledFor = rotationState.nextPayoutDate || processedAt;

      const history = Array.isArray(rotationState.history) ? rotationState.history.slice() : [];
      history.push({
        round: nextRound,
        memberId: recipient,
        amount: payoutAmount,
        scheduledFor,
        processedAt,
        autoAssigned: true,
        note: "Auto-assigned payout (server-verified contribution)",
      });
      rotationState.history = history;

      // Subtract one cycle worth of contributions.
      const adjusted = {};
      for (const m of members) {
        adjusted[m] = Math.max(Number(progress[m] || 0) - contributionAmount, 0);
      }
      rotationState.contributionProgress = adjusted;

      // Rotate queue.
      const nextQueue = payoutQueue.slice();
      if (nextQueue.length && nextQueue[0] === recipient) {
        nextQueue.shift();
      } else {
        const idx = nextQueue.indexOf(recipient);
        if (idx >= 0) nextQueue.splice(idx, 1);
      }
      nextQueue.push(recipient);
      // Ensure all members present.
      for (const m of members) {
        if (!nextQueue.includes(m)) nextQueue.push(m);
      }
      rotationState.payoutQueue = nextQueue;

      // Advance next payout date beyond now.
      const now = new Date();
      let nextPayoutDate = new Date(rotationState.nextPayoutDate || now.toISOString());
      while (!(nextPayoutDate > now)) {
        nextPayoutDate = new Date(nextPayoutDate.getTime() + cycleLengthDays * 24 * 60 * 60 * 1000);
      }
      rotationState.nextPayoutDate = nextPayoutDate.toISOString();

      // Also append a payout transaction to the group ledger.
      ledger.push({
        id: `payout-${groupId}-${nextRound}-${Date.now()}`,
        fromUserId: groupId,
        toUserId: recipient,
        amount: payoutAmount,
        timestamp: processedAt,
        status: "success",
        gateway: "equb_payout",
        feeAmount: 0,
        netAmount: payoutAmount,
        verificationStatus: "success",
      });
    }

    current.ledger = ledger;
    current.rotationState = rotationState;
    current.updatedAtMs = admin.database.ServerValue.TIMESTAMP;
    return current;
  });

  if (!groupResult.committed) {
    console.warn("chapaFinalize: Group update not committed", { groupId, userId, txRef });
  }

  // Award points to the payer for contribution.
  try {
    const ledgerId = userRef.child("points_ledger").push().key;
    await userRef.transaction((current) => {
      if (!current || typeof current !== "object") return;
      current.points = Number(current.points || 0) + points;
      if (ledgerId && points > 0) {
        const ledger =
          current.points_ledger && typeof current.points_ledger === "object"
            ? current.points_ledger
            : {};
        ledger[ledgerId] = {
          delta: points,
          action: "contribute",
          createdAtMs: nowMs,
          relatedTransactionId: txRef,
          metadata: { amount: effectiveAmount, groupId, gateway: "chapa" },
        };
        current.points_ledger = ledger;
      }
      return current;
    });
  } catch (e) {
    console.warn("chapaFinalize: Failed to award points", { userId, txRef, error: String(e) });
  }

  await txDbRef.update({
    status: "success",
    verificationStatus: "success",
    verifiedAtMs: nowMs,
    feeAmount: fee,
    netAmount: net,
  });

  return { ok: true, status: "success" };
}

exports.chapaVerifyAndFinalize = functions.https.onCall(async (data, context) => {
  assertAuthed(context);
  const txRef = (data && data.txRef ? String(data.txRef) : "").trim();
  if (!txRef) {
    throw new functions.https.HttpsError("invalid-argument", "txRef required");
  }

  const isEmulator =
    String(process.env.FUNCTIONS_EMULATOR || "").toLowerCase() === "true";
  const secretKey = await getChapaSecretKey({
    isEmulator,
    clientSecretKey: data && data.secretKey,
  });

  if (!secretKey) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      isEmulator
        ? "Chapa secretKey not provided for emulator. Set CHAPA_SECRET_KEY env var."
        : "Chapa secretKey not configured."
    );
  }

  const { resp, decoded, endpoint } = await verifyChapaTransaction(secretKey, txRef);
  if (!resp.ok) {
    console.error("Chapa verify failed", {
      endpoint,
      status: resp.status,
      txRef,
      decoded: decoded ? redactSensitive(decoded) : undefined,
    });
    throw new functions.https.HttpsError(
      "unavailable",
      `Chapa verify failed (${resp.status})`
    );
  }

  const verified = isChapaSuccess(decoded);
  const verifiedAmount = getVerifiedAmount(decoded);
  const result = await finalizeChapaTx({ txRef, verified, verifiedAmount });
  return { ok: true, verified, result };
});

exports.chapaWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const body = isPlainObject(req.body) ? req.body : safeJsonParse(req.rawBody?.toString("utf8")) || {};
    const txRef =
      (body && (body.tx_ref || body.txRef || body.reference))
        ? String(body.tx_ref || body.txRef || body.reference).trim()
        : (req.query && (req.query.tx_ref || req.query.txRef))
          ? String(req.query.tx_ref || req.query.txRef).trim()
          : "";

    if (!txRef) {
      return res.status(400).send({ ok: false, error: "tx_ref required" });
    }

    const isEmulator =
      String(process.env.FUNCTIONS_EMULATOR || "").toLowerCase() === "true";
    const secretKey = await getChapaSecretKey({ isEmulator });
    if (!secretKey) {
      return res.status(500).send({ ok: false, error: "Chapa secretKey not configured" });
    }

    const { resp, decoded } = await verifyChapaTransaction(secretKey, txRef);
    if (!resp.ok) {
      console.error("Chapa verify failed (webhook)", {
        status: resp.status,
        txRef,
        decoded: decoded ? redactSensitive(decoded) : undefined,
      });
      return res.status(503).send({ ok: false, error: "verify failed" });
    }

    const verified = isChapaSuccess(decoded);
    const verifiedAmount = getVerifiedAmount(decoded);
    const result = await finalizeChapaTx({ txRef, verified, verifiedAmount });
    return res.status(200).send({ ok: true, verified, result });
  } catch (e) {
    console.error("Chapa webhook error", { error: String(e) });
    return res.status(500).send({ ok: false, error: "internal" });
  }
});

// --- Advanced Admin Functions ---

const {
  getAdminDashboardStats,
  getAdminAuditLogs,
  logAdminAction,
  performSystemMaintenance,
  generateComplianceReport,
} = require("./advanced_admin");

const {
  telebirrWebhook,
  cbeBirrWebhook,
  checkMobileMoneyTransaction,
  processPendingMobileMoneyTransactions,
} = require("./mobile_money_webhooks");

const {
  schedulePushNotification,
  sendImmediateNotification,
  cancelScheduledNotifications,
  sendScheduledNotifications,
  scheduleContributionReminders,
  schedulePayoutNotifications,
} = require("./push_notifications");

// --- Email Notifications ---

const { EmailService } = require("./email_service");
const emailService = new EmailService();

// Send welcome email when user is created
exports.sendWelcomeEmail = functions.database
  .ref("users/{userId}")
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const userData = snapshot.val();

    if (!userData || !userData.email) {
      console.log("No email found for user:", userId);
      return;
    }

    try {
      await emailService.sendWelcomeEmail(
        userData.email,
        userData.name || "User"
      );
      console.log("Welcome email sent to:", userData.email);
    } catch (error) {
      console.error("Failed to send welcome email:", error);
    }
  });

// Send contribution reminder emails
exports.scheduleContributionReminders = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async (context) => {
    const db = admin.database();
    const now = new Date();
    const reminderDate = new Date(now.getTime() + 24 * 60 * 60 * 1000); // 24 hours from now

    try {
      // Get all groups with upcoming contribution dates
      const groupsSnapshot = await db.ref("groups").get();
      if (!groupsSnapshot.exists()) return;

      const groups = groupsSnapshot.val();

      for (const [groupId, groupData] of Object.entries(groups)) {
        if (!groupData.nextPayoutDate) continue;

        const nextPayout = new Date(groupData.nextPayoutDate);
        const timeDiff = nextPayout.getTime() - reminderDate.getTime();

        // If next payout is within 24 hours, send reminders
        if (timeDiff > 0 && timeDiff <= 24 * 60 * 60 * 1000) {
          await sendGroupContributionReminders(db, groupId, groupData);
        }
      }

      console.log("Contribution reminders processed");
    } catch (error) {
      console.error("Failed to process contribution reminders:", error);
    }
  });

// Send payout notification emails
exports.sendPayoutNotification = functions.database
  .ref("auto_topup_executions/{executionId}")
  .onCreate(async (snapshot, context) => {
    const executionData = snapshot.val();
    if (!executionData || executionData.status !== "success") return;

    // This is for auto top-up success - you might want different logic for actual payouts
    // For now, this serves as an example of how to trigger email notifications
    console.log(
      "Auto top-up successful, could send notification:",
      executionData
    );
  });

// Manual email sending function for admins
exports.adminSendEmail = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const to = (data && data.to ? String(data.to) : "").trim();
  const subject = (data && data.subject ? String(data.subject) : "").trim();
  const html = (data && data.html ? String(data.html) : "").trim();
  const text = (data && data.text ? String(data.text) : "").trim();

  if (!to || !subject || (!html && !text)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "to, subject, and html/text required."
    );
  }

  try {
    const result = await emailService.sendEmail(to, subject, html, text);
    return { ok: true, result };
  } catch (error) {
    console.error("Failed to send email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});

// --- User Email Preferences Management ---

exports.getUserEmailPreferences = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const targetUserId = (
      data && data.userId ? String(data.userId) : ""
    ).trim();

    if (!targetUserId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId required."
      );
    }

    // Users can only get their own preferences, admins can get any user's
    const db = admin.database();
    const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
    const isSuperAdmin = (
      await db.ref(`superadmins/${callerUid}`).get()
    ).exists();

    if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Can only access your own email preferences."
      );
    }

    try {
      const prefsSnapshot = await db
        .ref(`user_email_preferences/${targetUserId}`)
        .get();
      const preferences = prefsSnapshot.exists() ? prefsSnapshot.val() : {}; // Return empty object for defaults

      return { success: true, preferences };
    } catch (error) {
      console.error("Failed to get email preferences:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get email preferences"
      );
    }
  }
);

exports.updateUserEmailPreferences = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const targetUserId = (
      data && data.userId ? String(data.userId) : ""
    ).trim();
    const preferences = data && data.preferences;

    if (!targetUserId || !isPlainObject(preferences)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId and preferences required."
      );
    }

    // Users can only update their own preferences, admins can update any user's
    const db = admin.database();
    const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
    const isSuperAdmin = (
      await db.ref(`superadmins/${callerUid}`).get()
    ).exists();

    if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Can only update your own email preferences."
      );
    }

    try {
      // Validate preferences structure
      const validKeys = [
        "contributionReminders",
        "payoutNotifications",
        "groupInvitations",
        "transactionConfirmations",
        "weeklySummaries",
        "marketingEmails",
        "lowBalanceWarnings",
        "systemUpdates",
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

      console.log("Email preferences updated for user:", targetUserId);
      return { success: true };
    } catch (error) {
      console.error("Failed to update email preferences:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update email preferences"
      );
    }
  }
);

exports.getUserEmailHistory = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const targetUserId = (data && data.userId ? String(data.userId) : "").trim();
  const limit = Math.max(1, Math.min(100, Number((data && data.limit) || 50)));

  if (!targetUserId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "userId required."
    );
  }

  // Users can only get their own history, admins can get any user's
  const db = admin.database();
  const isAdmin = (await db.ref(`admins/${callerUid}`).get()).exists();
  const isSuperAdmin = (
    await db.ref(`superadmins/${callerUid}`).get()
  ).exists();

  if (callerUid !== targetUserId && !isAdmin && !isSuperAdmin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Can only access your own email history."
    );
  }

  try {
    const historySnapshot = await db
      .ref("email_notifications")
      .orderByChild("userId")
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
    console.error("Failed to get email history:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to get email history"
    );
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
      const prefsSnapshot = await db
        .ref(`user_email_preferences/${memberId}`)
        .get();
      const prefs = prefsSnapshot.exists() ? prefsSnapshot.val() : {};
      const reminderPref = prefs.contributionReminders || "immediate";

      if (reminderPref === "never") continue;

      // Get user's contribution status (simplified)
      const contributionAmount = groupData.contributionAmount || 0;
      const nextPayoutDate = groupData.nextPayoutDate;

      await emailService.sendContributionReminder(
        userData.email,
        userData.name || "User",
        groupData.name || "Savings Group",
        contributionAmount,
        new Date(nextPayoutDate).toLocaleDateString()
      );

      console.log("Contribution reminder sent to:", userData.email);
    } catch (error) {
      console.error(
        "Failed to send contribution reminder to member:",
        memberId,
        error
      );
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

  const snap = await db.ref("groups").limitToFirst(limit).get();
  const raw = snap.val() || {};
  const items = Object.keys(raw).map((id) => {
    const g = raw[id] || {};
    const members = Array.isArray(g.members) ? g.members : [];
    return {
      id: g.id || id,
      name: g.name || "",
      contributionAmount: Number(g.contributionAmount || 0),
      frequencyDays: Number(g.frequencyDays || 0),
      payoutStrategy: g.payoutStrategy || "fixedOrder",
      membersCount: members.length,
      bannerUrl: g.bannerUrl || null,
    };
  });
  items.sort((a, b) => String(a.name).localeCompare(String(b.name)));
  return { ok: true, items };
});

exports.adminGetGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : "").trim();
  if (!groupId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "groupId required."
    );
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const snap = await db.ref(`groups/${groupId}`).get();
  if (!snap.exists())
    throw new functions.https.HttpsError("not-found", "Group not found.");
  return { ok: true, group: snap.val() };
});

exports.adminUpdateGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : "").trim();
  const patch = data && data.patch;
  if (!groupId || !isPlainObject(patch)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "groupId and patch required."
    );
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const ref = db.ref(`groups/${groupId}`);
  const result = await ref.transaction((current) => {
    if (!current || typeof current !== "object") return;

    if (patch.name != null) current.name = String(patch.name);
    if (patch.bannerUrl !== undefined)
      current.bannerUrl = patch.bannerUrl ? String(patch.bannerUrl) : null;
    if (patch.contributionAmount != null)
      current.contributionAmount = Number(patch.contributionAmount);

    if (patch.frequencyDays != null) {
      const days = Number(patch.frequencyDays);
      current.frequencyDays = days;
      if (!current.scheduleConfig || typeof current.scheduleConfig !== "object")
        current.scheduleConfig = {};
      current.scheduleConfig.cycleLengthDays = days;
      current.scheduleConfig.cycle = inferCycle(days);
    }

    if (patch.payoutStrategy != null) {
      const strategy = String(patch.payoutStrategy);
      current.payoutStrategy = strategy;
      if (!current.scheduleConfig || typeof current.scheduleConfig !== "object")
        current.scheduleConfig = {};
      current.scheduleConfig.strategy = strategy;
    }

    current.updatedAtMs = admin.database.ServerValue.TIMESTAMP;
    current.updatedBy = callerUid;
    return current;
  });

  if (!result.committed) {
    throw new functions.https.HttpsError(
      "aborted",
      "Group update could not be committed."
    );
  }

  return { ok: true };
});

exports.adminAddGroupMember = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : "").trim();
  const memberId = (data && data.memberId ? String(data.memberId) : "").trim();
  if (!groupId || !memberId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "groupId and memberId required."
    );
  }

  const db = admin.database();
  await assertAdminUid(db, callerUid);

  const ref = db.ref(`groups/${groupId}`);
  const result = await ref.transaction((current) => {
    if (!current || typeof current !== "object") return;

    const members = Array.isArray(current.members)
      ? current.members.slice()
      : [];
    if (!members.includes(memberId)) members.push(memberId);
    current.members = members;

    if (!current.scheduleConfig || typeof current.scheduleConfig !== "object")
      current.scheduleConfig = {};
    current.scheduleConfig.preferredOrder = members;

    if (!current.rotationState || typeof current.rotationState !== "object")
      current.rotationState = {};
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
    throw new functions.https.HttpsError(
      "aborted",
      "Member add could not be committed."
    );
  }
  return { ok: true };
});

exports.adminRemoveGroupMember = functions.https.onCall(
  async (data, context) => {
    const callerUid = assertAuthed(context);
    const groupId = (data && data.groupId ? String(data.groupId) : "").trim();
    const memberId = (
      data && data.memberId ? String(data.memberId) : ""
    ).trim();
    if (!groupId || !memberId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId and memberId required."
      );
    }

    const db = admin.database();
    await assertAdminUid(db, callerUid);

    const ref = db.ref(`groups/${groupId}`);
    const result = await ref.transaction((current) => {
      if (!current || typeof current !== "object") return;

      const members = Array.isArray(current.members)
        ? current.members.slice()
        : [];
      current.members = members.filter((m) => String(m) !== memberId);

      if (
        current.scheduleConfig &&
        typeof current.scheduleConfig === "object"
      ) {
        if (Array.isArray(current.scheduleConfig.preferredOrder)) {
          current.scheduleConfig.preferredOrder =
            current.scheduleConfig.preferredOrder.filter(
              (m) => String(m) !== memberId
            );
        }
        if (isPlainObject(current.scheduleConfig.adminAssignments)) {
          const assignments = { ...current.scheduleConfig.adminAssignments };
          for (const k of Object.keys(assignments)) {
            if (String(assignments[k]) === memberId) delete assignments[k];
          }
          current.scheduleConfig.adminAssignments = assignments;
        }
      }

      if (current.rotationState && typeof current.rotationState === "object") {
        if (Array.isArray(current.rotationState.payoutQueue)) {
          current.rotationState.payoutQueue =
            current.rotationState.payoutQueue.filter(
              (m) => String(m) !== memberId
            );
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
      throw new functions.https.HttpsError(
        "aborted",
        "Member removal could not be committed."
      );
    }
    return { ok: true };
  }
);

exports.adminDeleteGroup = functions.https.onCall(async (data, context) => {
  const callerUid = assertAuthed(context);
  const groupId = (data && data.groupId ? String(data.groupId) : "").trim();
  if (!groupId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "groupId required."
    );
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
exports.processPendingMobileMoneyTransactions =
  processPendingMobileMoneyTransactions;

// --- Push Notifications ---

exports.schedulePushNotification = schedulePushNotification;
exports.sendImmediateNotification = sendImmediateNotification;
exports.cancelScheduledNotifications = cancelScheduledNotifications;
exports.sendScheduledNotifications = sendScheduledNotifications;
exports.scheduleContributionReminders = scheduleContributionReminders;
exports.schedulePayoutNotifications = schedulePayoutNotifications;
