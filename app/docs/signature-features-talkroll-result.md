# Signature features: result tracker

Compares what was built against `signature-features-talkroll.md`, section by section, so we can see later what still needs a revisit. Update it as each section is done.

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
- **Apple recogniser:** on iOS 26 and macOS 26 and later it uses `SpeechAnalyzer` with `SpeechTranscriber` (10 languages) or `DictationTranscriber` (about 30 more), with the older `SFSpeechRecognizer` on-device path as the fallback and for older systems (see "Apple engine research" below). The first use of a language downloads its pack from Apple once; the recording is never sent.
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
- **Whole script (regression):** Auto-scroll ran straight through to "End of script" with no section stop, and Voice followed all four sections word by word to "End of script" with no section stop. The footer still shows the marker-based "Wrap-up · 4 of 4" as before.
- **§2 on the camera screen:** Narration with the camera records while the audio plays one section at a time. The section-done card sits over the camera and the recording keeps going.

### Bug found and fixed (iOS only)

- On iOS, "Use Narration + camera" (and any change from the reader that depends on what was applied) did nothing: the sheet's future finished before the choices were applied, so the reader saw "nothing applied" and stayed on the reader. Fixed in `features/studio/start_options.dart` by waiting for the apply step on iOS only (`isApple`). Android and macOS take the same path as before. Re-tested on the iPhone: it now opens the camera screen.

### Second iPhone run (2026-11-02, same phone, debug build over USB, same touch driver)

Passed:

- **Whole-script Narration:** 21 s file, 95% match, "Following audio" highlights in step, ends on "End of script" with the play icon (the header did not stay on "Following audio").
- **Chinese and Thai Narration:** transcribed on the phone (Chinese 78% match, Thai 100%), highlight follows the audio to the end.
- **Voice with the camera, section by section:** the section-done card shows over the camera while REC keeps running; Retake and Next work and Voice resumes; the Sections sheet opens over the camera and jumps; both takes saved to the gallery (02:39 and 04:17, 1080p).
- **Light theme** (Studio and sheets; the reader stays black) and **landscape** (compact card with Retake / Next / Sections…, Sections sheet scrolls).

Found, not fixed:

- **Older Apple recogniser (`SFSpeechRecognizer`), kept as the fallback:** it recognises a long file in stretches of about a minute and returned only the last one; fixed by merging the timed results (iOS and macOS).
- **Portuguese (pt-BR) failed in that older recogniser's models themselves** (22% of the letters, also with Apple's servers). Fixed by the newer engine, see below.
- **After "Sections…" the prompter waits paused** (by design, `goToSection` without play). On the camera screen nothing says so, and the round button at the bottom right pauses the recording, not the prompter. Tapping the prompter text starts it. Voice did follow the speech after that tap.
- **Voice, last section:** with one section's audio played alone, Wrap-up stopped at 99% with "year." not confirmed (and no last-section card), even when the ending was spoken again. Likely the conservative matcher on the final word with synthetic speech. Not reproduced with a human voice.

### Apple engine research and fix (2026-11-02, iPhone 15 Pro Max, iOS 26.6.2)

Why: Portuguese Narration showed "doesn't seem to match". Compared on the phone, same 20 recordings made with macOS text-to-speech, scored as the share of the script's letters found in order:

- **Portuguese:** `SpeechTranscriber` 100%; `DictationTranscriber`, the older on-device recogniser and Apple's servers all 22%. So the server fallback would not have helped, and nothing needs to leave the device.
- **Other languages (`SpeechTranscriber` / `DictationTranscriber`):** es 98/95, fr 91/83, de 100/100, it 100/100, ja 98/92, ko 96/87, zh 89/80. Dictation only: hi 93, ru 99, tr 98, nl 100, pl 92, vi 95, id 99, sv 97, he 98, uk 100, cs 100, hu 99, el 97, ro 96, th 96.
- **Speed:** about 0.4 s for a 40 s file; 3:59 of English in a few seconds. Every word has a time.
- **Built:** on iOS 26 and macOS 26 and later (`FileTranscriberChannel.swift`, both copies) the newer model is used where it supports the language, else the dictation model, else the older path. Through the app: all 25 recordings transcribe (English 300 of 300 and 787 of 790 words, Portuguese 91 words and 98% match), and the Portuguese Narration highlight follows the audio.
- **Things learned:** the system allows 5 reserved languages per app and a reservation outlives the app, so each one is released after use; the language packs are installed by the system on first use (needs a connection once per language); asking `SpeechTranscriber.supportedLocale(equivalentTo:)` about a language it lacks makes the dictation pack for that language report as unsupported, so the lists are matched directly; the older recogniser's on-device availability followed what the system had installed (zh-CN stopped working once its reservation was released).
- **Cache:** transcripts are stored under a new name (`.v2`) so ones made by the older recogniser are not reused.
- **Not done at that point:** the language-pack download copy, Voice mode and the language list (done below), macOS at run time.

### Languages, language packs and Voice mode (2026-11-02, follow-up)

The 33 languages, with the engine and measured score for each, are in `docs/apple-speech-languages.md` (for the App Review notes). Changes made:

