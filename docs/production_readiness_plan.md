# Production Readiness Plan (Next Fixes)

Date: 2026-01-09

This plan focuses on making the current Flutter + Firebase (RTDB/Firestore/Functions/Auth) implementation **production-ready**, based on the issues observed during recent debugging:

- Newly created groups sometimes not showing due to **data-shape/schema drift**.
- Firebase Rules vs app payload mismatch (especially `groups/{groupId}/members`).
- Firestore `permission-denied` impacting onboarding persistence.
- Web phone auth/onboarding gaps.
- Analyzer warnings and missing “release gates” (CI + smoke tests).

## Goals

- Ensure **groups created are always readable and visible** to the creating user.
- Ensure RTDB rules enforce membership correctly and consistently.
- Ensure onboarding doesn’t crash/block users; persistence works under correct rules.
- Ensure phone auth works on web where enabled.
- Add basic release gates so “works on my machine” doesn’t reach production.

## Non-goals

- No major UI redesign.
- No new product features (only correctness, rules, reliability, and production hygiene).

---

## Priority 0 — Fix Group Schema + Rules Compatibility (BLOCKER)

### Problem

- RTDB rules for chat rely on:
  - `root.child('groups/' + $groupId + '/members').hasChild(auth.uid)`
- This implies `members` must be a **map keyed by uid** (e.g. `{ "uid1": true }`).
- Some groups in RTDB currently have `members` stored as a **list**, or missing.
- Flutter parsing also previously assumed a list; we fixed decoding to accept list/map/missing, but **rules and other services still need a single canonical schema**.

### Decision (recommended)

Adopt **canonical RTDB schema**:

- `groups/{groupId}/members/{uid} = true`

Keep backward compatibility in the app for a short time, but migrate data and write only the canonical format going forward.

### Implementation

1. **Update group creation writes** to always write `members` as a map.

   - Option A (best): change `RtdbEqubRepository.createGroup()` to write:
     - `membersMap = { for (uid in members) uid: true }`
     - Persist that shape into RTDB.
   - Also ensure schedule preferred order still uses a list in `scheduleConfig.preferredOrder`.

2. **Update group read model** to accept either shape (already done in `EqubGroup.fromJson`).

   - Keep this for at least one release to avoid breaking older data.

3. **Data migration/backfill** for existing groups:

   - Create a one-off Admin script (Node, Firebase Admin SDK) to:
     - Scan `groups/*`.
     - If `members` is a list, rewrite into map form.
     - If `members` missing, infer from `scheduleConfig.preferredOrder` if present; otherwise leave empty and flag.
   - Keep an audit output: number migrated, number skipped, number flagged.

   **Implemented**

   - Script: `functions/scripts/migrate_rtdb_group_members_to_map.js`
   - Run (dry-run):
     - `cd functions`
     - `npm run migrate:rtdb:members -- --serviceAccount "C:\\path\\service-account.json" --databaseURL "https://<PROJECT_ID>-default-rtdb.firebaseio.com" --dryRun`
   - Run (commit):
     - `cd functions`
     - `npm run migrate:rtdb:members -- --serviceAccount "C:\\path\\service-account.json" --databaseURL "https://<PROJECT_ID>-default-rtdb.firebaseio.com" --commit`

4. **Rules validation**
   - After migration, ensure the rules still match the canonical schema.
   - Add a small automated check (script) to verify that for every group:
     - `members` exists and is a map (or explicitly allow missing but then chat is disabled).

### Acceptance criteria

- Creating a group immediately shows it in the Groups list.
- Opening group chat does not fail with permission errors when creator is a member.
- Existing groups created with old schema remain visible.

### Status (implemented)

- RTDB group writes now persist `members` as a canonical map (`{uid: true}`) while keeping `scheduleConfig.preferredOrder` as a list.
- Backward-compatible reads remain supported for legacy data.

---

## Priority 1 — Make Groups List “Production-Correct” (not demo-only)

### Problem

- `equbGroupsProvider` currently contains **debug seeding** logic when groups is empty.
- This is convenient for dev but risky in staging/production testing (confusing “real” data).

### Implementation

- Keep dev seeding strictly behind `kDebugMode` (already is), but also add a hard guard:
  - Only seed if a dedicated flag is enabled, e.g. `config/feature_flags/demoSeedEnabled = true`.
  - Or remove seeding entirely once schema/migration is complete.

### Acceptance criteria

- No automatic group creation occurs in staging/prod.

### Status (implemented)

- Demo seeding is now blocked unless `config/feature_flags/demoSeedEnabled == true` in RTDB (and still only runs in `kDebugMode`).

---

## Priority 2 — Fix Firestore Onboarding Permissions (Production Rules)

### Problem

- Web runtime saw Firestore `permission-denied` during onboarding persistence.
- Current client code is resilient (doesn’t crash), but production should have correct access rules.

### Recommended rule shape (example)

- Allow authenticated users to read/write their own onboarding doc:
  - `user_onboarding/{uid}` where `request.auth.uid == uid`
- Allow authenticated users to read/write their own user profile doc:
  - `users/{uid}` where `request.auth.uid == uid`

