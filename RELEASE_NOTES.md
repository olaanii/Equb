# Release Notes

## Week 2 – Day 10 Cut (2025-12-07)

### Week 2 Highlights

- **Gateway readiness**: Feature-flag driven Telebirr, CBE Birr, and bank transfer configs now expose runtime environments (mock, sandbox, production) and flow through wallet deposit + transaction history UIs with consistent labeling.
- **Reliability guardrails**: Firestore repositories, retry policies, and notification services ship with structured logging plus deterministic unit tests so QA can trace failures without reproducing them manually.
- **Analytics coverage**: Wallet usage metrics, analytics fan-out, and gateway breakdown charts are wired through Riverpod providers, giving product stakeholders visibility into adoption without extra Firestore reads.
- **Notification polish**: Reminder preferences (quiet hours, lead times, mute toggles) persist per user and feed the dashboard/notifications screens via replayable streams.

### Week 2 Testing Summary

- Widget coverage for wallet deposits and transaction history: `test/ui/wallet_screen_test.dart`, `test/ui/tx_history_screen_test.dart`.
- Service/provider coverage: `test/services/firestore_wallet_repository_test.dart`, `test/services/notification_reminder_service_test.dart`, `test/providers/wallet_usage_metrics_test.dart`, `test/providers/notification_providers_test.dart`.
- Please continue to run `flutter test` and `flutter analyze` before tagging releases.

### Week 2 Known Follow-ups

- Bank transfer adapter still uses manual settlement copy; productionization will happen in Week 3 alongside real credentials.
- CI integration remains manual (see `CONTRIBUTING.md` checklist) until GitHub Actions is wired up.

## Week 3 – QA Automation Cut (2025-12-12)

### QA Automation Highlights

- Added `tool/smoke_test_runner.ps1`, a PowerShell harness that runs `flutter clean`, `flutter analyze`, the entire unit suite, and the high-signal targeted specs (wallet, transaction history, gateway guardrails, settlement worker, reminder scheduler) with a single command plus skip switches for faster iteration.
- Documented the runner in both `README.md` and `docs/smoke_test_checklist.md`, turning the manual pre-flight into a reproducible checklist for QA and release managers.
- Introduced the GitHub Actions workflow **Nightly Smoke Tests** (`.github/workflows/nightly-smoke.yml`), which runs nightly at 02:00 UTC (and on-demand) to execute `flutter analyze`, `flutter test`, and the targeted suites while uploading analyzer/test logs as artifacts for release managers.

### QA Automation Testing Summary

- `powershell -File .\tool\smoke_test_runner.ps1` now encapsulates the required analyzer/test cadence; use `-SkipClean`, `-SkipAnalyze`, `-SkipUnit`, or `-SkipTargeted` for incremental runs.
- Targeted suites exercised by the runner: `wallet_screen_test.dart`, `tx_history_screen_test.dart`, `group_detail_gateway_test.dart`, `bank_settlement_worker_test.dart`, `reminder_scheduler_service_test.dart`, `analytics_persistence_test.dart`, `wallet_cohort_summary_test.dart`.
- GitHub Actions mirrors the same cadence nightly and publishes analyzer/test logs as `nightly-smoke-logs` artifacts in each run.

### QA Automation Follow-ups

- Expand CI coverage with emulator-based integration (Android/iOS) smoke tests to exercise push notifications and gateway UX end-to-end.
- Attach the telemetry drill log exports as additional workflow artifacts so QA can reference them alongside analyzer/test outputs.
