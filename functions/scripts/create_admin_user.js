/*
Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  npm install
  $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
  node scripts/create_admin_user.js --databaseURL "https://<db>.firebaseio.com" --email "admin@example.com" --password "ChangeMe123!"

Notes:
- Requires a service account JSON with access to Auth + RTDB.
- Prints the created credentials to stdout.
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

function randomPassword(length = 20) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%^&*()-_=+[]{}';
  let out = '';
  for (let i = 0; i < length; i++) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

async function main() {
  const args = parseArgs(process.argv);

  const email = (args.email ? String(args.email) : '').trim();
  const password = (args.password ? String(args.password) : '').trim() || randomPassword();
  const databaseURL = (args.databaseURL ? String(args.databaseURL) : '').trim();
  const projectId = (args.projectId ? String(args.projectId) : '').trim();

  if (!email) {
    throw new Error('Missing required --email');
  }
  if (!databaseURL) {
    throw new Error('Missing required --databaseURL (example: https://<db>.firebaseio.com)');
  }

  // For local CLI usage, rely on GOOGLE_APPLICATION_CREDENTIALS.
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
    ...(projectId ? { projectId } : {}),
  });

  const userRecord = await admin.auth().createUser({
    email,
    password,
    emailVerified: true,
  });

  await admin.database().ref(`admins/${userRecord.uid}`).set(true);

  // Output credentials for the developer running this.
  // (Treat like a secret; rotate after first login if needed.)
  process.stdout.write(
    [
      'Admin user created:',
      `  uid: ${userRecord.uid}`,
      `  email: ${email}`,
      `  password: ${password}`,
      '',
      'Admin flag set:',
      `  admins/${userRecord.uid} = true`,
      '',
    ].join('\n')
  );
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
