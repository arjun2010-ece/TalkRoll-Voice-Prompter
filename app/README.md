# TalkRoll (Flutter)

Cross-platform TalkRoll: macOS, Windows, iOS, iPadOS, Android. See `../plan/cross-platform-plan.md`.

```sh
flutter pub get
flutter test
flutter run -d macos           # or windows / an iOS or Android device
```

Running on macOS, step by step, with a manual test checklist: `docs/RUN_MACOS.md`.
Windows setup and run instructions: `docs/RUN_WINDOWS.md`.

Native plugins live in `../packages/`: `talkroll_window` (desktop overlay) and `talkroll_camera` (mobile camera).
Set `--dart-define=SENTRY_DSN=...` to enable opt-in crash reporting.
