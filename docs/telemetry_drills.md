# Telemetry Drills

Purpose-built drills for QA, SRE, or release managers to rehearse the highest-risk failure modes (gateway secrets, analytics fan-out, and reminder delivery). Each scenario explains how to induce the fault, how to capture evidence through `SystemLogService`, and how to restore the environment afterwards.

> Run these in a staging build only. Every drill purposely perturbs credentials, analytics wiring, or reminder jobs, so revert the temporary changes before handing the app back to testers.

## 0. Capture Setup

1. Launch the app with full logging enabled:
   ```powershell
   flutter run -d chrome --debug
   ```
2. Start Flutter DevTools (`dart pub global run devtools`), open the running session, and pin the **Provider** tab entries for `systemLogServiceProvider`, `secureStorageServiceProvider`, and `analyticsServiceProvider`.
3. To execute drill helpers or export logs, keep the DevTools **Eval** console handy. Use this snippet whenever you need a `ProviderContainer` inside Eval:
   ```dart
   import 'package:flutter/widgets.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import 'package:equb/providers/providers.dart' as providers;

   final container = ProviderScope.containerOf(
     WidgetsBinding.instance.rootElement!,
     listen: false,
   );
   ```
4. Export the captured telemetry after each drill so the evidence can be attached to QA notes:
   ```dart
   final logs = container.read(providers.systemLogServiceProvider);
   final csv = logs.exportCsv();
   print(csv);
   ```

---

## Drill 1 – Gateway Secret Regression

**Goal:** Confirm that missing Telebirr or CBE credentials create actionable errors before traffic leaves the device.

1. In DevTools Eval (after creating the `container` variable from the setup block), wipe one credential:
   ```dart
   await container.read(providers.secureStorageServiceProvider).delete('gateway.telebirr.apiKey');
   ```
2. In the running app, navigate to **Wallet ▸ Deposit funds ▸ Telebirr**, attempt a deposit, and dismiss the snackbar.
3. Inspect `systemLogServiceProvider` for a new entry.

**Expected SystemLogService entry**

| Field | Value |
| --- | --- |
| `level` | `error` |
| `source` | `GatewayService.telebirr` (or `.cbe_birr` for that gateway) |
| `message` | `Missing apiKey for telebirr gateway. Add the secret via SecureStorage.` |
| `context` | `{"gatewayId":"telebirr","field":"apiKey"}` |

**Recovery**

Re-seed the credential (placeholder value is fine for drills) and rerun the flow to ensure the log stops repeating:
```dart
await container.read(providers.secureStorageServiceProvider).write('gateway.telebirr.apiKey', 'drill-placeholder');
```

---

## Drill 2 – Analytics Fan-out Failure

**Goal:** Validate that analytics/LTV instrumentation failures are surfaced through repository guardrails instead of silently dropping telemetry.

1. Create a temporary debug-only destination that always throws. Add the following helper to `lib/main.dart` (guard it with `assert(() { ...; return true; }());` so it never ships):
   ```dart
   class ThrowingAnalyticsDestination implements AnalyticsDestination {
     @override
     Future<void> send(AnalyticsEvent event) {
       throw Exception('drill: analytics fan-out blocked');
     }
   }
   ```
2. Wrap the root `ProviderScope` with an override when the drill flag is on:
   ```dart
   final failingAnalytics = AnalyticsService(
     destinations: [ThrowingAnalyticsDestination()],
   );

   runApp(
     ProviderScope(
       overrides: [
         analyticsServiceProvider.overrideWithValue(failingAnalytics),
       ],
       child: EqubApp(
         firebaseInitialized: firebaseInitialized,
         firebaseError: firebaseError,
       ),
     ),
   );
   ```
3. With the override active, perform a wallet deposit (any gateway). The Firestore transaction succeeds, but analytics fan-out now throws.
4. Inspect `systemLogServiceProvider`.

**Expected SystemLogService entry**

| Field | Value |
| --- | --- |
| `level` | `error` |
| `source` | `FirestoreWalletRepository.deposit` |
| `message` | `Exception: drill: analytics fan-out blocked` |
| `context` | Contains `operation: "deposit"`, plus the `userId`, `gateway`, and `amount` that were passed into the repository |

**Recovery**

Remove the override, hot-restart, and confirm new deposits no longer emit the error.

---

## Drill 3 – Reminder Scheduler & Notification Failures

### A. Malformed Firestore Job

1. Identify the active user ID (DevTools ▸ Provider ▸ `currentUserProvider`).
2. In Firestore (or the emulator), add a document under `users/{uid}/reminder_jobs/{drill_job}` with **no** `scheduledAt` field.
3. Wait for the listener to process the change.

**Expected log:**
- `level`: `warning`
- `source`: `ReminderSchedulerService`
- `message`: `Reminder job missing scheduledAt`
- `context`: `{"jobId":"drill_job","scheduledAt":"null"}`

### B. Muted User Suppression

1. In-app, open **Profile ▸ Notification Preferences** and set **Mute reminders** for at least 15 minutes.
2. Insert a valid reminder job (e.g., use Firestore console and copy an existing document, adjusting `scheduledAt` to `Timestamp.now()`).

**Expected log:**
- `level`: `info`
- `source`: `ReminderSchedulerService`
- `message`: `Muted until <timestamp> – suppressing push delivery`

The reminder is inserted as `read=true`, confirming the mute guardrail.

### C. Quiet-Hour Shift Verification

1. Configure quiet hours so the current time is inside the quiet window (e.g., start 20:00, end 08:00, run drill at 22:00).
2. Create a reminder job scheduled for the current minute.

**Expected logs:**
1. `info` entry stating `Reminder shifted out of quiet hours` with context showing `original` vs `shifted` timestamps.
2. Optional: if you delete `muteUntil` and re-run, the reminder should trigger a local push once the shifted time arrives.

### D. Stream Failure

(To test the Firestore listener failure path, temporarily disable the device network.)

1. With the app running, disable Wi-Fi.
2. In DevTools logs you should see:
   - `level`: `error`
   - `source`: `ReminderSchedulerService`
   - `message`: `Failed to sync reminder jobs`
   - `context`: includes the thrown error message

**Recovery:** Re-enable the network; logs should quiet once the listener reconnects.

---

## Attaching Evidence

- Export the `SystemLogService` CSV after every drill (`logs.exportCsv()` snippet above) and attach it to QA artifacts.
- Reference the automated coverage when citing reproducibility:
  - Gateway guardrails: `test/services/gateway_service_test.dart`
  - Analytics persistence: `test/services/analytics_persistence_test.dart`
  - Reminder scheduler: `test/services/reminder_scheduler_service_test.dart`
- Close the session with `flutter clean` and rerun the smoke test runner to ensure no drill artifacts leak into day-to-day development.
