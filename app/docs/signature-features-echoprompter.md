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

Fixed on iOS and iPadOS in the Narration-with-camera work, not yet on Android. macOS does not record, so it is not affected. All three entries are one piece of work on Android; the first one has to come first.

### Narration video had no narration audio
- **Fixed on:** iOS and iPadOS (`packages/echoprompter_camera/ios/.../EchoprompterCameraPlugin.swift`, `NarrationMux.swift`, `packages/echoprompter_camera/lib/echoprompter_camera.dart`, `app/lib/features/video/record_screen.dart`, `app/lib/features/prompter/prompter_controller.dart`)
- **Also affects:** Android
- **Issue:** Record a take in Narration mode with the camera. With headphones, the volume down or silent mode, the saved video has only background noise instead of the narration.
- **Root cause:** The video's audio track was the microphone, which only heard the narration through the speaker.
- **Fix applied (iOS):** The take is filmed without the microphone. The Record screen reports the narration's playback position every 50 ms (`EchoPrompterCamera.narrationTick`), the camera notes which parts of the file played, and when the take stops `NarrationMux` puts those parts into the video (AAC soundtrack, picture copied without re-encoding). The audio session is set to playback only.
- **What Android needs (checked in the code):** `Recorder` in `EchoprompterCameraPlugin.kt` always runs an AAC codec fed by `AudioRecord` (`MediaRecorder.AudioSource.MIC`). In Narration mode Dart asks for the built-in microphone (`setHeadsetInput(false)`) and plays the narration on the speaker (`_route = speaker`; `setReferenceRoute` does nothing on Android), so an Android take still records the speaker and has the same bug. Port: for a Narration take do not start `AudioRecord`; put the parts of the narration that played into the audio track instead, using the same playback positions from `narrationTick` (the Dart side only needs `Platform.isIOS` widened to Android in `_toggleRecord`). Either decode the file with `MediaExtractor` and `MediaCodec` and feed the existing audio codec at the right time, or join it afterwards (the doc suggests Media3 Transformer in section 4; a new native dependency needs Arjun's approval first).
- **Status:** Pending on Android

### Narration with the camera asked for the microphone
- **Fixed on:** iOS and iPadOS (`app/lib/features/video/record_screen.dart`)
- **Also affects:** Android
- **Issue:** Start Narration with the camera. The permission card and the system prompt ask for the microphone even though the take does not need it.
- **Root cause:** The camera screen asked for camera and microphone for every mode.
- **Fix applied (iOS):** `_needsMic(mode)` is false for Narration on iOS, so only the camera is asked for, the card says the microphone is not used, and switching to Voice on the camera screen asks for the microphone then (`_askMicIfNeeded`).
- **What Android needs:** `_needsMic` is still true on Android (`RECORD_AUDIO` is in the manifest for Voice mode). Once the Android take no longer uses the microphone (entry above), widen the check to Android Narration. The permission flow is the same `permission_handler` code, so only that one check changes. Do not change it before the audio port, or Android Narration takes would be silent.
- **Status:** Pending on Android (after the entry above)

### Message when the narration could not be added, and the camera hint
- **Fixed on:** iOS and iPadOS (`EchoprompterCameraPlugin.swift`, `record_screen.dart`, `echoprompter_camera.dart`)
- **Also affects:** Android
- **Issue:** If the narration cannot be put into the video (or never played during the take), the reader should be told, not given a video without sound.
- **Fix applied (iOS):** `stopRecording` and the interrupted/storage-full event carry `narrationFailed`. The camera screen then deletes the file and shows "Narration wasn't added ... Please record the take again." with Record again (a snackbar when a mode change saves the take). The hint under the preview says the narration is added from its file.
- **What Android needs:** The Dart side is shared (`RecordingResult.narrationFailed`, `_onStopped`, `_endTake`), so only native work is left: return `narrationFailed` in the result map and in the event emitted by `finishRecording` in `EchoprompterCameraPlugin.kt`. The hint is still the old speaker text on Android (`Platform.isIOS ? ... : ...` in `record_screen.dart`); switch it when the audio port ships.
- **Status:** Pending on Android (after the first entry)

### Checked, nothing pending
- **Take ended by the system saved to the gallery** (call, app in the background, storage full): fixed on iOS and Android together; macOS does not record.
- **Android crash when the app goes to the background mid-take** (video thread stopped under the encoder): Android only. iOS finishes its writer and was tested with the same interruption, so it is not affected.
- **Record again restarts a Narration that played to its end:** fixed in shared Dart, so it applies to every platform.
