# Narration on iPhone / iPad: code review and test plan

Status: reviewed by reading the code and compiling (`flutter build ios --no-codesign --debug` succeeds). Not yet run on a device. To be tested on a real iPhone over USB (the Simulator has no on-device speech models worth trusting).

## What was reviewed

- `packages/echoprompter_camera/ios/echoprompter_camera/Sources/echoprompter_camera/FileTranscriberChannel.swift` (identical to the macOS copy). Channel `com.echoprompter/transcribe`; methods `isSupported`, `transcribe`, `cancel`; progress goes back as `progress`.
- On iOS 26 and later it uses `SpeechAnalyzer` (`SpeechTranscriber`, else `DictationTranscriber`; the system installs the language pack on first use and every locale is released after use). Otherwise, or if that fails, it uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`. If the language has no offline model it refuses with `unavailable` and a message pointing at Settings > General > Keyboard > Dictation. The recording is never sent to a server.
- Only the **Speech Recognition** permission is asked for (`NSSpeechRecognitionUsageDescription`, updated to mention narration). Narration never asks for the microphone on iOS: the Dart code requests microphone only on Android, and `Info.plist` strings are the only prompts.
- Playback is `just_audio` (`AudiblePlayback`), position-driven; no `AVAudioEngine` input is touched.

## Things to watch (not yet proven)

1. Long recordings: the older recogniser works in stretches of about a minute and the results are merged; the newer analyzer reads the whole file. A 3:59 file tested on iOS 26 (787 of 790 words).
2. Silent switch: `just_audio` uses the playback category, so audio should play with the switch on silent.
3. Narration + camera (Record screen): the recording must contain the narration from the speaker, and the camera's audio session must not mute or duck it.
4. Offline: turn on Airplane mode and transcribe a file that is not cached; it must still work.
5. Language without an offline model (for example one not downloaded in Dictation settings): the message should be clear, and nothing is uploaded.
6. Permission denied for Speech Recognition: the card shows the denied message; turning it back on in Settings and choosing the file again works.
7. File types from the Files app: m4a, mp3, wav, and a Voice Memos export.
8. iPad: the Narration card in the start sheet, the 5 s skip buttons, and rotation.

## Test checklist (on the phone)

Use a script of at least two paragraphs (60 words or more) and a recording of it.

- Choose recording: progress runs to 100%, "N% matches your script" shows 90% or more.
- Start: Narration chip and "Following audio" show; highlight follows the voice.
- Pause, Play, Restart, Back 5 s, Forward 5 s, tap a word (controls visible), Sync offset slider (±500 ms).
- Play to the end: "End of script", play icon.
- Close and reopen the app: the recording is still linked and the transcript is cached (no second transcription).
- Switch to another script and back: the card shows the right recording for each.
- Low match: choose an unrelated recording; the warning, Continue anyway, and Choose another file all work.
- Cancel during transcription returns to the chooser.
- Mic check: no microphone prompt appears at any point in Narration or Auto-scroll; Voice mode still asks as before.
- Narration + camera: record a short video; the narration is audible in the saved video.
