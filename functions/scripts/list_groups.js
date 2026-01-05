/*
Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\Downloads\equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json"
  node scripts/list_groups.js --databaseURL "https://equb-1e38b-default-rtdb.firebaseio.com"
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
  if (!databaseURL) throw new Error('Missing --databaseURL');

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
  });

  const snap = await admin.database().ref('groups').get();
  const val = snap.val();
  if (!val) {
    console.log('groups: <empty>');
    return;
  }
  if (typeof val !== 'object') {
    console.log('groups: non-object', typeof val);
    console.log(val);
    return;
  }

  const entries = Object.entries(val);
  console.log(`groups count: ${entries.length}`);
  for (const [id, g] of entries.slice(0, 50)) {
    const name = g && typeof g === 'object' ? g.name : undefined;
    const fields = g && typeof g === 'object' ? Object.keys(g) : [];
    console.log('-', id, 'name=', name, 'fields=', fields.join(','));
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
