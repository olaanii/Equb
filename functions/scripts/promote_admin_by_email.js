/*
Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  npm install
  $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"

  node scripts/promote_admin_by_email.js \
    --databaseURL "https://equb-1e38b-default-rtdb.firebaseio.com" \
    --email "olani@gmail.com"

Notes:
- Promotes an EXISTING Firebase Auth user (by email) to admin by setting:
    admins/{uid} = true
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
  const email = (args.email ? String(args.email) : '').trim();
  const databaseURL = (args.databaseURL ? String(args.databaseURL) : '').trim();
  const projectId = (args.projectId ? String(args.projectId) : '').trim();

  if (!email) throw new Error('Missing required --email');
  if (!databaseURL) {
    throw new Error('Missing required --databaseURL (example: https://<db>.firebaseio.com)');
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
    ...(projectId ? { projectId } : {}),
  });

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (e) {
    const msg = (e && e.message) ? e.message : String(e);
    throw new Error(
      `No Firebase Auth user found for email ${email}.\n` +
        `Create the account first (via app signup or the create_admin_user.js script).\n` +
        `Raw error: ${msg}`
    );
  }

  await admin.database().ref(`admins/${userRecord.uid}`).set(true);

  process.stdout.write(
    [
      'Admin promotion complete:',
      `  email: ${email}`,
      `  uid: ${userRecord.uid}`,
      `  admins/${userRecord.uid} = true`,
      '',
    ].join('\n')
  );
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