### Implementation

1. Inspect Firestore rules (not RTDB rules) and add/confirm:

   - Users can `get/set` their own onboarding.
   - Disallow cross-user reads.

2. Keep current client-side permission-denied handling as a safety net.

### Acceptance criteria

- Onboarding persistence succeeds for signed-in users.
- No `permission-denied` errors during normal onboarding.

### Status (partially implemented)

- Added a baseline rules file at `firestore.rules` matching the recommended shape.
- Client-side permission-denied handling remains as a safety net.

---

## Priority 3 — Phone Auth: Make Web + Onboarding Consistent

### Problem

- Web phone auth requires reCAPTCHA.
- Login flow supports web reCAPTCHA, but onboarding phone verification may still be blocked/limited on web.

### Implementation

- Reuse the same web phone auth approach (RecaptchaVerifier + ConfirmationResult) in the onboarding phone step.
- Ensure there is exactly one reCAPTCHA container and it is present (already added to `web/index.html`).
- Decide whether onboarding should:
  - `linkWithCredential` if user already signed in, else `signInWithCredential`.

### Acceptance criteria

- On web: user can verify phone in onboarding without “not supported” messages.
- On mobile: verification continues to work.

### Status (implemented)

- Onboarding phone step now supports web using `RecaptchaVerifier` + `ConfirmationResult` (same approach as login).

---

## Priority 4 — Ensure Repository Choice is Single-Source-of-Truth

### Problem

- There are multiple “group” implementations in the repo:
  - `EqubGroup` + `equbGroupsProvider` (RTDB)
  - `Group` + `groupsProvider` (mock)
- This can cause confusion and “created group not shown” reports when different screens use different providers.

### Implementation

- Decide the production model:
  - For Equb app: use `EqubGroup` + `equbGroupsProvider` everywhere.
- Audit UI routes/screens and remove/disable mock group flows from production navigation.
- Keep mock-only code under a clear “demo” folder or behind a feature flag.

### Acceptance criteria

- Only one group list source is used by the app shell.
- Creating a group always affects the same list the user sees.

### Status (implemented as a safety guard)

- Legacy `/group-settings` and `/group-invitations` routes are disabled outside `kDebugMode` to prevent production navigation drift.

---

## Priority 5 — Release Gates: Analyzer Clean + Smoke Tests + CI

### Problem

- `flutter analyze` currently reports warnings/info in multiple files.
- Exit code is non-zero, which blocks clean CI.

### Implementation

1. Fix analyzer issues (don’t ignore):

   - Remove unused imports.
   - Replace `print` with structured logging (`SystemLogService`) or guarded debug printing.
   - Remove dead null-aware expressions and unused locals.

2. Wire CI:
   - Run:
     - `flutter pub get`
     - `flutter analyze`
     - `flutter test`
     - optionally `powershell -File .\\tool\\smoke_test_runner.ps1 -Skip*` variants.

### Acceptance criteria

- `flutter analyze` returns 0 issues.
- CI fails on analyzer/test failures.

### Status (implemented)

- `flutter analyze` returns 0 issues.

---

## Priority 6 — Observability + Safety

### Implementation

- Ensure client errors are logged in one place with context:
  - Use `SystemLogService` for repository failures and auth/onboarding.
- Add a lightweight “diagnostics” admin function/script for production debugging:
  - List groups with malformed schema.
  - Verify rules deploy version.

### Acceptance criteria

- When issues occur, logs include operation + groupId/userId + Firebase error code.

---

## Suggested Order of Execution (1–3 days)

1. Canonicalize groups schema + migration (Priority 0)
2. Remove/feature-flag demo seed (Priority 1)
3. Fix Firestore rules for onboarding (Priority 2)
4. Web onboarding phone verification (Priority 3)
5. Unify group providers (Priority 4)
6. Clean analyzer + CI gates (Priority 5)

---

## Rollout / Deployment Notes

- RTDB Rules: deploy `database.rules.json` via Firebase CLI.
- Firestore Rules: deploy via Firebase CLI.
- Do the RTDB migration **before** enabling strict chat/membership enforcement for all users.
- Keep backward compatibility in `EqubGroup.fromJson` for at least one app release.

---

## Quick Verification Checklist

- Create group → appears immediately in Groups tab.
- Group data in RTDB:
  - `groups/{groupId}/members/{uid} == true`
- Open group chat → message read/write succeeds for group members.
- Onboarding save/load succeeds with correct rules.
- Web phone verification works end-to-end (OTP + confirm).
- `flutter analyze` is clean and CI is green.

## Windows dev note (important)

On Windows, Flutter rejects projects whose path contains characters like `'`.
If your repo lives under a folder like `olani's`, create a safe junction and run Flutter from there:

- `New-Item -ItemType Directory -Path C:\\work -Force`
- `New-Item -ItemType Junction -Path C:\\work\\Equb -Target "C:\\Users\\PC\\Documents\\olani's\\nextjs\\Equb"`
- Then use: `cd C:\\work\\Equb` for `flutter analyze/run/build`.
