# Contributing Guide

Thanks for helping build the Equb app! Please keep the following guardrails in mind so Week 3+ work lands smoothly.

## 1. Workflow Basics

- Fork or branch from `main` (feature branches should follow `feature/<topic>` naming)
- Prefer small, reviewable PRs tied to a single day in `PROGRESS.md`
- Reference the relevant smoke-test step or release note item inside your PR description

## 2. Local Environment

- Keep Flutter at 3.24+ and Dart at 3.5+
- Run `flutterfire configure` whenever Firebase projects change (updates `lib/firebase_options.dart`)
- Supabase keys live in `config/supabase_config.dart`; do not commit secrets

## 3. CI / Pre-Push Checklist

Run the following before pushing:

```powershell
flutter pub get
flutter analyze
flutter test
dart format lib test --output=none --set-exit-if-changed
```

Additional expectations:

- Widget tests (`test/ui/*.dart`) should cover new UI states or data plumbing
- Update `RELEASE_NOTES.md` and `PROGRESS.md` with the day’s deliverables
- Record manual validation steps in `docs/smoke_test_checklist.md` if the flow is new

## 4. Code Style & Docs

- Prefer Riverpod providers over manual `InheritedWidget` plumbing
- Add succinct comments only for non-obvious logic (retry math, gateway adapters, etc.)
- Keep README sections updated when introducing new services or UX flows

## 5. Support

Ping the maintainer via GitHub Issues for clarifications or drop questions in the team chat channel labeled `#equb-release`.
