/*
Lists superadmin users (from RTDB superadmins/{uid}=true) with their emails.

Usage (PowerShell):
  cd "C:\Users\PC\Documents\olani's\nextjs\Equb\functions"
  npm install

  # Option A: env var credentials
  $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\PC\Documents\olani's\nextjs\equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json"

  node scripts/list_superadmins.js --databaseURL "https://<YOUR-DB>.firebaseio.com"

Notes:
- Requires RTDB enabled and service account access.
- Prints uid + email for each superadmin uid found.
*/

const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
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

async function main() {
  const args = parseArgs(process.argv);
  const databaseURL = (args.databaseURL ? String(args.databaseURL) : '').trim();
  const projectId = (args.projectId ? String(args.projectId) : '').trim();

  if (!databaseURL) throw new Error('Missing required --databaseURL');

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
    ...(projectId ? { projectId } : {}),
  });

  const snap = await admin.database().ref('superadmins').once('value');
  const map = snap.val() || {};
  const uids = Object.keys(map).filter((uid) => map[uid] === true);

  if (uids.length === 0) {
    process.stdout.write('No superadmins found in RTDB at superadmins/{uid}=true\n');
    return;
  }

  process.stdout.write(`Found ${uids.length} superadmin uid(s):\n\n`);

  for (const uid of uids) {
    try {
      const user = await admin.auth().getUser(uid);
      process.stdout.write(`- uid: ${uid}\n  email: ${user.email || '(no email)'}\n\n`);
    } catch (e) {
      const msg = (e && e.message) ? e.message : String(e);
      process.stdout.write(`- uid: ${uid}\n  email: (lookup failed)\n  error: ${msg}\n\n`);
    }
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
