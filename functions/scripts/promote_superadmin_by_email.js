/*
Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  npm install
  $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\Downloads\<service-account>.json"

  node scripts/promote_superadmin_by_email.js \
    --databaseURL "https://equb-1e38b-default-rtdb.firebaseio.com" \
    --email "olani@gmail.com"

Effect:
  superadmins/{uid} = true
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
  if (!databaseURL) throw new Error('Missing required --databaseURL');

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
    ...(projectId ? { projectId } : {}),
  });

  const userRecord = await admin.auth().getUserByEmail(email);
  await admin.database().ref(`superadmins/${userRecord.uid}`).set(true);

  process.stdout.write(
    [
      'Super admin promotion complete:',
      `  email: ${email}`,
      `  uid: ${userRecord.uid}`,
      `  superadmins/${userRecord.uid} = true`,
      '',
    ].join('\n')
  );
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
