/*
Resets a Firebase Auth (Email/Password) user's password by email.

Usage (PowerShell):
  cd "C:\Users\PC\Documents\olani's\nextjs\Equb\functions"
  npm install

  # Option A (recommended): point Admin SDK at your service account JSON
  $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\Users\PC\Documents\olani's\nextjs\equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json"

  node scripts/reset_password_by_email.js --email "user@example.com" --password "NewStrongPassword123!"

  # Option B: pass credentials file explicitly (no env var)
  node scripts/reset_password_by_email.js \
    --credentials "C:\Users\PC\Documents\olani's\nextjs\equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json" \
    --email "user@example.com" \
    --password "NewStrongPassword123!"

Notes:
- Requires Email/Password provider enabled in Firebase Auth.
- If --password is omitted, a random one is generated and printed.
- Do NOT commit the service account JSON to git.
*/

const fs = require('fs');
const path = require('path');
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

function resolveDefaultCredentialsPath() {
  // If you keep the service-account JSON one folder above the repo root as described:
  //   C:\Users\PC\Documents\olani's\nextjs\equb-...json
  // then from functions/scripts, that is ../../../equb-...json
  const expectedName = 'equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json';
  return path.resolve(__dirname, '..', '..', '..', expectedName);
}

function initAdmin(args) {
  const credentialsArg = (args.credentials ? String(args.credentials) : '').trim();

  if (credentialsArg) {
    const resolved = path.resolve(credentialsArg);
    if (!fs.existsSync(resolved)) {
      throw new Error(`--credentials file not found: ${resolved}`);
    }

    const json = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(json),
    });
    return;
  }

  // Prefer application default (GOOGLE_APPLICATION_CREDENTIALS or GCP env).
  // If the env var isn't set, try a reasonable local default.
  try {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  } catch (e) {
    const fallback = resolveDefaultCredentialsPath();
    if (!fs.existsSync(fallback)) {
      throw e;
    }
    const json = JSON.parse(fs.readFileSync(fallback, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(json),
    });
  }
}

async function main() {
  const args = parseArgs(process.argv);

  const email = (args.email ? String(args.email) : '').trim();
  if (!email) throw new Error('Missing required --email');

  const password = (args.password ? String(args.password) : '').trim() || randomPassword();

  initAdmin(args);

  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().updateUser(user.uid, { password });

  process.stdout.write(
    [
      'Password reset complete:',
      `  email: ${email}`,
      `  uid: ${user.uid}`,
      `  new password: ${password}`,
      '',
    ].join('\n')
  );
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
