# iPad / iPhone testing: camera and prompter findings

Status: findings from an iPad Pro 11" (4th gen, iPadOS 27) test session, 2026-10-27. All fixes are committed on
`mobile-redesign`. **Verified** means the owner confirmed it on the iPad; **not verified** means it compiled and
analysed clean but has not been seen on a device.

Scope: the camera plugin (`packages/talkroll_camera`, iOS Swift), the camera screen
(`app/lib/features/video/record_screen.dart`) and the shared prompter text (`app/lib/features/prompter/`).

---

## 1. Camera preview and recording orientation (iOS, iPadOS)

Commits `8630fb4` (plugin) and `f0eec34` (preview shape). **Verified**: preview upright in landscape and portrait, no
jump when recording starts. **Not verified**: the saved clip's orientation and the back camera.

| Symptom | Cause | Fix |
|---|---|---|
| Landscape preview upside down (180°) on iPad | Capture angle was chosen from fixed angles per `UIDevice.orientation`. The iPad front camera sits on the long edge, so the sensor is mounted differently from an iPhone's | On iOS 17+ the angle comes from `AVCaptureDevice.RotationCoordinator` (`videoRotationAngleForHorizonLevelCapture`, observed so it follows rotation). Older iOS falls back to the screen (interface) orientation, then the device orientation |
| Preview squashed after rotating to portrait and back | The preview box kept the aspect ratio it had when the camera started, but the buffer flips between 16:9 and 9:16 | `record_screen.dart` sizes the box from the current layout orientation (wide in landscape, tall in portrait) |
| Preview jumped about 90° when Record was pressed | In `beginWriter`, `orientationLocked = true` was set **before** `currentAngle()` was read, so it returned the stale `lockedAngle` (default 90 = portrait) | Read the angle first, then lock |

Notes for next time:

- The first guess (use the interface orientation instead of the device orientation) did not fix the upside-down
  image. It is kept only as the pre-iOS 17 fallback. When an orientation bug appears, ask which direction and whether the
  image is also mirrored before changing code.
- `RotationCoordinator` is gravity-based. With the iPad's rotation lock on, the preview can differ from the UI. This was
  not tested.
- Recording locks the angle at the start of a take, so the file has one orientation (the existing design).

## 2. Prompter scroll fell behind the voice on long scripts (all platforms)

Commit `7d6ddcb`. **Verified** with an on-screen readout: measured and drawn text height both 675 px, drift 0 px.

- **Symptom:** in Voice + Camera the highlighted word crept toward the bottom of the panel, and the end of a long script
  was cut off.
- **Cause:** the scroll target comes from `WordLayout` (a `TextPainter` with no text scaling and no inherited style). The
  text on screen is a `Text.rich`, which applies the system text scale and the Material 3 default letter spacing
  (0.25). On the iPad the scale was **1.24**, so the drawn script was 60% taller (1085 vs 675 px, about 35 lines vs 27) and
  the error grew with every line.
- **The iPad's text size looked like the default** in Settings, yet Flutter reported a 1.24 scale. Do not trust the
  setting screen; read `MediaQuery.textScalerOf(context)`.
- **Fix:** `Text.rich(... textScaler: TextScaler.noScaling)` and a non-inheriting root style in `_spans`. The font size is
  an in-app setting, so the prompter now ignores the system text size (it looks about 20% smaller on a device with a
  larger text setting).
- Tap-to-seek uses the same positions, so it was off by the same amount before.
- **How to check for this again:** compare `layout.height + topPad + bottomPad - viewportHeight` with
  `_scroll.position.maxScrollExtent`. If they differ, measured and drawn text disagree.

## 3. Voice mode on the camera screen listens only while recording (iPhone, iPad, Android)

Commit `0ba0f2e`. **Not verified** on a device.

- **Before:** the microphone listened from the moment the screen opened (the reference app does this). Speaking before
  pressing Record scrolled the script and greyed out words, which looked wrong and had no reset.
- **Decision (owner, 2026-10-27):** the script stays at the start until Record. Rehearsal belongs to the Preview on the
  Read screen (`plan/mobile-ux-plan.md`). This is a deliberate difference from the reference.
- **Now:** Voice starts listening when Record is **tapped** (before any 3-2-1 countdown, so the recogniser is warm for the
  first words). Pause, Resume and Stop control it like Normal and Audio modes. The script still appears early on black
  while the camera opens (`_scriptFirst`), without listening.
- **Check on device:** speaking before Record does nothing; the first words after Record are followed, with and without
  the countdown.
- **Open:** "Record again" leaves the script where the last take ended (all modes, not new). A reset to the start would
  be one call (`prompter.restart()`); the owner has not decided.

## 4. Reading guide and progress line on mobile (iPhone, iPad, Android)

Commits `d755c79` and `c5f8c9b`. **Not verified** on a device.

- The reading guide is drawn on desktop only (`settings.readingGuide && !isMobile` in `prompt_surface.dart`). The "Reading
  guide" switch in Text settings is now hidden on mobile too (`prompt_text_controls.dart`). The saved setting is unchanged.
- The progress line (`42% · ~1:35 left`) was missing from the camera screen on every platform; only the Read screen and the
  desktop prompter had it. It now shows under the prompter text there when "Show progress" is on.
  The elapsed time is left out on purpose: the top bar already shows the recording time (`ProgressLine.showElapsed`).
  In portrait it sits above the drag handle (`PromptView.bottomInset`).

## 5. Not covered

- Android was not run for any of the camera orientation work; that fix is iOS-only Swift (Android has its own Kotlin
  plugin and a `quarterTurns` path).
- The Android and macOS behaviour of the text-size fix follows from the shared code but was not tested.
- The uncommitted `project.pbxproj` change (signing team and Xcode format bump) is local to the owner's machine.
