# Architecture notes (Phase 0)

Short map of the Flutter app (`app/`) for the signature-features work. The Swift app in `Sources/` is legacy and untouched. Windows is dropped.

## Layout

- `lib/core/`: pure Dart. `script/` (saved script, section markers `[Name]`, cleaning, reading time), `settings/` (`PromptSettings`, `PromptControlMode`, labels), `matching/script_tracker.dart` (the conservative word matcher), `progress/`, `entitlements/`, `shortcuts/`.
- `lib/features/`: UI by area: `studio` (macOS Script Studio, start options, script list), `read` (mobile reading screen and settings), `prompter` (controller, macOS prompter window, prompt surface), `video` (mobile camera and recording), `onboarding`, `pro` (paywall), `settings`, `menu`.
- `lib/services/`: `speech` (native recognizer channel), `audio` (reference clock, input), `camera`, `storage` (script library, file IO), `purchases`, `permissions`, `window`, `providers.dart` (Riverpod wiring).
- Local packages: `packages/echoprompter_window`, `packages/echoprompter_camera`. Native code: `macos/Runner`, `ios/Runner`, `android/`.
- State management: Riverpod (`flutter_riverpod`). Settings are in `settingsProvider`; prompter state is in `prompterProvider` (`prompter_controller.dart`).

## Modes

- `enum PromptControlMode { normal, voice, recordedAudio }` in `lib/core/settings/prompt_settings.dart`. These values are persisted, so they never change.
- User-facing names live in one place: `lib/core/settings/labels.dart` (`autoScrollModeName`, `voiceModeName`, `narrationModeName`, plus `label`, `explanation`, `headerName`). Normal → **Auto-scroll**, Audio/Recorded audio → **Narration** (done in 0.1).
- `PrompterController` owns how each mode tracks position: Auto-scroll is timer-based; Voice listens through the native recognizer and matches words with `ScriptTracker`; Narration plays the chosen file through `ReferenceClock`. Apple (macOS/iOS/iPadOS) transcribes it on device to time each word; Android finds where the speaker pauses (no recogniser, no microphone permission) and times the script between those pauses (`alignScript` in `core/narration/alignment.dart`).

## Sections

`lib/core/script/sections.dart`: a line holding only `[Name]` is a section marker. It is shown as a divider on the prompter, never read, and does not shift word indexes. Action cues (Phase 1) need their own marker syntax, still to be proposed.

## Camera and recording

`features/video/record_screen.dart` and `camera_state.dart`, over `echoprompter_camera`. Mobile only. macOS does not record.

## Paywall and limits

`core/entitlements/entitlements.dart` (seam, payments switches `PAYMENTS_APPLE` / `PAYMENTS_ANDROID`), `features/pro/*` (paywall dialog, upgrade prompts, purchase actions), `services/purchases/*`. Free-script limit and persistence are described in `docs/free-script-limit-persistence.md`.

## Storage

Scripts: `services/storage/script_library.dart` and `script_io.dart`. Settings: `shared_preferences`.

## Notes for the next phases

- Keep "EchoPrompter" out of new strings; add a display-name constant before Phase 1 so the Phase 5 rename is quick.
- No new dependency with native code without asking.
