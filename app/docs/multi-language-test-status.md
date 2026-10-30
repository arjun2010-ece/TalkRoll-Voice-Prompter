# Multi-language: what has been tested, and what is left

Status as of 2026-10-30, branch `mobile-redesign`. Platforms in scope: macOS, iOS, iPadOS, Android (Windows is dropped).
See `multi-language-plan.md` (plan, decisions), `macos-reference-language-comparison.md` (how the macOS reference app
does it) and `android-voice-reference-parity.md` (Android recogniser).

How a test counts: the script is opened in **Voice** mode, the language is **Automatic** unless noted, and a spoken
sentence is played or read. "x of y" is how many script words the highlight reached. Synthetic voices (`say`) played
through the Mac speakers into the device microphone are noisy: the same voice can vary from run to run, and some
voices (Portuguese Luciana, Joana) are poorly recognised by an iPhone through the air. Treat a result as "works" only
when a clean run reaches the end of the script.

## 1. Tested

| Language | macOS | iPhone (real device) | iOS simulator | Android emulator |
|---|---|---|---|---|
| English | 100% | 20 of 21 | not possible | 100% |
| Portuguese (Brazil) | 100% | natural voices 23 of 24 (Eddy, Sandy, Reed); reading aloud in your own voice works | not possible | 100% |
| Portuguese (Portugal) | not run | worked in your own voice (setting not recorded) | not possible | not run |
| Spanish | 100% | 19 of 20 | not possible | passed in an earlier run; a later run stalled on a typo in the test script (see 3.3) |
| French | 100% | 22 of 23 | not possible | not run |
| Italian | 100% | 19 of 20 | not possible | not run |
| Chinese (Simplified) | 100% | 19 of 20 | not possible | not run |
| Thai | 100% (followed by letters) | 4 of 5 | not possible | hidden on Android |
| Japanese | passed | not run | not possible | not run |
| Arabic | passed | not run | not possible | not run |
| Hebrew | passed | not run | not possible | not run |

Other things verified:

- **Automatic detection** (Apple's language recogniser) gave the right language for English, French, Italian, Spanish,
  Portuguese, Chinese and Thai on macOS, and for Portuguese, French, Chinese, Thai and English on the iOS simulator
  (list of supported languages, region choice).
- **Language picker** lists only languages the device supports; a language the device cannot recognise shows a
  message that names the fix (macOS: Dictation > Languages).
- **"Different Language Detected"** prompt (a fixed language that differs from the script): macOS English fixed with a
  French script, Use and Keep both work, and it is not asked again for the same script. Not tried on iOS or Android
  (Apple only; Android never asks).
- **Regressions checked** after each change: English, Spanish, French and Chinese on macOS; the eight-language run on the
  iPhone before and after the idle-limit change (section 3).

## 2. Not tested yet (for when there is time)

Never spoken on any platform:

- European languages: German, Dutch, Swedish, Danish, Norwegian, Finnish, Polish, Czech, Slovak, Slovenian, Croatian,
  Hungarian, Romanian, Bulgarian, Greek, Catalan, Russian, Ukrainian, Turkish.
- Asian and other: Korean, Hindi, Indonesian, Malay, Vietnamese, Cantonese, Chinese (Traditional).
- Regional variants: English (UK, Australia, India), Spanish (Mexico, US), French (Canada), Portuguese (Portugal) on
  macOS and Android.

Platform gaps:

- **iPad**: nothing spoken on a real iPad. It shares the iPhone's code, so it should match, but it is unverified.
- **iPhone**: Japanese, Arabic, Hebrew; Portuguese (Portugal) set by hand with a recorded result; a language whose
  offline model is not installed (the fallback to Apple's servers and the model download on iOS 26 and later).
- **Android, real phone**: nothing. The emulator tests used synthetic voices; the Android 14+ language-pack download
  prompt and `checkRecognitionSupport` need a physical phone. French, Chinese, Japanese and the rest are not run on Android
  at all.
- **macOS**: German (its dictation model was installed on the dev Mac but German was not spoken), Korean, and every language in the first group above.
- **Error rules** (301 quiet, 201 stops on the second, 1700 means the request was rejected, five failures stops): compiled
  and read from the reference code, but never triggered by a real recogniser error.
- **Own-voice testing** in languages other than Portuguese. Synthetic voices are a weak proxy.

## 3. Known issues and limits found while testing

1. **iOS microphone on the reading screen** (fixed, commit `c95f2a3`): iOS only had audio while a camera preview was
   running, so Voice mode on the voice-only reading screen listened to silence ("Listening", no error, no words). It now
   opens its own microphone capture when there is no camera preview.
2. **iOS idle limit** (fixed, commit `29fdd6b`; one line in `SpeechRecognizerChannel.swift`): iOS
   ended a recognition session after 1.5 s without new words. Portuguese's offline recogniser on the iPhone often pauses
   longer than that between sentences, and each restart lost speech. The limit is now 10 s. A repeatable test (a
   Portuguese passage with 1.8 s pauses fed straight into the recogniser) tracked 9 of 25 words before and 24 of 25 after,
   both times. Microphone runs of the other seven languages were unchanged. It affects every language on iPhone and iPad
   only; macOS and Android have their own code.
3. **Test-method limits**: the iOS simulator cannot test speech (no microphone input from the Mac, and its Speech engine
   fails with `kLSRErrorDomain 300`); use a real device. Android emulator Spanish stalled only because the test script had
   a typo ("tar de") and the synthetic voice mis-heard words; the same stall happens on the unchanged code.
4. **Thai** is not in the reference app's behaviour: it has no spaces, so it is followed by letters (Apple only).
   Chinese and Japanese are followed per character. Accents must match (same as the reference).

## 4. How to repeat a test on a real iPhone

1. Plug the phone in, unlock it, trust the Mac, turn on Developer Mode, and trust the developer profile on the phone.
2. `flutter run -d <iPhone>` for a debug run, or `flutter build ios --release` and `xcrun devicectl device install app`
   for a standalone build that opens from the home screen.
3. Open a script in the language, choose Voice, press Start, and read it aloud. Note the language setting
   (Automatic or fixed), what the status line says, and how far the highlight goes.
4. Add the result to the table in section 1.
