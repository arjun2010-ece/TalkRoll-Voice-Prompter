# EchoPrompter: Feature Handover

**For:** Claude Code, working in the existing EchoPrompter Flutter codebase
**From:** Arjun (product owner)
**Last updated:** 2026-11-01.

---

## 0. Read this first

EchoPrompter is an existing Flutter teleprompter app. It targets macOS first, plus iOS, iPadOS and Android from the same codebase. Today it has three reading modes:

- **Normal** (renamed **Auto-scroll**, see section 0.1): constant-speed scrolling. Never uses the camera or microphone.
- **Voice:** follows the reader's live speech through the microphone.
- **Audio** (renamed **Narration**, see section 0.1): follows a pre-recorded audio file. Today the file plays on speakers and the microphone listens to it.

Mobile and tablet add **camera recording** (front or back) in Voice and Narration modes. **macOS does not record anything:** users record their screen with other tools (OBS, QuickTime, ScreenFlow) while EchoPrompter prompts them. The macOS prompter (notch/corner) is hidden from screen sharing and recording. The app already has a script library with sections ("Insert Section", already shown as cues in the prompter), reading settings, settings, and a Pro paywall with existing paywall popups.

### What we're building, in one picture

Every platform gets the same three independent choices:

| Choice | Options |
|---|---|
| **What moves the prompter** | Auto-scroll (speed) · Voice (your speech) · Narration (playback time of a recorded file) |
| **How you run the script** | Whole script (today's behaviour) · Section by section (stop after each section; Retake, Next, jump to any section) |
| **What's in the script** | Text, sections (spoken, already exist) and **action cues** (new: never spoken, can hold the prompter) |

Platform differences:

- **Mobile/tablet** records the camera. Section by section produces one clip per section, and the export joins the final clips.
- **macOS** doesn't record. Section by section plays a **retake "clap"** (sound and/or flash) that the user's screen recorder captures, and keeps a simple **take list**.

**Positioning:** most teleprompters are one long scroll that follows your voice. EchoPrompter directs the recording: what to say, what to do, and when to stop and redo. "Record in sections, not in one breath." Main uses: on-camera videos on mobile, and faceless screencasts and tutorials on Mac (narration plus on-screen actions).

### How to work

1. **Explore before changing anything.** Map the project structure, state management, routing, how scripts and sections are stored, how each mode tracks position, how camera recording works, how the paywall and free limits are implemented, and which platform channels and native code exist (`ios/`, `macos/`, `android/`). Write a summary in `docs/architecture-notes.md` and check it with me before starting Phase 1.
2. **Extend, don't rewrite.** Reuse the existing reading engine, script model, design tokens, components and paywall popups. New UI must match the existing v3 design (mode chip, "How to read" sheet, camera screens) in dark and light themes.
3. **Code style:** use `async`/`await`, never `.then()`/`.catch()` chains, with one consistent pattern throughout. Indent properly and follow the repo's lint rules.
4. **Everything runs on-device.** No server transcription, no uploading audio, video or scripts.
5. **Work in phases** (section 9). Finish each phase with tests before starting the next. Ask before adding any dependency with native code.
6. Items marked **❓** are decisions for me. Don't guess: stub behind a flag and ask.

---

## 0.1 First change: rename the modes

**Do this first, right after exploring the repo and before any other change.** The rest of this file uses the new names.

| Old name (today) | New name | What it does |
|---|---|---|
| Normal | **Auto-scroll** | Scrolls at a set speed |
| Voice | **Voice** (unchanged) | Follows the user's live speech |
| Audio | **Narration** | Follows a pre-recorded narration file; the user doesn't speak |

The mode chip reads **Auto-scroll · Voice · Narration**.

### Rules

- **User-facing text only:** mode chip, "How to read" / start options sheet, prompter UI, settings, paywall, permission explainers and purpose strings, error and empty states (e.g. "Audio · no recording" → "Narration · no recording"), the demo script, onboarding, tooltips, accessibility labels, localization files, and `web/` marketing copy if it names the modes.
- **Keep internal identifiers unchanged:** enum values, stored keys and saved data (e.g. `normal`, `audio`) stay as they are, so existing scripts, settings and preferences keep working with no migration. Renaming Dart classes or files is optional and not worth risk. If you do rename code symbols, never change persisted values.
- **"Audio" as a generic word stays** where it really means audio: "audio file", "choose a recording", "audio permission" and so on. Only the **mode name** changes.
- Keep mode names in one place (localization keys/constants) so they're easy to change again.
- Copy hint for Narration: "Plays your recorded narration and keeps the script in step. You don't speak."

### Acceptance criteria

- No user-visible "Normal" or "Audio" mode label remains on any platform, in light or dark theme.
- Existing users' scripts and settings, including their last-used mode, load correctly after the update.
- `flutter analyze` is clean and existing tests pass (update tests that assert on the old labels).

---

## 1. Narration mode: scroll by playback time

**Platforms:** macOS, iOS, iPadOS, Android.

Narration mode uses **only audio files the user imports** (m4a, mp3, wav, aac; the audio track of a video file if easy). The audio can come from anywhere: the user's own recording or any outside text-to-speech tool. **EchoPrompter has no built-in text-to-speech.**

### How it works

1. **Import:** copy the file into app storage and link it to the script.
2. **Transcribe once, on-device, with word timings.** Cache the result per (file hash, script id) so it never runs twice. Show progress, and allow cancel.
   - **iOS / iPadOS / macOS:** Apple's speech framework through a platform channel. Prefer `SpeechAnalyzer` / `SpeechTranscriber` where the OS supports it, and fall back to `SFSpeechRecognizer` with `SFSpeechURLRecognitionRequest` and `requiresOnDeviceRecognition = true`. Word times come from each segment's `timestamp` and `duration`. Check the app's minimum OS versions and choose the path at runtime. Process long files in chunks if needed.
   - **Android (required at launch):** the platform `SpeechRecognizer` doesn't reliably transcribe files with timings, so use an on-device engine (for example whisper.cpp through a maintained Flutter binding with word timestamps). Compare the options' app-size impact, speed on a mid-range phone, accuracy and licence, recommend one, and get my approval before adding it. If the model is large, download it once on first use of Narration mode (with progress and a clear size notice) instead of bundling it.
3. **Align the transcript with the script.** Normalize both sides (lowercase, strip punctuation, expand numbers where practical). Run a token-level sequence alignment (Needleman–Wunsch or similar). Interpolate times for unmatched script words from their neighbours. **Exclude action cues and section titles from alignment** (they're never spoken). Store the result as an `AlignmentMap` (script word index → time).
4. **Scroll by playback time:** look up the current playback position in the `AlignmentMap` and drive the existing scroll engine from it. **Do not use the microphone in Narration mode.** Pause, resume, seek (including "back 5 seconds") and the existing speed control must stay in sync.
5. **Sync offset:** a small setting (±500 ms) for Bluetooth headphone latency. Remember it per output device if possible.
6. **Low match:** if under about 70% of script words matched, show "This recording doesn't seem to match this script," with *Continue anyway* (interpolated timing) or *Choose another file*. Reuse or replace the existing "recording cannot be read" state.

### Copy changes

Remove "Play the audio on your speakers, not a headset, so the microphone can hear it" everywhere. Narration mode now works with headphones, with the volume down and in silence. Add the transcribing/progress state.

### Not in scope (decided)

No ahead/behind indicator. No lip-sync features. No microphone listening in Narration mode.

### Acceptance criteria

- The script stays in sync (within about 1 word) with playback, including after pause, seek and speed changes.
- The transcript is cached, so reopening the script doesn't transcribe again.
- No network use (test in airplane mode).
- Low-match, permission-denied and unsupported-device states are handled.
- It cover normalization, alignment, interpolation (skipped and extra words), and that cues and section titles are excluded.

---

## 2. Run styles: whole script or section by section

**Platforms:** all. **Modes:** Auto-scroll, Voice, Narration.

A **Run** choice on the start options / "How to read" sheet: **Whole script** (today's behaviour, unchanged) or **Section by section**.

### Section by section

- The prompter plays one section at a time and **always stops at the end of the section and waits** (no auto-continue). It shows a clear end-of-section state: **"Section 3 done · Retake · Next · Sections…"**
  - **Retake:** go back to the start of this section and run it again.
  - **Next:** continue to the next section.
  - **Sections…:** open the section list and jump to any section.
- The user can also jump to any section before starting.
- **Auto-scroll mode:** scrolls the section at the set speed, then stops.
- **Voice mode:** follows speech within the section, then stops.
- **Narration mode:** plays only that section's part of the audio (from the `AlignmentMap`), then stops the audio. Retake replays from the section's start time. Jumping seeks the audio to that section.
- A script with no sections behaves as one section.
- **macOS:** every control has a **global hotkey** (works while VS Code, a browser or a terminal is the active app): Next, Retake, Pause/Resume, Back 5 seconds, Open sections, Continue (for hold cues, see section 3). Extend the existing Shortcuts settings, with conflict detection like today.
- **Mobile:** large on-screen buttons; the existing remote/keyboard handling if any.

### Acceptance criteria

- In all three modes, the prompter stops at every section end and Retake/Next/jump behave as described.
- Global hotkeys work on macOS while another app is in focus.
- Whole-script runs behave exactly as before.

---

## 3. Action cues

**Platforms:** all. **Modes:** Auto-scroll, Voice, Narration.

A new kind of item in the script, **separate from sections**, for things the user must **do**, not say: "click Submit", "type `npm run dev`", "switch to the browser", "hold the product up to the camera".

### Rules

- **Never spoken, never matched by speech recognition, never highlighted as read text, excluded from alignment and word counts.**
- **Shown in a distinct style**: a chip or side lane, clearly different from narration and from section cues. Never mixed into the reading line.
- **Anchored to a position in the text** (between two words).
- **Heads-up:** a "Next up" preview appears before the cue becomes active, e.g. "In 3s: click Submit".
  - Narration mode: exactly N seconds before (default 3 s, setting 1–5 s), from the `AlignmentMap`.
  - Auto-scroll mode: from scroll speed. Voice mode: estimated from the current reading pace, at least about one line ahead.
- **Active:** when the prompter reaches the cue, it's emphasized until the next text starts.
- **Hold (optional, per cue):** when the prompter reaches a hold cue, it **waits until the user presses Continue** (button, tap or global hotkey on macOS).
  - Auto-scroll: scrolling stops. Voice: scrolling stops and speech is ignored until Continue. Narration: **the audio pauses** and resumes on Continue.
  - Use this for actions that take unpredictable time: installs, page loads, builds.
- **Editor:** "Insert Action Cue" next to the existing "Insert Section", with a text field and a Hold toggle. Cues can be edited, moved and deleted.
- **Storage:** inspect how scripts are stored today and propose a serialization that fits (ideally a structured element, not magic text the user could type by accident). Existing scripts must load unchanged. Check the proposal with me before implementing.

### Acceptance criteria

- Cues never affect voice following or audio alignment (tested with a script dense with cues).
- Heads-up and hold work in all three modes. In Narration mode the audio pauses and resumes exactly at the hold point.
- Old scripts load unchanged, and scripts with cues round-trip without loss.

---

## 4. Mobile recording: section clips and export

**Platforms:** iOS, iPadOS, Android. **Modes:** Voice and Narration (with camera on). Front or back camera, as today.

The user chooses the run style:

- **Whole script:** one continuous recording, as today.
- **Section by section:** **each section is recorded as its own clip.** Recording starts when the section starts (keep or reuse the existing countdown) and stops automatically at the section end.
  - **Retake** records a new clip for that section, which **replaces** the previous one as the keeper. Keep earlier attempts until the session is exported or discarded, in case of undo.
  - **Next** keeps the clip and moves on. **Jump** to any section is allowed. Clips are always assembled in **section order**, whatever order they were recorded in.
  - **No retake clap on mobile.** The app knows which clip is the keeper, so no manual editing is needed.

### Export

- **Finished video:** the keeper clips joined in section order. If some sections have no clip, warn ("Sections 2 and 4 have no take") and offer to export without them.
- **Separate clips:** each keeper clip as its own file, for people who edit in CapCut, Final Cut and similar.
- Save to Photos/gallery (existing flow) and the share sheet.
- Joins between takes will show as jump cuts. That's expected; no smoothing needed.
- iOS/iPadOS: native `AVMutableComposition` and `AVAssetExportSession` through a platform channel. Android: Media3 Transformer. Don't use abandoned FFmpeg wrappers.

### Narration mode with the camera

- Intended for footage where the user **is not speaking**: hands-on demos with the back camera (unboxing, cooking, setting up a device), or the front camera for reactions, pointing, holding things up to the lens, makeup or fitness demonstrations.
- **Soundtrack:** the exported video **always uses the imported narration audio** (each clip gets its section's part of the narration). **The microphone is never recorded in Narration mode, and there's no option for it.** The purpose of Narration mode is that the user doesn't speak; the pre-recorded voice is the soundtrack.
- So Narration mode with the camera needs **camera permission only, no microphone permission**. Update the permission flows to match.
- Headphones are optional; the narration can play on the speaker, since nothing is recorded from the mic.

### Data model (adapt to the repo's existing models and storage)

```text
RecordingSession { id, scriptId, createdAt, mode (voice|audio), runStyle (whole|sections), camera (front|back) }
Clip             { id, sessionId, sectionId?, file, durationMs, attempt, isKeeper, createdAt }
```

Deleting a script asks whether to delete its recordings too.

### Acceptance criteria

- A 4-section script recorded section by section produces 4 keeper clips. Retaking section 3 replaces only section 3's keeper.
- The finished export has the sections in order, with no black frames or audio gaps at the joins.
- Narration-mode exports use the correct part of the narration for each clip.
- Works in portrait and landscape, front and back camera, phone and tablet, and handles the existing storage-full and interruption states for each clip.
- Tests cover keeper selection, section ordering and the "missing sections" warning.

---

## 5. macOS: retake clap and take list

**Platform:** macOS only. **Modes:** Auto-scroll, Voice, Narration.

The Mac app doesn't record, so when someone retakes a section their screen recorder (OBS etc.) captures every attempt. EchoPrompter helps them find the cut points.

### Retake clap

- Fires **at the start of each section** in section-by-section runs, and **every time Retake is pressed**. In whole-script runs, it fires once at the start.
- Setting: **Sound / Flash / Both / Off**, default **Both**.
  - **Sound:** a short, distinctive beep, easy to spot in an audio waveform. It's only captured if the recorder records system audio, or the mic hears the speakers.
  - **Flash:** a brief visual marker (about 200 ms) in a small separate window that is **not** hidden from screen capture (unlike the prompter), so every screen recorder captures it. Position: a screen corner (setting).
- Explain this in settings in one line: "Helps you find retakes when editing your recording."

### Take list

- Records, for each run, the sections and how many attempts each had.
- **Copy** or **share** it as plain text:
  ```text
  Section 1 · Intro ........ 1 attempt
  Section 2 · Setup ........ 3 attempts (keep the last)
  Section 3 · Deploy ....... 2 attempts (keep the last)
  ```
- The rule shown to users: **the last attempt of each section is the keeper.**

### Acceptance criteria

- The flash appears in recordings made with QuickTime and OBS, while the prompter stays hidden.
- The beep and flash fire at each section start and each retake, and respect the setting.
- The take list matches what happened in the run.

---

## 6. Free tier and paywall

**Every feature is unlocked for free users.** The limits are about how much they use it. **No watermark.**

| Limit | Value |
|---|---|
| Scripts | 5 |
| Words per script | 800 (action cues and section titles don't count) |
| Changes after reaching 5 scripts | **A shared pool of 15 free changes in total** |
| After that | The existing paywall popup |

### What uses a "change" (only once the user has 5 scripts)

- **A big rewrite:** saving a script where **more than 60% of its words** changed compared with the last saved version (word-level diff). Smaller edits, typo fixes and added lines are always free and unlimited.
- **Replacing a script:** deleting a script and then creating a new one.

### Rules

- **Never lock the user's content.** At any limit, scripts stay readable, usable in the prompter, copyable and deletable. Only the blocked action (saving a big rewrite, creating a script, going over 800 words) opens the paywall popup.
- Show limits **before** they're hit: "612 / 800 words" in the editor, "3 free changes left", and a warning before saving a change that would use one.
- **Persist the counters across delete and reinstall:** the Keychain on iOS and macOS, Android Block Store or backup. Best effort is fine.
- **The bundled demo script** stays within the limits and doesn't count towards any of them.
- Update the existing designs and copy that mention a 20-script limit.
- Paywall (Guideline 3.1): In-App Purchase only, **Restore Purchases**, price and billing period clearly shown, links to Terms and Privacy. Call it "Free: 5 scripts, up to 800 words each", never a "trial" unless it's time-limited.
- Pro removes all limits.

### Acceptance criteria

- Check for the 60% word-diff rule (edge cases: reordering, empty script, script with only cues), the pool counter, and delete-then-create.
- Counters survive an app reinstall on iOS and macOS.
- No content is ever inaccessible because of a limit.

---

## 7. App Review cleanup (Phase 0)

- **Demo content:** the demo script contains placeholder copy ("Brightside sorts it into today…"). Replace it with real copy explaining EchoPrompter, showing sections and at least two action cues (one with hold). Search the repo for any other placeholder or lorem text.
- **Bundled sample audio:** ship a short sample recording (about 20–30 s) that matches the demo script, so a reviewer can try Narration mode instantly. Arjun provides the final recording. Until then, use a placeholder file from any source, marked `TODO(arjun): replace sample audio`.
- **"Hidden from screen recording": remove it from iOS, iPadOS and Android (decided).** Mobile records the camera, never the phone's screen, so the prompter can't appear in mobile videos anyway. The option is unnecessary there, and iOS can't reliably back the claim. Remove the setting, its copy (e.g. in "More text options") and any related code on mobile. **Keep it unchanged on macOS.**
- **Permission strings:** clear, specific purpose strings for camera, microphone, speech recognition, Photos (add-only), and anything new on macOS. Example: "EchoPrompter uses speech recognition on your device to follow your voice and to sync your script to an audio recording."
- **Permission explainer screens:** the button says "Continue" (not "Allow") and leads straight to the system prompt.
- **Competitor names:** none anywhere in the app, strings, metadata or assets.
- **Review notes:** create `docs/app-review-notes.md` with a short walkthrough for the reviewer: open the demo script → Section by section → Narration mode with the sample → reach a hold cue → Continue → Retake a section → (mobile) export the finished video.

---

## 8. Removed or deferred (don't build)

**Removed:**
- Built-in text-to-speech
- Take review reports and Memorize mode
- Ahead/behind indicator and any lip-sync features
- Watermarks
- Chapter markers for Final Cut or Premiere
- Retake clap on mobile

**Future scope (not now):**
- Built-in screen recording on macOS (ScreenCaptureKit, excluding the prompter window), giving Mac real section clips and export
- Mac meeting companion (auto-show a script when Zoom or Teams opens; talking-point checklists)
- Native extras: App Intents/Shortcuts, Live Activity, Apple Watch remote, Continuity Camera, external display output

---

## 9. Phases

| Phase | Scope |
|---|---|
| **0** | Explore the repo and write `docs/architecture-notes.md`. **Then, as the first change: rename the modes (section 0.1).** Then the App Review cleanup (section 7) and the action-cue storage proposal. |
| **1** | Action cues (section 3) and run styles (section 2) in Auto-scroll and Voice modes, all platforms, including macOS global hotkeys. |
| **2** | Narration mode by playback time (section 1), then run styles and cues in Narration mode, including hold pausing the audio. |
| **3** | Mobile section clips and export (section 4). macOS retake clap and take list (section 5). |
| **4** | Free tier and paywall (section 6). Final review pass (section 10). |
| **5** | **Rename the app** (section 12). Start only after phases 0–4 are done, and only once Arjun gives the new name. |

All phases, including Android Narration mode, are needed before launch.

**Prepare for the rename while building:** don't hard-code "EchoPrompter" in new code. Put the display name in one place (a constant and the localization files) and use that everywhere new, so phase 5 is quick.

---

## 10. Definition of done (every phase)

- Works on every platform in the feature's scope, in light and dark themes, portrait and landscape.
- All new states are handled: permission denied, unsupported device, low match, no section takes, storage full, interruption (phone call), app going to the background.
- Check for the logic (alignment, cue exclusion, section stops, keeper ordering, word diff, counters). Widget tests for new screens where the repo already does widget testing.
- No network use in any new feature.
- `flutter analyze` is clean, and existing tests pass.
- A short entry per phase in the repo's changelog.

---

## 11. Decisions settled

1. Android Narration mode (on-device file transcription) **is required at launch**.
2. Narration mode with the camera **always exports the narration audio**. No microphone recording, no option for it.
3. Arjun provides the final sample audio recording for the demo script. A placeholder is used until then.
4. "Hidden from screen recording" is **removed from mobile** and kept on macOS.
5. The app will be **renamed** (an iOS teleprompter called "EchoPrompt" already exists). That's phase 5, after all features.

## 12. Phase 5: rename the app (after phases 0–4, when Arjun gives the name)

Don't start until Arjun confirms the new name. Then:

- **Change the display name** on every platform: iOS/iPadOS `CFBundleDisplayName`/`CFBundleName`, macOS app name and menu bar items, Android `android:label`, window titles, the About screen, onboarding, the paywall, permission purpose strings, review notes, the demo script, and the localization files.
- **Keep the bundle identifiers / application IDs unchanged** unless Arjun says otherwise. Changing them would create a new app on the stores and break updates.
- Replace the app icon and assets only when Arjun provides them.
- Rename user-visible file names and export names (e.g. exported video file names, take-list headers) to the new name.
- Search the whole repo, including `web/` (the Next.js marketing site), for leftover mentions of the old name and list any that need Arjun's decision (domains, social handles, legal pages).
- Don't rename Dart packages, folders or classes unless asked. That's internal and not worth the risk.

---

## Cross-platform fixes pending

Fixed on iOS and iPadOS in the Narration-with-camera work. The three entries below are now also fixed on Android. macOS does not record, so it is not affected.

### Narration video had no narration audio
- **Fixed on:** iOS and iPadOS (`packages/echoprompter_camera/ios/.../EchoprompterCameraPlugin.swift`, `NarrationMux.swift`, `packages/echoprompter_camera/lib/echoprompter_camera.dart`, `app/lib/features/video/record_screen.dart`, `app/lib/features/prompter/prompter_controller.dart`) and Android (`packages/echoprompter_camera/android/.../EchoprompterCameraPlugin.kt`, `NarrationMux.kt`, `app/lib/features/video/record_screen.dart`)
- **Also affects:** none left (macOS does not record)
- **Issue:** Record a take in Narration mode with the camera. With headphones, the volume down or silent mode, the saved video has only background noise instead of the narration.
- **Root cause:** The video's audio track was the microphone, which only heard the narration through the speaker.
- **Fix applied (iOS):** The take is filmed without the microphone. The Record screen reports the narration's playback position every 50 ms (`EchoPrompterCamera.narrationTick`), the camera notes which parts of the file played, and when the take stops `NarrationMux` puts those parts into the video (AAC soundtrack, picture copied without re-encoding). The audio session is set to playback only.
- **Root cause on Android (same as iOS):** `Recorder` in `EchoprompterCameraPlugin.kt` always ran an AAC codec fed by `AudioRecord` (`MediaRecorder.AudioSource.MIC`). In Narration mode Dart asked for the built-in microphone (`setHeadsetInput(false)`) and played the narration on the speaker (`setReferenceRoute` does nothing on Android), so the take recorded the speaker.
- **Fix applied (Android):** A Narration take starts no `AudioRecord` and the `Recorder` runs video-only (`withAudio = false`). `startRecording` receives the narration file and `narrationTick` (the same 50 ms playback reports as iOS) lets `Recorder` note which parts of the file played, on the take's own timeline, cut at the first video frame. When the take stops, `NarrationMux.kt` runs on a background thread: it decodes those parts with `MediaExtractor` and `MediaCodec`, puts silence between them, encodes AAC at the file's own sample rate, and joins that with the untouched video samples through `MediaMuxer` (platform APIs only, no new dependency). If that fails, or the narration never played, the result carries `narrationFailed` and the take is kept as filmed. The Dart side only widened `Platform.isIOS` to `Platform.isIOS || Platform.isAndroid` in `_toggleRecord`.
- **Verified:** On the Android emulator (API 37) with the volume at maximum and at 0 (muted), the saved video has the narration clearly present both times (same level as the file; per-window correlation 0.5 to 0.95). The narration sits at a steady offset from the video's start, from 220 ms early to 90 ms late depending on the take, because it starts playing a little before or after the first camera frame. A take with a pause and resume stays continuous. An interrupted take (Home) is joined and saved as well. Voice mode takes still record the microphone, and a normal stop is unchanged.
- **Status:** Done (fixed on iOS, iPadOS and Android)

### Narration with the camera asked for the microphone
- **Fixed on:** iOS and iPadOS (`app/lib/features/video/record_screen.dart`) and Android (`app/lib/features/video/record_screen.dart`, `packages/echoprompter_camera/android/.../EchoprompterCameraPlugin.kt`, `RecordingService.kt`)
- **Also affects:** none left (macOS does not record)
- **Issue:** Start Narration with the camera. The permission card and the system prompt ask for the microphone even though the take does not need it.
- **Root cause:** The camera screen asked for camera and microphone for every mode.
- **Fix applied (iOS):** `_needsMic(mode)` is false for Narration on iOS, so only the camera is asked for, the card says the microphone is not used, and switching to Voice on the camera screen asks for the microphone then (`_askMicIfNeeded`).
- **Fix applied (Android):** `_needsMic(mode)` is now false for Narration on Android too (`Platform.isIOS || Platform.isAndroid`). That alone made the app crash when recording: `RecordingService` always started its foreground service with the `microphone` type, and Android refuses that without the microphone permission (`SecurityException: Starting FGS with type microphone ... requires ... RECORD_AUDIO`). So `startRecording` now passes `withMic` (false for a Narration take) to `RecordingService`, which asks for the `camera` type only in that case. Voice takes still start it with `camera|microphone`.
- **Verified (Android emulator, API 37, permissions reset before each run):** (1) Narration with the camera asks for the camera only, and the card says the microphone is not used; (2) switching to Voice on the camera screen then asks for the microphone; (3) Voice with the camera from the start asks for both, as before; (4) a Narration take with the microphone never granted saves with the narration in it (the audio matches the file, silent during the hold cue, and picks up after Continue). A Voice take afterwards saved normally with the `camera|microphone` service.
- **Status:** Done (fixed on iOS, iPadOS and Android)

### Message when the narration could not be added, and the camera hint
- **Fixed on:** iOS and iPadOS (`EchoprompterCameraPlugin.swift`, `record_screen.dart`, `echoprompter_camera.dart`) and Android (`EchoprompterCameraPlugin.kt`, `record_screen.dart`)
- **Also affects:** none left (macOS does not record)
- **Issue:** If the narration cannot be put into the video (or never played during the take), the reader should be told, not given a video without sound.
- **Fix applied (iOS):** `stopRecording` and the interrupted/storage-full event carry `narrationFailed`. The camera screen then deletes the file and shows "Narration wasn't added ... Please record the take again." with Record again (a snackbar when a mode change saves the take). The hint under the preview says the narration is added from its file.
- **Fix applied (Android):** The Dart side is shared (`RecordingResult.narrationFailed`, `_onStopped`, `_endTake`). Android's `finishRecording` now returns `narrationFailed` in the `stopRecording` result and in the interrupted/storage-full event. The hint under the preview now shows the same "added from its file" text on both platforms.
- **Status:** Done (fixed on iOS, iPadOS and Android)

### Found while testing, not fixed yet
These were seen while testing the work above. None of them were part of it, so nothing was changed. Each says which platform needs fixing.

#### "Saved to your gallery" is shown even when the save failed
- **Fixed on:** Android (`app/lib/features/video/record_screen.dart`, `packages/echoprompter_camera/android/.../EchoprompterCameraPlugin.kt`) and iOS (the same shared Dart change in `record_screen.dart`; no native change).
- **Also affects:** iPadOS (same code as iPhone, not tried on an iPad). macOS is not affected: it has no camera plugin and does not record.
- **Issue:** Record a take and stop it when the gallery cannot take the video (for example Photos access refused on iOS, or no space on Android). The camera screen still said "Saved to your gallery" (and "What you recorded was saved" after an interruption), and the take was lost from the reader's point of view.
- **Root cause:** `_onStopped` and `_endTake` in `record_screen.dart` called `EchoPrompterCamera.saveToGallery(r.path)` inside `try { ... } catch (_) {}`, so the error the native side returns was thrown away and the card was shown anyway. iOS reports it as a `FlutterError` (`permission` or `save`); Android throws from `saveToGallery` (MediaStore insert or copy). Android also left an empty or partial gallery entry behind when the copy failed.
- **Fix applied:** One `_saveToGallery(r)` helper in `record_screen.dart` returns whether the save worked. `_onStopped` shows the "Saved" card (or the interruption card) only when it did. Otherwise it shows a "Couldn't save to your gallery" card with the take kept, **Try again** and **Share** (`_unsaved`, `_retrySave`); a successful retry turns into the normal saved card. `_endTake` (mode change) shows a snackbar with Try again, then Share if the retry fails too. Android only: `saveToGallery` in the plugin deletes the half-written MediaStore row on failure and throws an `IOException` instead of a null-pointer error. iOS native code already returned the errors, so it is unchanged.
- **Verified (Android emulator, API 37):** with a forced write failure, a stopped take shows the error card, the file stays in app storage and nothing is added to the gallery; Try again while still failing keeps the card; after the failure is removed, Try again saves it and shows "Saved to your gallery". A normal take still shows "Saved to your gallery". The mode-change snackbar shows "Couldn't save…" with Try again, then "Still couldn't save…" with Share. The test-only failure code was removed afterwards.
- **Verified (iPhone 15 Pro Max, debug build, Narration + camera, a 9 s recording):** take 1 shows the heads-up (`next=0`, "Next ⏸ Click Submit · Hold" in the status line) and holds at the cue ("Holding at cue" + Continue in the controls). (a) Continue, run to the end, save, Record again: take 2 shows the heads-up and holds again. (b) Stop take 1 in the middle of the hold, Record again: take 2 shows the heads-up and holds again.
- **Photos refused (iOS only):** `_saveToGallery` returns `saved`, `photosOff` (a `PlatformException` with code `permission`, which only the iOS plugin sends) or `failed`. Android never sends that code, so its cards are unchanged. The mode-change snackbar shows the same advice with Share.
- **Status:** Done on Android and iPhone. iPadOS not tried (same code).

#### Camera screen does not notice a permission turned on in Settings
- **Fixed on:** Android (`app/lib/features/video/record_screen.dart`). The new code runs only when `Platform.isAndroid`, so iOS behaves as before (it restarts the app when a permission is changed in Settings, so it does not show there).
- **Also affects:** none (iOS restarts the app; macOS does not record)
- **Issue:** Open the camera screen with the camera or microphone refused, tap Open settings, turn the permission on and come back. The "... access is off" card stayed and the reader had to leave the screen and open it again.
- **Root cause:** `didChangeAppLifecycleState` in `record_screen.dart` only restarted the preview on resume. It never ran `_ensurePermissions()` again, so `_perm` stayed `denied`. Also, the rest of `_init` (camera events, preview, prompter) sits after the permission check and had returned early, so it never ran.
- **Fix applied (Android):** The part of `_init` after the permission check moved into `_continueInit()` (same code, same order). On resume, if `_perm` is `denied`, `_recheckPermissions()` reads `Permission.camera.status` and `Permission.microphone.status` only (no request, so no dialog). When everything needed is granted it sets `_perm` to `ok`, clears `_error`, and runs `_continueInit()` (or just starts the preview if the screen had already been set up). If something is still off, the card stays and names what is still off (for example it changes from "Camera and microphone are off" to "Microphone access is off"). While denied, the resume no longer opens the camera behind the card.
- **Verified (Android emulator, API 37):** (1) camera refused and microphone granted: granting the camera in Settings and coming back starts the preview and the script, without leaving the screen; (2) Voice mode, both refused: granting the camera changes the card to "Microphone access is off", and then granting the microphone starts the preview, and a take recorded afterwards saved normally; (3) coming back from Settings without granting leaves the "access is off" card and no permission dialog appears; (4) with everything granted, Home and back restarts the preview as before with no dialog.
- **Status:** Done on Android. iOS needs no change (builds with `flutter build ios --no-codesign`, not tested on a device).

#### "Holding at cue" strip sat inside the prompter panel on the camera screen
- **Fixed on:** Android and iOS/iPadOS (`app/lib/features/video/record_screen.dart`, `app/lib/features/prompter/prompt_surface.dart`, `app/lib/features/prompter/prompt_view.dart`). macOS is not affected (no camera screen; its full prompter already draws the strip in the footer, and that code is unchanged).
- **Also affects:** none left
- **Issue:** Record with the camera and reach a hold cue. The "Holding at cue · Continue" strip appeared inside the small prompter panel, over the lower lines of the script, with a normal-size button. The reader screen and the Mac's full prompter put the same strip at the bottom edge of the screen.
- **Root cause:** The camera screen shows the script through `PromptView` in a small panel, and `PromptSurface` only draws the strip at the screen's bottom edge when a host passes `cueFooterBottom` (only the reader screen does). Everywhere else it falls back to a strip inside the panel.
- **Fix applied:** `PromptSurface` and `PromptView` got a `holdInFooter` option (default false, so every other host is unchanged). When it is on, the surface leaves the holding strip out, and `RecordScreen` draws `CueFooter.holding(large: true)` itself as a full-width bar just above the record controls (portrait) or between the prompter panel and the controls rail (landscape). The controls are not replaced, so Stop and Pause stay in reach during a take. `RecordScreen._holdInFooter` is `Platform.isAndroid || Platform.isIOS`. The "Next" heads-up strip stays in the panel as before. The hidden strip is left out of the surface's `Stack` altogether: a zero-size child there made the panel's text disappear while holding.
- **Verified:** Android emulator (API 37), Narration + camera with a hold cue: the bar appears above the controls in portrait and landscape, the script stays fully visible in the panel, Continue resumes the narration, a no-hold cue shows inline with no bar, and the take saves (audio 40 s for a take with a long hold). iPhone 15 Pro Max (iOS 26.6): same result in portrait (bar above the controls, Continue resumes, take saved "00:36"). macOS: `flutter build macos` passes; `holdInFooter` is false there, so the existing strip code path is untouched. Not tried: iPad, iPhone landscape, Voice mode (same code path, driven by the same hold state).
- **Update (Android first, later change):** Android no longer uses the footer bar. On a phone's small panel the "Next" strip and the stacked bar were both too much, so Android now has no cue strips over the script (`RecordScreen._quietCues` is `Platform.isAndroid`; `PromptSurface`/`PromptView` option `quietCues`, default false). (1) The "Next" heads-up replaces the panel's status line for the few seconds before a cue (`ProgressLine(headsUp: true)`): `Next ⏸ Click Submit · Hold`, or `Next ↳ Point at the chart` for a cue without hold, and it shows even if the "Show progress" setting is off. (2) While a cue holds, the controls row changes in place: "Holding at cue" where the flip button is (it is off during a take anyway), Stop stays in the middle, and **Continue** takes the pause button's place (landscape: a small "Holding at cue" label, Stop, and a round ▶ in the rail). Pause is not offered during a hold (the narration is already paused) and comes back after Continue. iPhone and iPad got the same design afterwards (next update). macOS is unchanged.
- **Verified (Android emulator, API 37, fresh launch each time):** Narration + camera with a hold cue and a no-hold cue: the status line shows the heads-up before each cue (no black strip), the hold row appears with the full script visible, Continue resumes the narration, the no-hold cue shows inline with its heads-up and no row change, Stop during a hold saves the take (audio up to the hold point), and landscape shows the rail version. `flutter build ios` and `flutter build macos` pass; their code paths are unchanged.
- **Update (iPhone and iPad, same design as Android):** `RecordScreen._quietCues` is now `Platform.isAndroid || Platform.isIOS`, so iPhone and iPad get the Android design, and the footer-bar code (`holdInFooter` on `PromptSurface`/`PromptView`, and the bar in `RecordScreen`) was removed because nothing uses it any more. macOS is not affected: `RecordScreen` only exists on mobile, `quietCues` defaults to false for every other host (the Mac prompter, the phone reader, the studio preview), and the Mac keeps its own "Next" and "Holding at cue" strips.
- **Verified (iPhone 15 Pro Max, iOS 26.6, USB, debug build):** Narration + camera with a hold cue and a no-hold cue. The status line showed `Next ⏸ Click Submit · Hold` before the hold, no black strip. At the hold the controls read `Holding at cue | ■ Stop | Continue ▶` with the full script visible. Continue resumed the narration, the no-hold cue showed inline as "now" with no change to the controls, and the take saved ("Saved to your gallery · 01:32"). After Record again, the second take showed the heads-up and held at the cue again. Android re-run after the cleanup: same result. `flutter build ios`, `apk` and `macos` pass.
- **Not tried:** iPad, iPhone landscape (the layout code is shared with the Android landscape rail, which was checked), Voice mode (same hold state), Stop during a hold on iPhone.
- **Status:** Done on Android and iPhone/iPad (iPad and iPhone landscape not tried)

#### Camera screen: prompter panel footer and a taller panel (cosmetic, iPhone, iPad and Android)
- **Fixed on:** Android and iPhone/iPad (`app/lib/features/video/record_screen.dart`, `app/lib/features/prompter/progress_line.dart`, `prompt_surface.dart`, `prompt_view.dart`). macOS, the phone reader and the studio preview are not affected.
- **Also affects:** none left
- **Issue:** The panel's footer was one centred line under the script, and the script was cut off hard at the bottom edge of the panel (a line could be sliced in half). The panel was also small: 30% of the screen height in portrait.
- **Fix applied:** (1) The footer is split into two sides, lined up with the script's left and right edges: the section on the left (`Demo · 1 of 1`, name brighter) and the progress on the right (`33% · ~0:05 left`, percent brighter). It stays fixed while the script scrolls under it. The "Next …" heads-up starts at the left of the same row. (2) The script fades out over the last 44 px above the footer instead of ending in a hard cut. (3) In portrait, the panel's default height is 60% of the camera picture (about 48% of the screen on a 16:9 picture) instead of 30% of the screen. A height the reader already set by dragging is kept, and Prompter height → Reset returns to the new default. Landscape keeps its 40% of the screen. This is all behind new options that default to off (`splitFooter`/`bottomFade`/`split` and `_defaultFraction`), switched on in `RecordScreen` by `Platform.isAndroid || Platform.isIOS` (`_splitFooter`, `_defaultFraction`). The "Holding at cue" label is white with a soft shadow on both platforms (it was grey on Android), because the controls row can overlap the bottom edge of the camera picture. No logic changed.
- **Verified:** Android emulator (API 37): Narration and Voice with the camera, ready and recording, portrait and landscape, the hold row, drag of the panel handle, Reset, and the 60% default. iPhone 15 Pro Max (iOS 26.6, USB): Narration + camera in portrait, with the same footer, fade and 60% panel, the heads-up, the hold row, Continue resuming the narration to 100%, and a take saved ("Saved to your gallery · 00:43"). `flutter analyze` is clean; the iOS (no-codesign), Android and macOS debug builds pass.
- **Also verified on the iPhone:** Voice + camera, with the same 60% panel, split footer and fade, and a take saved ("Saved to your gallery · 00:09").
- **Checked afterwards:** (1) *Voice, a hold cue at the very start:* the hold row ("Holding at cue | Continue") was missing during the 3-2-1 countdown, although the hold was already active (the plain flip and "more" buttons showed instead). Reproduced on the Android emulator and fixed (`holdingCue` now also counts the countdown); Continue during the countdown ends the hold, and the take then records and saves. (2) *Panel size jump when the camera reports its shape:* not a bug on the supported cameras. The default height is worked out from a 9:16 picture until the camera reports its shape, and both platforms always report 9:16 in portrait (iOS fixes the preset to 1080x1920; Android only picks a 16:9 stream, and the panel measured the same ready, recording and after Reset), so it never changes. (3) *iPad in portrait:* not a bug. The picture is limited by the screen height there, so 60% of the picture is 60% of the screen height, which is what the setting means. Not seen on a real iPad (none connected).
- **Not tried:** iPad, iPhone landscape, and a first-time reader with no saved height on the iPhone.
- **Status:** Done on Android and iPhone/iPad (iPad and iPhone landscape not tried)

#### Narration: hold cues and heads-ups never fire after "Record again"
- **Needs fixing on:** every platform that records (shared Dart in `app/lib/features/prompter/prompter_controller.dart`); seen on Android
- **Issue:** Record a Narration take that reaches a hold cue, stop it, tap Record again and record. The prompter runs straight through the hold cue: no "Holding at cue", the audio does not pause, and no heads-up either. A fresh start of the camera screen holds as expected.
- **Root cause:** `_cueTimes` (the narration time of each cue) is computed once, when the recording is loaded. `restart()` (called by Record again) runs `_resetCues`, which empties `_cueTimes` and does not recompute it, so `_cueTimes.length != _cues.length` and the narration never reports a cue position again until the camera screen is reopened.
- **Fixed on:** shared Dart, `app/lib/features/prompter/prompter_controller.dart` (so it covers every platform that restarts a Narration; checked on Android and macOS)
- **Also a bug on macOS:** the Mac's Restart button (`desktop_prompter_screen.dart`, `_restart`) calls the same `restart()`. Repro on a macOS debug build with the fix switched off (Narration, script with a hold cue, state read through the VM service): take 1 held at the cue (`hold=0`, "On hold"); after Continue, the end, Restart and Play, the narration ran straight past the cue (word 10 → 15 → 21) with no heads-up (`next` stayed -1) and no hold.
- **Fix applied:** `_resetCues(script, {keepTimes})` now takes `keepTimes`, and `restart()` passes `keepTimes: true`: the cues start over (`_cuesDone`, timers, pace) but their narration times stay, because the script and the recording are the same. `begin()` (a new session or mode) still clears them and they are recomputed when the recording loads. Nothing else changed.
- **Verified (Android emulator, API 37):** take 1 through its hold, to the end, then Record again: take 2 shows the heads-up and holds at the cue; stop in the middle of that hold, Record again: take 3 shows the heads-up (`Next ⏸ Click Submit · Hold`) and holds again.
- **Verified (macOS debug build, fix on):** the same sequence now shows the heads-up (`next=0` from word 5 on) and holds at the cue (`hold=0`, "On hold", word 10) after Restart and Play, and again after Restart during an active hold. The first take is unchanged. (The prompter window is hidden from screen capture on the Mac, so this was checked from the prompter state, not from screenshots. A cached transcript was used, so the speech recogniser was not started.)
- **Verified (iPhone 15 Pro Max, debug build, Voice + camera off/on Narration + camera, 9 s recording):** take 1 shows the heads-up (`next=0`, "Next ⏸ Click Submit · Hold" in the status line), holds at the cue ("Holding at cue" + Continue in the controls), Continue runs it to the end and the take saves; Record again: take 2 shows the heads-up and holds again; take 2 stopped in the middle of the hold, Record again: take 3 shows the heads-up and holds again. Each run also stopped in the middle of a hold on the first take (Record again afterwards held on take 2 as well).
- **Not tried:** iPad (none connected), the Mac window UI itself, Retake in section by section.
- **Status:** Done on Android, macOS and iPhone (shared code; iPad not tried)

#### Android: after an interrupted take the card shows the video length, not the file's
- **Fixed on:** Android only (`packages/echoprompter_camera/android/.../EchoprompterCameraPlugin.kt`, `NarrationMux.kt`). An iPhone take interrupted the same way came out 6.60 s of video and 6.5 s of audio, so iOS is fine.
- **Issue:** Record in Voice mode with the camera, press Home after about 8 s and come back. The card said "Saved 00:07 to your gallery", but the saved file had 8.73 s of audio and only 7.81 s of video, so the video ended before the sound did.
- **Root cause:** When the app goes to the background the camera closes first, so video frames stop while the audio keeps going until the take is stopped. `Recorder.stop()` reports `lastPtsUs`, the last video frame, as the take's length.
- **Fix applied (decision: end the audio at the last video frame):** Only a take that did not end with the Stop button (`reason != "user"`: interrupted, storage full) is touched. Voice: after `Recorder.stop()`, `NarrationMux.trimAudioToVideo` runs on a background thread. If the audio runs more than 50 ms past the last video frame (`Recorder.videoEndUs`), it copies the file over itself, every video sample and the audio samples up to that frame, without re-encoding; on any failure the file is left as recorded. Narration: `narrationSegments(videoEndUs)` also cuts the narration segments at the last video frame (before this they were only bounded by when the app was told to stop). A normal Stop is unchanged: the new code is skipped.
- **Verified (Android emulator, API 37), track lengths from the pulled gallery files:**
  - Voice + camera, Home after about 8 s: **before** video 7.809 s, audio 8.731 s (card 00:07). **After** video 7.034 s, audio 6.958 s (card 00:06). The two tracks now agree to within one audio frame and the card to within a second (the card floors the last frame's start time; the container adds that frame's own length).
  - Narration + camera, Home 3 s after Continue: **before** video 7.274 s, audio 5.152 s. **After** video 3.915 s, audio 3.759 s. The narration is present (level about 2600 to 3600 RMS, silent during the hold, same as before) and is cut at the picture's end. In Narration the audio was already never longer than the video, because its segments stop when the app is told to stop, so the cut there is a safeguard and changed no measured value.
  - Normal Stop, Voice + camera, about 8 s: card 00:08, video 8.865 s, audio 8.847 s. The trim code did not run.
  - `flutter analyze` is clean and the debug APK builds.
- **Not tried:** a take interrupted by storage full, a take with pauses before the interruption, a take longer than a minute.
- **Status:** Done on Android (iOS not affected)

#### "Done" on the saved card went back to the script's editor
- **Fixed on:** Android and iOS/iPadOS (`app/lib/features/video/record_screen.dart`, shared Dart gated by `Platform.isAndroid || Platform.isIOS`). macOS has no camera screen.
- **Issue:** Record a take in Voice or Narration with the camera, then tap **Done** on the "Saved to your gallery" card. It returned to that script's editor, although the take is finished and nothing is left to edit.
- **Root cause:** `onDone` on the saved card was `_close`, which pops one screen.
- **Fix applied:** `_done()` calls `_home()` (`popUntil` the first route, the scripts list) on Android and iOS; other platforms keep `_close`. The X button and the "Done" on the "Recording stopped" card (nothing saved) still go back one screen, as before.
- **Verified (Android emulator, API 37):** Voice + camera and Narration + camera, a take saved, Done: both show the scripts list; reopening the script and starting again works. `flutter analyze` is clean.
- **Verified (iPhone 15 Pro Max, debug build):** Voice + camera, take saved, Done: scripts list. Narration + camera (9 s recording, hold cue): take saved, Record again, second take saved, Done: scripts list. Reopening the script and starting again worked, and X on the camera screen still goes back to the editor. No app errors were logged.
- **Not tried:** iPad (none connected).
- **Status:** Done on Android and iPhone (iPad not tried)

### Checked, nothing pending
- **Take ended by the system saved to the gallery** (call, app in the background, storage full): fixed on iOS and Android together; macOS does not record.
- **Android crash when the app goes to the background mid-take** (video thread stopped under the encoder): Android only. iOS finishes its writer and was tested with the same interruption, so it is not affected.
- **Record again restarts a Narration that played to its end:** fixed in shared Dart, so it applies to every platform.

### Camera screen: prompter panel under the camera cut-out in landscape
- **Fixed on:** iPhone (`app/lib/features/video/record_screen.dart`)
- **Also affects:** Android phones with a camera cut-out (not checked), iPad (no cut-out, probably not affected)
- **Issue:** Open the camera screen (Voice or Narration, camera on) on an iPhone with a Dynamic Island and turn it to landscape. The prompter panel starts at the left screen edge, so the first letter of each line and the section labels are hidden under the island.
- **Root cause:** The camera screen is full-bleed (immersive) and positioned the panel at a fixed 12 px from the left, without the safe-area inset.
- **Fix applied:** On iOS in landscape, `left: 12 + media.padding.left` for the panel with its width reduced by the same amount (right edge unchanged), and the right control rail at `16 + media.padding.right`.
- **Status:** Fixed on iPhone, pending on Android (check a phone with a cut-out in landscape)


### Free plan: demo script locked at the script limit
- **Fixed on:** Android and macOS (`app/lib/services/providers.dart` `canPresentNow`, `features/studio/studio_screen.dart`, `start_options.dart`, `desktop_studio_screen.dart`)
- **Also affects:** iOS and iPadOS
- **Issue:** With all 5 free scripts used, open the bundled "Welcome to EchoPrompter" demo: Start shows a lock and "Needs Pro. You've used your 5 free scripts". §6 says the demo must stay within the limits.
- **Root cause:** The demo has no saved id, and `ProState.canPresent(null)` treats an unsaved script as needing a free slot.
- **Fix applied:** `StudioNotifier.canPresentNow(pro)` returns true for the demo (no saved id and the text equals the welcome text, the same rule the save path uses) before asking `canPresent`. It is gated to `Platform.isAndroid || Platform.isMacOS`; add `Platform.isIOS` to enable it on iOS.
- **Status:** Pending (fixed on Android and macOS; macOS checked on screen only: Start unlocked at 5 of 5)

### Paywall had no Terms of Use or Privacy Policy links
- **Fixed on:** Android and macOS (`app/lib/features/pro/paywall_dialog.dart`, `app/lib/services/external_links.dart`; pages in `web/app/terms`, `web/app/privacy`)
- **Also affects:** iOS and iPadOS
- **Issue:** The paywall footer showed only a contact email, so there was no way to reach the Terms or the Privacy Policy (Guideline 3.1).
- **Root cause:** The links and the pages did not exist, and `openExternal` only opened URLs on macOS and Windows.
- **Fix applied:** "Terms of Use" and "Privacy Policy" buttons under the footer text, shown when `isAndroid || isMacOS`. `openExternal` opens URLs on Android with `url_launcher`. `websiteUrl` accepts `--dart-define=WEBSITE_URL=...` to point at a local `web/` server (`http://10.0.2.2:3000` from the Android emulator). The pages are `/terms` and `/privacy` on the website and must be deployed.
- **Status:** Pending (fixed on Android, verified on the emulator against the local server; macOS not clicked; iOS needs the platform check widened and `openExternal` to open URLs there)