- **Language packs are downloaded once, and only after the reader agrees** (iOS 26 and macOS 26 and later), through one shared helper (`LanguagePacks.swift`, both platforms; `language_pack.dart`). Narration shows a Download / Not now row on its card; Voice asks when Start is pressed (`ui/language_pack_prompt.dart`, with a progress dialog and a failure message); switching to Voice inside the reader never downloads and says what to do. Earlier today's version downloaded silently when the card opened; that was removed. After the download the language works offline. If a download fails (no connection) the message says to connect once. Apple reports no size or byte progress for the packs, so the app shows neither. Each pack stays reserved; the system allows five, and when a sixth language is needed the least recently used is let go and asks again.
- **Reading language Automatic:** unchanged logic (detect the script's language with Apple's language recogniser, match the device's regional variants). With a German script and no German pack, Narration now downloads the German pack (about a minute, once) instead of failing; Voice does the same. A script in a language Apple lacks (Bulgarian, Slovenian) is read as English, and the "doesn't seem to match" message now says which language the recording was read as.
- **Voice mode in Portuguese:** the older recogniser dropped most of the speech (22%) and, on the iPhone, produced almost nothing after the first pause. Portuguese now listens through Apple's newer engine (`LiveAnalyzer.swift`, both platforms). Checked on the iPhone with a 90-word script: all 89 words were followed to "End of script". Other languages: the newer engine is also used when the older recogniser has no on-device model (checked: Russian 52 of 52 words, German 56 of 57); languages where the older one has an on-device model keep it (English, Chinese and Thai measured better there, Chinese 174 of 175 against 147 of 175).
- **Found while testing:** the older recogniser said Danish had no on-device model right after the pack was installed, and had one after the app was restarted. The choice of engine is therefore made each time Voice starts, from what the recogniser reports then.
- **Bug in my own cleanup, fixed:** while removing debug code I deleted the line that starts the newer engine, so Voice silently used the older one. Found by logging the engine choice and re-verified after the fix.
- **Cantonese:** the model writes Simplified characters and scripts are Traditional, so the transcript is converted to Traditional before alignment.
- **Consent step checked on the iPhone** (Russian, German, Hindi, Turkish): Voice's question, Not now (nothing downloaded), Download with the progress dialog then the reader (German followed to the end), the failure dialog (it appeared once when the system refused a sixth language, which exposed a bug: room is now made before the download), Narration's card with Download and Not now, and the in-reader Voice message. Regression: English Voice and Auto-scroll start with no question; Narration with installed packs (pt, de, ru, hi) transcribes.
- **Two fixes after the second iPhone walk-through:** (1) Choosing Voice inside the reader for a language whose pack is missing showed a long status that was cut off ("…press Start to do…") and told the reader to go back. The reader now asks the same "Download the … language pack?" question itself, shows the progress dialog, and starts Voice by itself when the download ends (checked with Vietnamese: question, progress, then the highlight followed the speech); the status is the short "Language pack needed". The camera screen does the same. (2) The Narration card kept the language it had read a recording in, so changing the same script from Chinese to English left "Needs the Chinese pack" (or the reverse) until the next tap. It now rereads the language when the sheet opens or the reading language changes (checked: zh-CN to en-US, and it asked for the English pack).
- **Voice mode measured for all 33 languages (2026-11-03, iPhone, whole script, voice only):** a two-paragraph script per language spoken from the Mac, followed through the real Voice controller. Every language reached 92% to 100% of its words (French 92% lowest); none needed the planned rerun below 70%. Seven languages used the newer engine (de, es, it, ja, ko, pt, yue) and 25 the older on-device recogniser, which depended on the packs already on the phone. Full table, with Narration kept as a separate record, in `docs/apple-speech-languages.md`.
- **Narration measured end to end for the same 32 languages (2026-11-03):** the two-paragraph audio was transcribed on the phone and played through the Narration controller. The highlight reached the end of the script in all of them; the share of script words found in the transcript was 81% (Korean) to 100%, lowest Korean 81%, Hindi 84%, French 85%, Finnish 86%, Croatian 86%. Table in `docs/apple-speech-languages.md`.
- **Not verified:** macOS at run time (compiles), iPad, iOS 15 to 25, real human speech, airplane mode (a download with no connection: only the failure path was seen, caused differently), and an App Review submission.

### Not covered on the iPhone yet

- **iPad** (the iPad was unavailable).
- **Airplane mode and Speech Recognition permission denied** need Settings changes on the phone and could not be driven from here.
- Narration without the camera in light theme or landscape was not run; only Auto-scroll sections were.

### Notes

- Xcode rewrote `ios/Runner.xcodeproj/project.pbxproj` (project format and team ID) and reordered `ios/Runner/Info.plist` during the iPhone build. Those are generated changes, not part of this work.
- In Narration, the camera option still says "Voice only / Voice + camera" (copy to revisit).
- My touch driver sometimes causes "Build scheduled during frame" asserts in the log. They come from synthetic touches arriving mid-frame, not from a user path.

## §3: Action cues

Platforms: macOS, iOS (iPhone) and Android. Modes: Auto-scroll, Voice, Narration. Design: the "quiet inline" artboards 37 to 41 of the design canvas (https://claude.ai/artifact/LjCLG754qyvCXoeqFtQhpB), approved after an earlier chip design was rejected as too heavy.

### What was built

- **Storage (proposal accepted by default, no migration):** a cue is a marker line in the script body, `{{ text }}` for a plain cue and `{{! text }}` for a hold cue. Old scripts load unchanged and cues round-trip. Cue lines are skipped by word counts, spoken-word matching, section detection and the Narration alignment (`core/script/sections.dart`, `text.dart`, `clean_script.dart`, `saved_script.dart`), so word indices are the same as without cues.
- **Editor:** "Insert Action Cue" next to "Insert Section" on mobile and in the macOS Studio, with a text field and a Hold toggle (`studio/action_cue_dialog.dart`). The macOS menu has an Insert Action Cue item. On mobile the button shares the row with Insert Section, and the word count and Clear sit on their own line above. Cue lines are tinted in the editor.
- **Prompter display** (`prompter/cue_widgets.dart`, `prompt_surface.dart`, `word_layout.dart`): cues are inline lines between the text, left-aligned, not part of the reading line. A plain cue shows as "↳ text"; a hold cue is amber with a "Hold" tag; the active cue shows "now". Heads-up: the upcoming cue is shown before it becomes active (no countdown, by design). A "Holding at cue" footer with a Continue button shows while holding (macOS shows the button in the control bar, the phone hides its dock). Text is `#EDEDEB` unspoken and `#A6A9B0` read, line height 1.32, with one spacing scale for the gaps above and below cues and sections.
- **Heads-up setting:** "Action cue heads-up" slider on the "How to read" sheet (1 to 5 s, default 3 s, `cueLeadSeconds`).
- **Hold, per mode** (`prompter_controller.dart`): Auto-scroll stops scrolling at the cue; Voice keeps the recogniser running but ignores speech until Continue; Narration pauses the audio at the cue time (alignment time minus 0.1 s) and resumes it on Continue. Continue works from the button, a tap, the macOS hotkey ⌃⌥↩ and Play. A plain cue never pauses.
- **Language row on "How to read"** (all platforms): "Listening for X · Change", with Automatic from the script. On Android, detection uses `TextClassifier` through the `detectLanguage` method channel with a fallback; the Apple path is unchanged.

### Bugs found and fixed during the build (before this round of tests)

- Voice overshot past a hold cue: progress now snaps back to the cue word when the hold starts and speech is dropped while it holds.
- The heads-up was missing after Continue, and the orange current-word highlight crossed a cue into text not yet spoken (`_predictedAfter`). Behaviour is unchanged when a script has no cues.
- Crash with large text ("Null check operator"): cue heights are now computed before the text is laid out.
- Auto-scroll hold jumped to the top, and a hold fired while its cue was below the reading line at large text: the scroller moved in the widget tree when the footer appeared; it is now always in the same stack.
- The "Cleared · Undo" snackbar stayed over Start.
- macOS: Space, the arrows and Esc did nothing in the prompter because the Studio text field kept keyboard focus. The window plugin now reclaims focus (`makeFirstResponder`) and the prompter uses a focus node. Play pressed while the recording was loading is remembered.
- macOS: the ↩ in the shortcut hint drew as a blue emoji box; it is now an icon.
- Android Voice did not follow the speech: the Voice language was fixed to Spanish for an English script (fixed with an Android-only branch, `_confirmOnAndroid`), and the on-device recogniser was swapped for the system one too early (it now gets 30 s once speech is detected, `SpeechChannel.kt`). The emulator needed `-allow-host-audio` and `adb emu avd hostmicon` to hear the Mac.

### Round of tests and fixes in this session

**Issue 1, Narration preloaded an audio file (not intended, fixed; all platforms).** A new, duplicated, imported or demo script has no saved identity but inherited the previous script's recording from the session. `StudioNotifier` (`services/providers.dart`) now clears the recording in those four places; a saved script still restores the recording linked to it. Checked on macOS: a new script shows "Choose a recording…", and the saved script with a linked recording still restores it.

**Issue 2, Voice: speech during a hold highlighted after Continue (fixed; shared Dart code).** Root cause: a recogniser's text is the whole running transcript of its current utterance, and it keeps growing until the recogniser ends the utterance (a final result; on macOS only after a pause). Words heard during the hold were still at the start of that transcript after Continue, so the tracker took them as new speech. That is why it only happened if Continue was pressed within a few seconds. Fix (`prompter_controller.dart`, helper `trackerWords` in `core/matching/script_tracker.dart`): count the words the transcript holds during the hold, and after Continue drop that many from the start of the same utterance's transcript until the utterance ends. No timer or delay. It does nothing unless a hold happened, and a final result or a recogniser restart resets it. Known limit: a word or two spoken between the last reported partial and the click can still count.

**Voice status line on macOS (fixed, macOS only; `desktop_prompter_screen.dart`).** The footer always read "Listening — start reading your script". It now reads "Following your voice" once the first script word is confirmed.

**Test script:** cues dense on purpose: two plain cues in a row, a plain cue before the hold, one hold ("Click Submit" / "Clique em enviar"), and two plain cues before the last sentence. English 34 words, Portuguese 33 words. Narration used recordings made with macOS text-to-speech (Samantha and Luciana), each matching its script 100% (0:11 and 0:15). Voice used the same voices played from the Mac speaker into each device's microphone.

| Mode | macOS | iPhone 15 Pro Max (iOS 26.6.2) | Android emulator (Pixel 7, earlier rounds Pixel 6) |
|---|---|---|---|
| Auto-scroll | Hold and plain cues checked in the build rounds | **Pass** | Checked at large text: the cue stays on one line and the hold stops at the cue |
| Voice, English | **Pass** (this round and the build rounds) | **Pass** | **Pass** (build rounds), hold re-checked after the Issue 2 fix |
| Voice, Portuguese | **Pass** (this round; build rounds after the language pack download) | **Pass** | **Pass** (build rounds, language set to Portuguese by hand) |
| Narration, English | **Pass** (this round and the build rounds) | **Pass** | **Pass** (build rounds, audio paused at 0:04, played to 0:11) |
| Narration, Portuguese | **Pass** (this round and the build rounds) | **Pass** | **Pass** (build rounds, audio paused at 0:03, played to 0:08) |

The Android and macOS "build rounds" are the runs made while the design was implemented and reworked, before this round. Their results are in the next subsection.

What each check showed, where "pass" means all of these held:

- Cues display in the distinct style, are never highlighted as read text, and don't change the word counts (34 and 33 words).
- A plain cue does not pause, and the highlight keeps following across it.
- A hold stops the prompter at the cue ("On hold" and "Holding at cue" with Continue). In Voice, a sentence spoken during the hold was ignored (the confirmed word index did not move, also when Continue was pressed within a second), and after Continue only new speech advanced the highlight to the end. In Narration the audio paused at the cue and resumed from the same point on Continue, finishing at 100%. In Auto-scroll the scroll stopped and Continue resumed it to "End of script".
- macOS: Continue was checked with the ⌃⌥↩ hotkey in English and the button in Portuguese. The Voice and Narration runs ended at 100% in both languages.
- iPhone: no permission prompt appeared. The English Narration language pack needed a one-time download (the user tapped Download); the Portuguese pack was already installed. The Voice language on the phone was left at Thai by an earlier test and was reset to Automatic from the sheet.

### Earlier test rounds (during the build)

**Android emulator** (first Pixel 6, then a Pixel 7 after the first emulator's microphone stayed silent; speech was the Mac's text-to-speech played from its speaker, narration recordings were made with the same voices):

| | Voice, English | Voice, Portuguese | Narration, English | Narration, Portuguese |
|---|---|---|---|---|
| Highlight follows the speech or audio | Pass | Pass | Pass | Pass |
| Hold cue pauses until Continue or Play | Pass, speech during the hold ignored | Pass, speech ignored | Pass, audio paused at 0:04 | Pass, audio paused at 0:03 |
| Plain cue is visual only | Pass, no pause, highlight continued | Pass | Pass, no pause | Pass |

Continue and Play resumed the run in every case, and every run reached "End of script" at 100%. After the design rework (screens 40 and 41) the same four runs were repeated and passed, plus Auto-scroll at large text. The first Narration pass (with the hold only) also passed before the Voice problems were solved.

**macOS** (built app, Voice and Narration, English then Portuguese; the Portuguese (Brazil) pack was downloaded once when the app asked):

- **Voice, English and Portuguese:** pass. The highlight followed the speech, the heads-up showed, speech during the hold was ignored, ⌃⌥↩ or the Continue button resumed it, the plain cue showed "now" without pausing, and it reached 100%.
- **Narration, English and Portuguese:** pass. The recording matched 100%, the heads-up showed "IN 1S", the audio paused at the hold ("Waiting for you"), Continue resumed it, and it finished at 100%.
- **Design checked against the artboards:** artboard 38 (floating window: the control bar is replaced by "Holding at cue · ⌃⌥↩ · Continue", 64 px tall, the cue sits on the reading line in Voice and Narration) and artboard 39 (notch: compact holding strip). The prompter was set back to Floating afterwards.

**Mobile design checked against screens 40 and 41 (Android):** while a hold is active the dock and progress bar are hidden and only "Holding at cue" with a large Continue shows, clear of the gesture bar; "01  Demo" is a fixed readable size (55% of the script size, 14 to 20 px) with a gap below; with very large text the "Next" strip sits above the dock; long cue text stays on one line up to 24 px and wraps to two lines after that.

**Fixed during those rounds (not listed above):**

- The status pill showed a red "Unavailable" during a hold; it now shows "On hold" (`tracking_status.dart`, all platforms; only while a hold is active).
- The mobile editor's Insert Section and Insert Action Cue labels wrapped; they now stay on one line.
- On Android the Voice highlight did not follow the speech after the recogniser had been swapped for the system one (details in the Android Voice entry above).

**Open items from those rounds (still true):**

- **Android "Automatic" language:** Android has no built-in language detector, so it first guessed from letters (Devanagari, Cyrillic, CJK, Arabic, Hebrew, Greek, Thai and Latin letters with tell-tale marks worked; French, Italian, Dutch and Spanish without ñ fell back to English). It was then reworked to use `TextClassifier` first with the letter and common-word guesses as fallbacks, and the language row on "How to read" shows what was chosen. macOS and iOS use Apple's detector and were not changed.
- **macOS "Start ⌘↩":** the ↩ in the Studio's Start button still shows as a blue emoji box (an older label; the cue footer was fixed).
- **macOS Narration start:** Space does not start Narration on the prompter, so Play has to be clicked. This was already so before the cues.
- **macOS desktop layout at very large text:** the "Next" strip sits just above the control bar; artboard 39 merges it into the bar, which would need the bar rebuilt, so it was kept simpler.
- **Emulator recogniser:** on the Android emulator the recogniser sometimes misses the last word of a sentence ("time.", "assistir.") until it is repeated; it is the emulator's microphone feed, not the cue logic.
- **Cue "now" window:** it lasts 2.5 s rather than "until the next text starts".
- **Test leftovers:** the emulator's "Script five…" held the Portuguese test script, and its Voice language was left on Portuguese (Brazil); the Mac's script list has the "Hello everyone…" and "Olá a todos…" test scripts.

### Other findings from these runs

- Nothing failed on macOS or the iPhone in this round, so no macOS-only or iOS-only fix was needed. The Issue 2 fix is shared code that is idle unless a hold happened.
- macOS paste into the Studio editor did nothing from automation, so the test scripts were loaded with Import.
- The Android emulator froze under CPU load once (screenshots came back empty and System UI stopped responding). It was restarted. `adb input text` also dropped characters, so the Android script was imported as a file.
- For macOS screenshots, "hide from screen capture" was turned off temporarily and the original setting was restored afterwards.
- The iPhone was driven with the same touch driver as the earlier runs (debug build over USB, touches through the Dart VM service, screenshots from `devicectl`, controller state read through the VM service). A "Build scheduled during frame" assert appeared once from a synthetic tap; the next tap worked.
- Xcode again rewrote `ios/Runner.xcodeproj/project.pbxproj` during the iPhone build (generated, not part of this work).

### Not covered / open

- **iPad** and a real Android phone were not run. Android Voice used speech played from the Mac, not a human voice.
- **Insert Action Cue flow on macOS:** the menu item and dialog opened and worked in the build rounds, but a full dialog insert was not re-run after the menu change (one scripted click missed, so the cue line was typed). The cue round-trip through saved storage was checked during the build, not re-run in this round.
- **Narration with the camera and section-by-section runs with cues** were not run in this round.
- **Unit tests:** the spec asks for a script dense with cues to be tested for voice following and alignment. It was tested by hand (above); no automated tests were written, because CLAUDE.md says not to create tests.
- The "Next up" heads-up in Voice is estimated from reading pace; its timing was seen working but not measured.

## §4: Mobile recording, section clips and export

Built and tested on the Android emulator and on the iPhone (see "iPhone run" at the end of this section). iPad was not run.

### What was built

- **Run style on the camera.** The existing "Run: Section by section" choice in *How to read* now also drives the camera screen (Voice and Narration, front or back camera). Whole script is untouched: one file, as before.
- **One clip per section** (`app/lib/features/video/record_screen.dart`, `recording_session.dart`). Record starts the 3-2-1 countdown and the section's take; when the prompter reaches the end of the section (`sectionDone`) the take stops by itself after 0.4 s, and the end card appears. Every take starts at the section's first word.
  - **Retake** and **Next** on the end card (`SectionEndCard` got `onRetake`, `onNext`, `onFinish`) go to the section and start a take with the countdown. **Jump** is "Sections…" on the end card, or *Camera options → Jump to a section*; after a jump the section waits and Record starts its take.
  - `RecordingSession` / `Clip` hold the data model (id, session, section, file, duration, attempt, keeper flag). A new take of a section becomes the keeper and the older ones stay as attempts. `keepers` are always sorted by section, whatever order they were recorded in. `missingSectionsMessage` builds "Sections 2 and 4 have no take".
  - Stopping the take in the middle of a section (Stop, close, or changing the mode) drops that half take, keeps the other clips and puts the section back at its start. A take ended by the system (call, full storage) is dropped the same way, with the existing "Recording stopped" / "Storage is full" card, and the section is ready to record again.
- **Export** (`clip_export_sheet.dart`). "Export" on the end card (or "Export" when leaving the screen with clips) opens *Your clips*: every section with its length and number of takes, "No take" in red, and the warning "Section 3 has no take". **Finished video** joins the keepers in section order (with missing sections it asks first: "Go back" / "Export without them"). **Separate clips** copies each keeper as `TalkRoll 02 Setup.mp4`. Both go to the gallery and then show the usual saved card with Share (all files). If the gallery refuses, the card says so and Share still works. After an export the clips are deleted; leaving with clips asks Stay / Discard clips / Export.
- **Native join.** New channel method `joinClips(paths)` in `packages/talkroll_camera`.
  - **Android:** `ClipJoin.kt`, Media3 Transformer 1.4.1 (`media3-transformer`, `media3-effect`, `media3-common`; no FFmpeg). Clips of the same size are joined as filmed (no re-encode); a clip of another size is fitted into the first clip's frame.
  - **iOS:** `ClipJoin.swift`, `AVMutableComposition` + `AVAssetExportSession`. Same size and rotation: passthrough preset (no re-encode); otherwise a video composition fits each clip into the first clip's frame. Not run yet.
- **Narration with the camera.** Already needed camera only (no microphone permission, no microphone in the file, narration put into each take from its file). Each section's clip therefore carries its own part of the narration. Nothing changed here.

### Tested on the Android emulator (Pixel 6, API 37, back/front scene camera, Narration mode with a generated 10 s narration, 3 sections)

- Record section 1, Next, record section 2, Retake section 2, Next, section 3: three clips, the retake replaced only section 2's keeper (export sheet shows "Setup · 2 takes"), earlier take kept until export.
- Finished video: 11.1 s, one video and one audio track, no black frame (sampled every 0.5 s) and no break in the audio at the joins (the only quiet stretches are the narration's own pauses at the end of sections 1 and 2). Saved to `DCIM/TalkRoll`.
- Missing section: with sections 1 and 2 only, the sheet shows "Section 3 has no take", Finished video asks first, and "Export without them" gave a 7.8 s video with both sections in order.
- Separate clips: two files saved, named after their sections.
- Stop in the middle of a section: "Take discarded", prompter back at the section start, the other clips kept. Leaving with clips: "Leave without exporting?" with the right count. Record again after an export starts a fresh run from section 1.

### Bugs found and fixed while testing (Android)

- The section number in the top pill never updated because nothing rebuilt the screen once the prompter knew its sections. The pill idea was dropped (the panel footer already says "Intro · 1 of 3"), so nothing is left of it.
- The last section's end card cut "Finish & export" short, so the button is just "Export".
- The first join re-encoded the picture (35 s for 11 s of video on the emulator) because a size effect was always added. It is now added only to a clip of another size, so same-size clips are no longer re-encoded.

### Differences from the spec / not covered

- **Not run:** iOS and iPadOS (code only, `swiftc -typecheck` is clean), a real Android phone, tablet, landscape, front camera for section clips, Voice mode with a real voice, storage-full and call interruptions during a section clip (the code path was written, the system events were not triggered), and a Whole script run after this change (that path was not edited, but it was not re-run).
- **Data model:** there is no `scriptId` because scripts have no stable id in the app today, and clips only live while the camera screen is open (they are deleted when it closes). Because of that "Deleting a script asks whether to delete its recordings too" has nothing to ask yet.
- **Undo:** earlier attempts are kept until export or discard, as asked, but there is no screen to bring one back as the keeper.
- **Edits during a session:** editing the script from the camera options deletes the clips (the sections may no longer line up). Changing the mode to one without the camera also leaves the screen and loses unexported clips.
- **Tests:** the spec asks for tests of keeper selection, section order and the missing-sections warning. None were written, because CLAUDE.md says not to create tests. The logic is isolated in `recording_session.dart` so it is easy to test.
- Joins show as jump cuts, as intended. The audio of a clip ends after the narration's pause that follows the section, so a clip can end with a short silence.

### iPhone run (2026-11-06, iPhone 15 Pro Max, iOS 26.6.2, debug build over USB)

Same driver as the earlier iPhone rounds (`flutter run`, VM-service taps, `devicectl` screenshots). The script (3 sections) and a 10 s generated narration were put in place by evaluating the providers, since the Files picker cannot be driven. Narration mode, Section by section, back camera.

**Passed**
- Record section 1 (3-2-1 countdown, stops by itself at the section end, end card "Section 1 done · Intro · 0:03"), Next, section 2, Retake section 2, Next, section 3. The export sheet showed "Setup · 2 takes" and the last section's end card had Retake, Sections… and the primary **Export**.
- **Finished video** (native `AVMutableComposition` + `AVAssetExportSession`, passthrough): 10.8 s, 1080x1920 upright, one video and one audio track, no black frame (sampled every 0.5 s), the narration continuous across both joins (only its own pauses are quiet), saved to Photos ("Saved to your gallery · Finished video · 00:10").
- **Separate clips**: `TalkRoll 01 Intro.mp4` was written and saved ("1 clip · 00:03"); that clip is 3.2 s with the narration for section 1.
- Stop in the middle of section 2: the take was dropped, the section waited at its start (Setup · 2 of 3, 38%), section 1's clip was kept.
- Close with a clip: native "Leave without exporting?" (Stay / Discard clips / Export). Export then showed "Sections 2 and 3 have no take", and Finished video asked "Go back / Export without them".
- **Whole script** (regression): one 10 s take, saved to the gallery ("00:10 · 1080p"), no section UI.
- No new bug was found on the iPhone, so no iOS code changed in this round.

**Not covered on the iPhone**
- iPad, front camera and Voice mode with section clips.
- A single keeper exported as "Finished video" (it uses the clip file itself, no join; the Android run covered this path).
- Interruptions (a call) and a full disk during a section clip.
- The test script "Section clips test" is left in the scripts list on the iPhone and on the Android emulator.

### iPhone landscape run (2026-11-06, same phone)

The phone was not turned by hand: the screen was forced to landscape with `SystemChrome.setPreferredOrientations` (the app locks the orientation itself during a take and releases it afterwards, so it was forced again after each take, as a person holding the phone sideways would stay sideways). Same script, narration and driver as above.

**Passed**
- Landscape layout of the camera screen (prompter panel on the left, controls in a rail on the right, end card in the middle): record, end of section, Retake, Next, section 3, Export, all worked. The end card shows Retake, Next, Sections… and Finish in one row; on the last section Retake, Sections… and Finish.
- The export sheet in landscape is scrollable (the list shows about one and a half sections above the buttons, which stay visible).
- **Finished video, all clips landscape:** 10.8 s, 1920x1080, one video and one audio track, no black frame, narration continuous across the joins (only its own pauses are quiet).
- **Finished video, mixed orientations** (section 1 portrait, section 2 landscape): 7.2 s, 1080x1920 (the first clip's frame). The landscape clip is upright and fitted inside it with black bars above and below, the narration continues without a break. This is the re-encoding path of `ClipJoin.swift`; it worked first time.

**Bug found and fixed (iPhone landscape, shared code)**
- The landscape end card (compact layout) holds four buttons once Finish is there, and "Sections…" was cut to "Secti…". `SectionEndCard` now uses less horizontal padding for its buttons in that layout, only when the camera passes `onFinish` (so the Mac's compact cards are unchanged). After the change "Sections…" shows in full. Re-checked on the phone.

**Fixed afterwards (iPhone only): prompter panel under the Dynamic Island in landscape**
- In landscape on the iPhone the panel started at the very left edge, so the Dynamic Island hid the first letter of lines ("Hello", "the") and the "01 Intro" labels. `record_screen.dart` now moves the panel in by the left safe-area inset (`media.padding.left`) and the right-hand control rail by the right inset, only on iOS and only in landscape. The panel keeps its right edge (it just gets narrower, so lines wrap a little earlier), so the top bar is not squeezed; the status pill reads "Camera rea…" as it already does in portrait.
- Checked on the iPhone in landscape: all prompter text is visible, and recording a section and the end card still work.
- Android and iPad landscape were not looked at (see "Cross-platform fixes pending" in `signature-features-talkroll.md`).

## §5: macOS retake clap and take list

Commits: `f7a7ace` (native window plugin), `9f95a77` (clap, settings, take list), `0acb195` (close button on the section-done card). macOS only; Auto-scroll, Voice and Narration.

### What was built

- **Retake clap.** A beep, a flash, both or neither fires when a take starts: at the start of each section in a section-by-section run, on every Retake, and once at the start of a whole-script run. Resuming after a pause, or tapping a word and pressing play mid-section, is not a take. The hook is `_beginTake()` in `prompter_controller.dart`, guarded by `Platform.isMacOS`. For Narration it waits until playback really starts (not while the recording is loading), and for Voice until listening has started.
- **Native** (`packages/talkroll_window/macos/.../RetakeClap.swift`, channel method `retakeClap`). The beep is a 0.12 s tone at 1760 Hz generated in code, with a hard start so it is easy to see in a waveform. The flash is a separate white borderless window (160 × 100 pt, 200 ms) in a screen corner, with `sharingType = .readOnly`, so recorders capture it while the prompter stays hidden. It is dismissed when the prompter exits.
- **Settings** (macOS only, General > "Retake clap"): Both / Sound / Flash / Off (default Both), a flash position (default top left), and the line "Helps you find retakes when editing your recording." Saved in `PromptSettings` (`retakeClap`, `retakeFlashCorner`); older saved settings load with the defaults.
- **Take list.** The controller counts attempts per section for the current run (reset on a new run). The Sections panel of the Mac prompter has "Copy take list" and "Share", with the note that the last attempt of each section is the keeper. Format (`takeListText` in `core/script/run_sections.dart`): `Section 2 · Setup ..... 3 attempts (keep the last)`; a section with no attempt reads "no take". Attempts are counted even when the clap is Off.
- **Close button on the section-done card** (not in the spec): a "×" in the card's corner that goes back to Script Studio, like Esc. It is opt-in (`onClose` on `SectionEndCard`), so the camera and Read screens are unchanged.

### Tested

- `flutter analyze` clean; `flutter build macos --debug` builds.
- Automated (`test/retake_clap_test.dart`, `test/section_end_close_test.dart`): take list text, settings round-trip and defaults, clap at each section start and each Retake (not on resume), whole-script run claps once, Sound/Flash/Off, attempts counted, take list resets on a new run, and the close button in the full and compact layouts.
- Native flash: a small harness running the real `RetakeClap.swift`, with `screencapture`, showed the white flash in the top-left corner during the 200 ms and nothing after.
- A test caught a real bug in the first close button (outside its parent's bounds, so not clickable); fixed before the commit.

### Not tested / open

- **Not run:** QuickTime and OBS recordings (the acceptance criterion), the beep by ear or in a waveform, and the full app by hand (settings rows, Sections panel Copy and Share, the "×" on the card, the three layouts). The take list text and the Share sheet were not checked in the running app.
- **Not covered by the spec's wording:** the flash position is a corner picker, not tied to the prompter's own corner; the flash is on the prompter's display; a Voice beep may be heard by the microphone (no words, so no effect on following).
- **Take list scope:** it covers the current run and is available from the Sections panel only. It is lost when the prompter closes; there is no export after the run.
- **Existing failures:** two tests in `test/prompter_controller_test.dart` fail on the committed code before and after this work (`settingsProvider` throws `UnimplementedError` in that test's container).

## §6: Free tier and paywall

Platforms: Android, macOS, iOS. Commits (branch `mobile-redesign`, not pushed): `435a9fb` (demo script presentable at the limit), `36e52e5` (Terms and Privacy links on the paywall), `542e322` (web Privacy and Terms pages), `44ee8c3` (shared pool of 15 free changes, Android and macOS), `20e07a7` (same for iOS), plus doc commits `23c6708`, `cd79397`, `427ece2`.

### Already there before this round

- Free plan of 5 scripts, enforced when `PAYMENTS_APPLE`, `PAYMENTS_ANDROID` or `ENFORCE_FREE_LIMIT` is set. Paywall dialog, upgrade card, debug fake store with `previewPlan(...)`.
- The counter of scripts ever presented (`presented` ids, prefs key `TalkRoll.proState.v1`) survives a reinstall through the iOS Keychain (`ReinstallStore`) and Android Auto Backup (`backup_rules.xml`). macOS keeps it in app data.

### Built and tested

- **Demo script stays presentable at the limit** (Android, macOS, iOS). `canPresentNow` in `services/providers.dart` lets the untouched welcome script start even when the limit is reached.
- **Terms of Use and Privacy Policy links on the paywall** (Android, macOS, iOS). `openExternal` now uses `url_launcher` on Android and iOS; macOS uses `open`. URLs come from `WEBSITE_URL` (default `https://talkroll.app`) in `services/external_links.dart`.
- **Web pages** `web/app/privacy`, `web/app/terms` (shared `LegalPage` component, sticky table of contents, summary cards), linked from the site footer and added to the sitemap. Checked locally and at phone width.
- **Shared pool of 15 free changes (delete, then create)** (Android, macOS, iOS; gate `freeChangesActive` in `core/entitlements/entitlements.dart`).
  - `ProState.live` holds the ids that exist now, refreshed after every save and delete. `changesUsed = presented.length - 5`, capped at 15, so no new stored value and the existing reinstall persistence carries over.
  - Creating a script while at 5 live and under the cap costs one change; deleting does not refund it. A "Use a free change?" dialog (`free_change_prompt.dart`) says "N left, N-1 after this one" with Cancel / Continue.
  - The upgrade card, settings and launch prompt show "N of 15 free changes left" and "No free changes left". At the cap the paywall says "You've used your 15 free changes."
- **Tested on each platform** before moving to the next:
  - **Android emulator:** counters, dialog, Cancel and Continue, block at 5 live, exhausted state, Terms and Privacy open the browser.
  - **macOS (clicked through the real UI, Mac unlocked):** card "4 of 5 scripts used / 14 of 15 free changes left"; "+" then Cancel changes nothing; Continue opens an empty editor; saving flips the card to "All 5 free scripts used"; "+" at 5 live opens the paywall with both links; Terms opened the local page; delete then "+" shows "13 left, 12 after this one", so the delete did not refund a change.
  - **iPhone 15 Pro Max (VM-service touch driver):** card, dialog "14 left, 13 after this one", Cancel keeps the count, Continue moves 6 to 7 presented and the pool 14 to 13, block at 5 live, "No free changes left" at 20 counted, paywall text and links; Terms opened the browser.

### Bugs found and fixed

- The demo script was locked at the limit (fixed on all three).
- The paywall had no Terms or Privacy links (fixed on all three).
- Lint `use_build_context_synchronously` after the dialog changes: guarded with `mounted` checks.
- A first commit wrongly included generated files (`project.pbxproj`, `next-env.d.ts`); it was reset and recommitted by path.

### Not built from §6 (still pending)

- 800-words-per-script limit and the "612 / 800 words" editor counter.
- The >60% word-diff "big rewrite" rule. Typing over the demo script saves as a new script and takes a change without the warning dialog.
- Android Block Store (reinstall persistence uses Auto Backup only).

### Not tested / open

- **Reinstall persistence** was not checked on any platform; iPad was not run.
- On the iPhone only `canPresentNow` was checked for the demo; its Start button was not tapped.
- **iPhone test state:** the 20-script library cap dropped the phone's oldest test script when the test script was saved. The phone's counter was rebuilt with 8 real ids plus filler (34 total) and the plan is Lifetime, so limits do not apply there.
- **No migration:** users who deleted many scripts under the old rule start with fewer changes.
- **Web pages are not deployed**, so the paywall links show "site can't be reached" (iOS) or 404 until `web/` is deployed.
- **Legal text is a draft** (Arjun Sah as controller, Portuguese law, CNPD, liability cap of 12 months of payments) and needs the owner's review.
- `ios/Runner.xcodeproj/project.pbxproj` was modified by Xcode (generated), left uncommitted.
