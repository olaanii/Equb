/*
One-off RTDB migration: ensure groups/{groupId}/members is a map keyed by uid.

Usage (PowerShell):
  cd functions
  node scripts/migrate_rtdb_group_members_to_map.js --serviceAccount "C:\\path\\service-account.json" --databaseURL "https://<PROJECT_ID>-default-rtdb.firebaseio.com" --dryRun
  node scripts/migrate_rtdb_group_members_to_map.js --serviceAccount "C:\\path\\service-account.json" --databaseURL "https://<PROJECT_ID>-default-rtdb.firebaseio.com" --commit

Notes:
- If members is missing, we try to infer from scheduleConfig.preferredOrder.
- Writes only the `members` field.
*/

const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const token = argv[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }
  return args;
}

function membersToMap(members) {
  if (!members) return null;

  // Already canonical map.
  if (typeof members === 'object' && !Array.isArray(members)) {
    const result = {};
    for (const [k, v] of Object.entries(members)) {
      if (k && v === true) result[k] = true;
      if (k && v === 1) result[k] = true;
      if (k && v === 'true') result[k] = true;
    }
    return Object.keys(result).length ? result : {};
  }

  // List of uids.
  if (Array.isArray(members)) {
    const result = {};
    for (const uid of members) {
      if (typeof uid === 'string' && uid.trim()) {
        result[uid.trim()] = true;
      }
    }
    return result;
  }

  return null;
}

function inferMembersFromPreferredOrder(group) {
  const preferred = group?.scheduleConfig?.preferredOrder;
  if (!Array.isArray(preferred)) return null;
  return membersToMap(preferred);
}

function inferMembersFromRotationState(group) {
  const state = group?.rotationState;
  if (!state || typeof state !== 'object') return null;

  const inferred = [];

  const queue = state.payoutQueue;
  if (Array.isArray(queue)) {
    for (const uid of queue) inferred.push(uid);
  }

  const progress = state.contributionProgress;
  if (progress && typeof progress === 'object' && !Array.isArray(progress)) {
    for (const uid of Object.keys(progress)) inferred.push(uid);
  }

  return membersToMap(inferred);
}

async function main() {
  const args = parseArgs(process.argv);
  const serviceAccountPath = args.serviceAccount;
  const databaseURL = args.databaseURL;
  const commit = !!args.commit;
  const dryRun = !!args.dryRun || !commit;

  if (!serviceAccountPath || !databaseURL) {
    console.error('Missing required args.');
    console.error('Required: --serviceAccount <path> --databaseURL <url>');
    console.error('Optional: --dryRun (default) | --commit');
    process.exit(2);
  }

  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL,
  });

  const db = admin.database();
  const groupsRef = db.ref('groups');

  const snap = await groupsRef.get();
  const raw = snap.val();
  if (!raw || typeof raw !== 'object') {
    console.log('No groups found.');
    return;
  }

  const stats = {
    total: 0,
    alreadyCanonical: 0,
    migratedFromList: 0,
    inferredFromPreferredOrder: 0,
    inferredFromRotationState: 0,
    emptyOrMissing: 0,
    skippedMalformed: 0,
    writes: 0,
  };

  const flagged = [];

  for (const [groupId, group] of Object.entries(raw)) {
    stats.total++;

    if (!group || typeof group !== 'object') {
      stats.skippedMalformed++;
      continue;
    }

    const currentMembers = group.members;

    // Detect canonical: map with at least one key, or empty map.
    const isCanonicalMap =
      currentMembers &&
      typeof currentMembers === 'object' &&
      !Array.isArray(currentMembers);

    if (isCanonicalMap) {
      stats.alreadyCanonical++;
      continue;
    }

    let nextMembersMap = membersToMap(currentMembers);
    let reason = null;

    if (Array.isArray(currentMembers)) {
      reason = 'list';
    }

    if (!nextMembersMap) {
      nextMembersMap = inferMembersFromPreferredOrder(group);
      if (nextMembersMap) {
        reason = 'preferredOrder';
      }
    }

    if (!nextMembersMap) {
      nextMembersMap = inferMembersFromRotationState(group);
      if (nextMembersMap) {
        reason = 'rotationState';
      }
    }

    if (!nextMembersMap || Object.keys(nextMembersMap).length === 0) {
      stats.emptyOrMissing++;
      flagged.push({
        groupId,
        name: group.name ?? null,
        reason: 'missing-or-empty-members',
      });
      continue;
    }

    if (dryRun) {
      // No write.
    } else {
      await groupsRef.child(groupId).child('members').set(nextMembersMap);
      stats.writes++;
    }

    if (reason === 'list') stats.migratedFromList++;
    if (reason === 'preferredOrder') stats.inferredFromPreferredOrder++;
    if (reason === 'rotationState') stats.inferredFromRotationState++;
  }

  console.log('--- RTDB members migration report ---');
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'COMMIT'}`);
  console.log(stats);
  if (flagged.length) {
    console.log('Flagged groups (missing/empty members):');
    for (const f of flagged.slice(0, 50)) {
      console.log(`- ${f.groupId} (${f.name ?? 'no-name'})`);
    }
    if (flagged.length > 50) {
      console.log(`...and ${flagged.length - 50} more`);
    }
  }
}

main().catch((e) => {
  console.error('Migration failed:', e);
  process.exit(1);
});
