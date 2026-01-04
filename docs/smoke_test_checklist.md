# Smoke Test Checklist – Week 2 Cut

## 0. Pre-flight

- [ ] (Recommended) Run `powershell -File .\tool\smoke_test_runner.ps1` to execute `flutter clean`, `flutter analyze`, the full unit suite, and targeted gateway/notification/widget specs in one pass. Use `-Skip*` switches to fast-forward through stages you have already validated locally.
- [ ] Review the latest **Nightly Smoke Tests** run in GitHub Actions to confirm the scheduled analyzer/test pipeline was green before starting manual validation.
- [ ] `flutter clean && flutter pub get`
- [ ] `flutterfire configure` (confirm `lib/firebase_options.dart` matches the current Firebase project)
- [ ] `flutter analyze` returns no issues
- [ ] `flutter test` passes

## 1. Authentication & Dashboard

- [ ] Launch the app and sign in with a seeded Firebase Auth test account
- [ ] Landing dashboard shows live group list without manual refresh
- [ ] `/transactions` route is reachable from Wallet quick links
- [ ] Terminate the app, disable Wi-Fi, relaunch, and confirm the cached dashboard/session loads without flashing the Login screen (SecureStorage-backed restore)
- [ ] While offline, verify `AuthWrapper` displays the guided error copy with **Retry** and **Open Login** actions, then re-enable the network and tap **Retry** to proceed
- [ ] (Optional fault injection) Temporarily remove the test user's Firestore profile to confirm the fallback copy appears, logs a warning via `SystemLogService`, and restores once the document is recreated
- [ ] Export `SystemLogService` logs (`systemLogServiceProvider`) and confirm `auth.currentUserProvider` warnings/errors plus `AuthWrapper` info entries are captured for offline and profile-missing scenarios
- [ ] Observe the debug console or analytics stream for `auth_session_retry` / `auth_session_open_login` events when pressing the respective buttons during the fallback flow

## 2. Wallet & Gateways

- [ ] Wallet overview renders available/locked balances plus deposit/payout metrics
- [ ] Quick action tile labels reflect the primary gateway and its environment (e.g., `Telebirr (Sandbox)`)
- [ ] Tap **Deposit funds** and submit ETB 1000 via Telebirr; verify success snackbar and Firestore `transactions` entry with gateway `telebirr`
- [ ] Toggle a gateway flag off in Admin > Feature Flags and confirm it disappears from the wallet dropdown
- [ ] Clear the secure storage entries for Telebirr (`gateway.telebirr.*`) and confirm the Telebirr button surfaces the actionable snackbar with the "View runbook" action instead of a generic failure. Restore the secrets afterwards.
- [ ] Run `flutter test test/ui/group_detail_gateway_test.dart` to ensure the credential guardrails stay deterministic.
- [ ] Run `flutter test test/ui/wallet_screen_test.dart` if UI behavior regresses

## 3. Transaction History Screen

- [ ] Search for the Telebirr transaction; label should display `Telebirr (Sandbox)`
- [ ] Apply the `Pending` filter to isolate provisional payouts
- [ ] Clear filters and export statement (dialog appears, auto-dismisses with snackbar)
- [ ] Run `flutter test test/ui/tx_history_screen_test.dart` for deterministic coverage

## 4. Notifications & Profile Preferences

- [ ] Open Notifications screen; unread reminders stream in and can be marked as read
- [ ] Profile > Notification Preferences allows quiet-hour and lead-time updates that persist (`UserModel.notificationPreferences` changes in Firestore)
- [ ] Muting reminders removes them from the unread badge until unmuted
- [ ] Set quiet hours to cover the current time, insert a Firestore `reminder_jobs` document, and confirm it auto-shifts to the next allowed window (DevTools provider view + `SystemLogService` entry).
- [ ] Set `muteUntil` 24h in the future, trigger another job, and verify no local push surfaces (`SystemLogService` should log a suppression and the reminder should arrive as `read`).
- [ ] `flutter test test/services/reminder_scheduler_service_test.dart` stays green.

## 5. Analytics & Logging

- [ ] Trigger at least one deposit + withdrawal; confirm `AnalyticsService` logs (`flutter run -d chrome` shows structured stdout)
- [ ] Inspect `analyticsServiceProvider` (DevTools > Providers) and ensure `pendingSupabaseExports` captures the new events before calling `drainSupabaseExports` or syncing to Supabase
- [ ] Verify `walletCohortSummaryProvider` and `conversionFunnelProvider` show the expected cohort/stage (e.g., **power** / **loyal**) for the active tester after the wallet actions; `flutter test test/providers/wallet_cohort_summary_test.dart` mirrors the expected logic
- [ ] Check `SystemLogService` output/logs for any repository guard warnings

## 7. Gateway Settlement Automation

- [ ] Seed (or locate) a `bank_transfer` transaction stuck in `pending` for >2 hours, then call `bankSettlementWorkerProvider` via DevTools or run `flutter test test/services/bank_settlement_worker_test.dart`; the worker should flip the status to `success`, append `settlementTimestamp`, and log the reconciliation event.
- [ ] Run `flutter test test/services/gateway_service_test.dart` to validate that secure credential injection still passes and missing secrets throw `GatewayCredentialException`s before reaching live traffic.

## 6. Pre-release Sign-off

- [ ] Update `RELEASE_NOTES.md` with any last-minute fixes
- [ ] Append new accomplishments to `PROGRESS.md`
- [ ] Ensure CI reminders in `CONTRIBUTING.md` (format/test) were followed prior to tagging builds
