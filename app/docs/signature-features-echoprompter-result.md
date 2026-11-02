# Signature features: result tracker

Compares what was built against `signature-features-echoprompter.md`, section by section, so we can see later what still needs a revisit. Update it as each section is done.

## §0 / 0.1: Read this first, rename the modes

Done. The mode names come from `lib/core/settings/labels.dart` (Auto-scroll, Voice, Narration). The persisted enum `PromptControlMode { normal, voice, recordedAudio }` is unchanged. Architecture notes are in `docs/architecture-notes.md`.

Left over from Phase 0 (not done): App Review cleanup (§7) and the action-cue storage format proposal.

## §1: Narration mode, scroll by playback time

Commits: `8786957` (Apple and shared code), `ede5077` (first Android attempt), `8d11472` (macOS fullscreen crash fix), `d06d129` (elapsed time and reopen after End of script), `ccf3030` (Android without microphone), `133c339` (permission strings), `31bf96c` (iOS test note).

### Done and tested (macOS and the Android emulator, Pixel 6)

- Import: the file is copied into app storage and linked to the script.
- Transcribe or analyse once, cache it, show progress, Cancel.
- Alignment of the recording with the script, with skipped and extra words handled. Section titles are excluded.
- Scrolling by playback time: pause, seek, Back/Forward 5 s, Restart, tap a word, play to End of script.
- No microphone in Narration. Android no longer asks for the permission, and the reader asks for it only in Voice mode.
- Works offline (tested in airplane mode on Android).
- Sync offset slider (±500 ms) and the low-match flow (Continue anyway, Choose another file).
- Copy: the "play on speakers, not a headset" text is gone.
- Android languages tested: Portuguese, Chinese, Thai (all follow the audio).

### Differences from the spec (revisit if needed)

- **Android timing:** the spec asks for word-level transcription (whisper.cpp). A 75 MB model was rejected, so Android times the script from the recording's pauses. It does not meet "within about 1 word" inside long sentences. It held at the checkpoints measured.
- **Apple recogniser:** only `SFSpeechRecognizer` in on-device mode is used, not `SpeechAnalyzer` / `SpeechTranscriber`. No chunking for very long files.
- **Cache key:** (file hash, language), not (file hash, script id).
- **Sync offset:** one global setting, not remembered per output device.
- **Speed control:** Narration has no speed control. Slower/Faster are replaced by Back/Forward 5 s. Check whether the spec means something else by "existing speed control".
- **Unit tests:** the acceptance criteria list tests (normalisation, alignment, interpolation). None were written, because CLAUDE.md says not to create tests.

### Not tested yet

- iPhone and iPad end to end (checklist: `docs/ios-narration-verification.md`), including a 3 to 5 minute file, Narration with the camera, and Speech Recognition permission denied.
- Chinese, Thai and Portuguese on macOS and iPhone. The Apple alignment now compares those scripts letter by letter, and that is untested on Apple.
- A real Android phone (only the emulator was used).
- Android 13 (works by design, not run).
- Voice mode re-run on a device after the shared changes (read_screen microphone check, macOS fullscreen fix). Unchanged by reading the code, not by testing.

### Known open item

- Once, the end of the audio left the header on "Following audio" with a pause icon. It could not be reproduced in four more tries, so it is not confirmed fixed.

## §2: Run styles, whole script or section by section

Commits: see the `Run styles` commits after `31bf96c` (model and settings, controller and prompter surface, shortcuts, screens).

### Done and tested

- **Run choice** on the "How to read" sheet and in the macOS Studio inspector: Whole script (unchanged) or Section by section, with a "Start from" section picker when starting. The choice is saved in settings (`runStyle`).
- **Sections** come from the existing `[Name]` markers (`core/script/run_sections.dart`). Text before the first marker is its own section, a script with no markers is one section, and a marker with no words after it is skipped.
- **Stops at every section end and waits**, in all three modes. The end-of-section card shows "Section N done", the section name and time, Retake, Next (not on the last section) and Sections…, plus "Up next". The Sections list jumps to any section.
- **Auto-scroll** scrolls the section at the set speed, then stops. **Voice** follows speech within the section, holds on the section's last word, then stops, and ignores speech while it waits. **Narration** plays only that section's part of the recording, then stops the audio; Retake replays from the section's start and Back/Forward 5 s stay inside the section.
- **macOS global hotkeys** (editable in Settings > Shortcuts, with the existing conflict check): Next section ⌃⌥→, Retake ⌃⌥←, Open sections ⌃⌥S, Back 5 seconds ⌃⌥B (Narration). They are only taken from other apps while they do something. Tray menu items were added. Tested working while VS Code was in front.
- **Mobile** shows the card over the reader and over the camera screen (recording keeps going), with large buttons, a compact version in landscape, and a bottom sheet for the sections.
- **Whole-script runs behave as before** (tested on macOS and Android).

