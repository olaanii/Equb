/*
Usage (PowerShell):
  cd "E:\my files\flutter\mmm\equb\functions"
  npm install
  $env:GOOGLE_APPLICATION_CREDENTIALS = "D:\Downloads\equb-1e38b-firebase-adminsdk-fbsvc-14b57414bf.json"
  node scripts/inspect_groups.js --databaseURL "https://equb-1e38b-default-rtdb.firebaseio.com" --limit 10
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
  const databaseURL = String(args.databaseURL || '').trim();
  const limit = Math.max(1, Math.min(50, Number(args.limit || 10)));

  if (!databaseURL) {
    throw new Error('Missing required --databaseURL');
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    databaseURL,
  });

  const snap = await admin.database().ref('groups').limitToLast(limit).get();
  const v = snap.val();
  if (!v) {
    console.log('No groups found.');
    return;
  }

  const entries = Object.entries(v);
  console.log(`Last ${entries.length} groups:`);
  for (const [key, val] of entries) {
    const name = val && val.name;
    const members = val && val.members;
    const hasSchedule = !!(val && val.scheduleConfig);
    const hasRotation = !!(val && val.rotationState);
    const freq = val && val.frequencyDays;
    console.log(
      '-',
      key,
      '|',
      name,
      '| members:',
      Array.isArray(members) ? members.length : typeof members,
      '| frequencyDays:',
      freq,
      '| schedule:',
      hasSchedule,
      '| rotation:',
      hasRotation
    );
  }
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exitCode = 1;
});
