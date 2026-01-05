/*
Creates (or resets) an email/password Firebase Auth user and promotes them to:
  superadmins/{uid} = true
  admins/{uid} = true

Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  npm install
  $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\Downloads\<service-account>.json"

  # Create new OR reset existing
  node scripts/create_or_reset_superadmin_user.js \
    --databaseURL "https://equb-1e38b-default-rtdb.firebaseio.com" \
    --email "superadmin@example.com" \
    --password "ChangeMe123!" \
    --resetExisting true

Notes:
- Requires Email/Password provider enabled in Firebase Auth.
- If --password is omitted, a random one is generated and printed.
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

function toBool(v) {
  if (v === true) return true;
  const s = String(v || '').trim().toLowerCase();
  return s === 'true' || s === '1' || s === 'yes' || s === 'y';
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
  const databaseURL = (args.databaseURL ? String(args.databaseURL) : '').trim();
  const projectId = (args.projectId ? String(args.projectId) : '').trim();
  const resetExisting = toBool(args.resetExisting);

  if (!email) throw new Error('Missing required --email');
  if (!databaseURL) throw new Error('Missing required --databaseURL');

  const password = (args.password ? String(args.password) : '').trim() || randomPassword();

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
    ...(projectId ? { projectId } : {}),
  });

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
    if (!resetExisting) {
      throw new Error(
        `User already exists for ${email}.\n` +
          `Pass --resetExisting true to set a new password and promote to superadmin.`
      );
    }

    userRecord = await admin.auth().updateUser(userRecord.uid, {
      password,
      emailVerified: true,
    });
  } catch (e) {
    const msg = (e && e.message) ? e.message : String(e);
    // If not found, create new user.
    if (String(msg).includes('There is no user record')) {
      userRecord = await admin.auth().createUser({
        email,
        password,
        emailVerified: true,
      });
    } else {
      throw e;
    }
  }

  const uid = userRecord.uid;
  const db = admin.database();
  await db.ref(`admins/${uid}`).set(true);
  await db.ref(`superadmins/${uid}`).set(true);

  process.stdout.write(
    [
      'Super admin ready:',
      `  email: ${email}`,
      `  password: ${password}`,
      `  uid: ${uid}`,
      `  admins/${uid} = true`,
      `  superadmins/${uid} = true`,
      '',
    ].join('\n')
  );
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