### Tested

- **macOS (built app opened directly):** Auto-scroll, Voice and Narration in floating, notch and corner layouts; Studio in native fullscreen then Start (no crash); light theme; hotkeys; Close while the card is showing.
- **Android emulator (Pixel 6):** Auto-scroll, Voice (speech played from the Mac speaker) and Narration; Voice with the camera and Whole script with the camera; Retake, Next, Sections jump, Start from, last section; landscape; light theme.

### Bugs found and fixed while testing

- Reader went blank (a `Positioned` returned from inside a widget).
- Auto-scroll showed word highlights after Retake or Next; the next section could end at once after Next; the progress footer stayed stale after a jump.
- Retake/Next/Start from left the text at the top after a new session started.
- Voice started matching from the script's start instead of the section, and its look-ahead ran into the next section's text.
- The footer showed the wrong section on the camera screen.
- The end card hid behind the dock in the reader and was cut off in landscape; the Sections sheet showed one row in landscape.
- The Retake button had a white fill in the light theme.
- On macOS the dimmed overlay blocked the header buttons while the card showed, and the header said "PAUSED" instead of "SECTION DONE".
- "Section by section" wrapped in the narrow inspector; notch buttons truncated by the shortcut hints.

### Revisit / not covered

- **iPhone and iPad:** not run (test tomorrow with the Narration checklist). Add: Run choice, end card, Sections sheet, Voice and Narration section stops, camera screen.
- **Unit tests:** none written (CLAUDE.md). The spec asks for logic tests for section stops.
- **Per-section video clips and export** belong to §4 and are not part of this section.
- The Android emulator's microphone only hears speech played from the Mac, so Voice was tested that way, not with a real voice.

## iPhone run (iPhone 15 Pro Max, iOS 26.6.2, debug build over USB)

Driven by a small script that sends touches through the Dart VM service, with screenshots from `devicectl`. Live logs were read from `flutter run`.

### Passed on the iPhone

- **§0 (mode names):** Auto-scroll, Voice and Narration show everywhere on the reader, the sheet and the camera screen.
- **§1 Narration:** the recording (47 s, four sections) was transcribed on the phone by Apple's on-device recogniser and matched the script at 97%. The Sync offset slider shows. "Following audio" highlights the words in step with the audio. Back/Forward 5 s, Restart and the time-left readout work. The camera result screen saved the video ("Saved to your gallery, 00:47, 1080p"), with the Camera, Microphone and Photos permission prompts shown once.
- **§2 Run styles, Auto-scroll:** stops at the end of each section, Next, the Sections sheet (with the done/current/next marks), jump to a section, and the last-section card with no Next button.
- **§2 Run styles, Voice:** the iPhone microphone heard speech played from the Mac, followed it word by word, stopped at the end of section 1 and then section 2, and Next carried on.
- **§2 Run styles, Narration:** plays only the section's part of the audio and stops; Forward 5 s stays inside the section; Back 5 s, Retake and Next work.
- **§2 on the camera screen:** Narration with the camera records while the audio plays one section at a time. The section-done card sits over the camera and the recording keeps going.

### Bug found and fixed (iOS only)

- On iOS, "Use Narration + camera" (and any change from the reader that depends on what was applied) did nothing: the sheet's future finished before the choices were applied, so the reader saw "nothing applied" and stayed on the reader. Fixed in `features/studio/start_options.dart` by waiting for the apply step on iOS only (`isApple`). Android and macOS take the same path as before. Re-tested on the iPhone: it now opens the camera screen.

### Not covered on the iPhone yet

- **Whole-script regression (all three modes)** and **Run styles on Whole script**.
- **Light theme, landscape, iPad.**
- **Voice with the camera**, Retake and Next on the camera screen, and the Sections sheet over the camera.
- **Chinese, Thai and Portuguese Narration** (the Apple letter-by-letter alignment).
- **A Narration file over about 3 minutes**, airplane mode, and Speech Recognition permission denied.

### Notes

- Xcode rewrote `ios/Runner.xcodeproj/project.pbxproj` (project format and team ID) and reordered `ios/Runner/Info.plist` during the iPhone build. Those are generated changes, not part of this work.
- In Narration, the camera option still says "Voice only / Voice + camera" (copy to revisit).
- My touch driver sometimes causes "Build scheduled during frame" asserts in the log. They come from synthetic touches arriving mid-frame, not from a user path.

## §3 onward

Not started.
