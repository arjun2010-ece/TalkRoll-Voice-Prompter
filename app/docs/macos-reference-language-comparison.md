# Multi-language: macOS reference app vs our implementation

Status: **analysis only, nothing changed in code.** Source: the decompiled macOS reference app
(`~/Downloads/mac-vp/decompiled`, VoicePrompter 4.0.2, arm64, Ghidra; method names are stripped, so functions are
`FUN_<address>`). Compared with our code on branch `mobile-redesign` (commits `9555cb6` to `e8fcf45`).

This replaces the guesses in `multi-language-plan.md` §1, which came from the reference's **Android** app. The macOS app
is Swift on Apple's own APIs, so it is the better model for our macOS, iOS and iPadOS side. Only macOS was decompiled;
an iOS build of the reference may differ.

Confidence: **[read]** seen in decompiled code or strings, **[inferred]** reasoned from partly garbled output,
**[not found]** looked for and absent from the binary.

## 1. How the macOS reference handles languages

1. **Recogniser** [read]: one `SFSpeechRecognizer(locale:)` per listen (`FUN_1001046c0`). Before starting it checks
   `isAvailable` (`FUN_100105560`). It sets `requiresOnDeviceRecognition = supportsOnDeviceRecognition`
   (`FUN_100107de0`), so it uses the offline model when the Mac has one and Apple's servers otherwise. It also sets
   `shouldReportPartialResults` and `contextualStrings` (up to 150 script words, `FUN_1001d3030(0x96)`). Entitlements
   include `network.client`; minimum macOS 15.
2. **No model download** [not found]: no `AssetInventory`, `DictationTranscriber`, `SpeechAnalyzer` or
   `SpeechTranscriber` anywhere in the binary strings. When a language is missing it tells the user to add it in System
   Settings > Keyboard > Dictation > Languages, to be online, and to wait for the download (strings at `10024cfd0`,
   `10024a250`, `10024e6f0`). An onboarding step and a dismissible banner push the same setup.
3. **Language list** [read]: `SFSpeechRecognizer.supportedLocales()` (`FUN_100073e70`), sorted with `en-US` first
   (`FUN_100074000`), shown with the system's localised names (`Locale.localizedString(forIdentifier:)`). Regional
   variants of one language get region labels [inferred, `FUN_10006c5e0`]. The picker has an **Automatic** row plus
   this list, in Settings > Scrolling and as a language chip in the prompter's dock. The choice is stored under
   `recognitionLanguage` and "is kept across scripts and app launches" (help text `10024dd50`).
4. **Automatic detection** [read]: `NLLanguageRecognizer.dominantLanguage` over the whole script (`FUN_100074460`;
   a blank script is skipped, `FUN_100072c60`). The result is mapped onto a locale this Mac supports
   (`FUN_10018a2f0`): candidates are the supported identifiers with the same language, and script when both have one
   (`FUN_10018bd40`, so `zh-Hans` and `zh-Hant` stay apart), sorted by identifier; the first candidate equal to, in
   order, the current choice, the system locale, `en-US`, or the detected code wins, else the first candidate
   [inferred order]. Nothing detected gives `en-US`. Detection runs on every script change.
5. **Mismatch prompt** [read]: when the user has fixed a language (not Automatic) and a script is detected as a
   different one, an `NSAlert` titled "Different Language Detected" asks "Which language would you like to use? Your
   choice will be kept for future scripts." with **Use <detected>** / **Keep <chosen>** (`FUN_100074720`). Conditions
   on two stored flags are [inferred].
6. **Errors** [read, `FUN_1001d6e20`, domains decoded from the packed strings]. `kLSRErrorDomain` 201, 301 and
   `kAFAssistantErrorDomain` 1110, 1700 get special treatment; any other error adds to a consecutive-failure count that
   stops listening after the fifth. 301 and 1110 restart quietly; 201 stops on the second occurrence; 1700 stops at
   once. The count resets when a result contains speech. Four messages exist: language unavailable, failed repeatedly,
   Siri/Dictation disabled, permissions allowed but request rejected (`100103bc0`, strings `10024cfd0` to `10024d310`).
   Which code maps to which message is [inferred]. There is **no switch to the servers after an on-device error**; it
   relies on `supportsOnDeviceRecognition` alone.
7. **Script text** [read]: the script is split on newlines (`FUN_1001d6280`); words for display come from
   `NLTokenizer(unit: .word)` with `setLanguage` set to the effective locale's language code (`FUN_1001d4f20`), so
   Chinese, Japanese and Thai are segmented by Apple's tokenizer. Word matching normalises with `lowercased()` and a
   split on non-alphanumerics (`FUN_1001d4600`); **no diacritic folding** exists in the binary [not found]. Text in
   `[square brackets]` is ignored. Sentence navigation skips sentences under 20 letters or digits. I found no
   CJK-specific code in the matcher itself; how recogniser segments for Chinese are paired with tokenizer words is
   unresolved.
8. **Voice commands** [read]: a 37-language enum (`goStart goNext goBack goFinish nextSentence previousSentence
   toggleMirroring toggleFollowMouse startRecording stopRecording`, plus special `hi-Latn`, `yue-Hans`, `zh-Hant`
   variants), phrases follow the recognition language and are user-editable. We dropped voice commands, so this is out of
   scope.
9. **Text direction** [inferred]: `leftToRight`/`rightToLeft` and `setBaseWritingDirection:` appear in the strings; I
   did not trace whether they are automatic or a user setting.

## 2. Side by side

| Area | macOS reference | Ours (macOS / iOS / iPadOS) | Verdict |
|---|---|---|---|
| Recogniser per language | `SFSpeechRecognizer(locale:)` | same | match |
| On-device preference | `requiresOnDevice = supportsOnDevice` | same | match |
| Server fallback after on-device error | none | yes (`onDeviceFailed`) | ours is a superset |
| Model download | none, points to Dictation settings | OS 26+ `AssetInventory` download | ours is a superset; keep |
| `contextualStrings` | script words, 150 | script bias words | match |
| Language list | all `supportedLocales`, localised names | fixed 43 tags filtered by `supportedLocales` | gap, small (see 3.6) |
| Automatic detection | `NLLanguageRecognizer` on the script | letter counts per script plus marker letters (`speech_languages.dart`), port of the Android reference | **gap, large (3.1)** |
| Detected tag to supported locale | picks a locale this device supports | picks from our list; unsupported gives "can't recognise <name>" | gap (3.2) |
| Fixed choice vs a different script | asks Use / Keep | silently keeps the choice | gap (3.3) |
| Chinese, Japanese, Thai words | `NLTokenizer(.word)` | per-character for Han/kana; Thai hidden | gap (3.4) |
| Accent handling | exact (no folding) | exact | match |
| Arabic/Hebrew vowel marks | no stripping found | stripped on both sides | ours differs, harmless |
| Error recovery | 201/301/1110/1700 rules, stop after 5 | 1110/203 quiet, dictation-off cases stop, stop after 5 | close (3.5) |
| Missing-language guidance | names the System Settings path | generic wording | gap, small (3.5) |
| Setting persistence | kept across scripts and launches | `speechLanguage` in settings | match |
| Voice commands in each language | yes | not built (dropped) | out of scope |

## 3. Differences worth deciding on

1. **Automatic detection is much weaker on our Apple side.** Our detector only places non-Latin scripts and a few Latin
   marker letters (ł, ß, ñ, ã, ř, ğ, ő, ơ ...). French, Italian, Dutch, Swedish, Danish, Finnish, Romanian, Catalan and
   most German or Spanish text without those letters fall through to `en-US`, so Automatic listens in the wrong
   language and the script never tracks. The reference gets these from `NLLanguageRecognizer`. This heuristic was right
   to copy for Android (the Android reference does the same), but not for Apple. Fix: a small native method on the macOS
   and iOS channels that returns `NLLanguageRecognizer.dominantLanguage`, called by `resolveSpeechLanguage`; keep the
   Dart detector for Android.
2. **Map the detection onto what the device supports.** Do it as the reference does: among supported locales of that
   language (and script), prefer the current choice, the system locale, `en-US`, then the first. Today `_variantOf` picks
   from our fixed list and a regional gap shows up as an error at listen time.
3. **Use/Keep prompt** when a fixed language disagrees with the script. Needs a Flutter dialog fed by the same detector;
   worth it once item 1 exists, because it then also covers a user who left a stale choice.
4. **Tokenisation of Chinese, Japanese and Thai.** `NLTokenizer(.word)` is the reference's answer and it also makes
   Thai possible, which we hide. Our per-character split works (tested on macOS) but is not word-aware. Apple-only; Android
   keeps what it has.
5. **Errors and wording.** Keep our server fallback. Consider the reference's 201-twice and 1700-stop rules and its
   wording that names Dictation > Languages, which is the thing a Mac user must act on.
6. **Picker list.** The reference shows every `supportedLocale` with localised names; we show our 43. Small: it only
   hides regional variants such as `en-ZA` or `de-AT`.

Not worth copying: the reference never downloads models (ours does on OS 26+), and its voice commands.

## 4. Limits of this analysis

- Only macOS was decompiled; iOS and iPadOS behaviour is assumed to match.
- The exact preference order in 1.4, the alert conditions in 1.5 and the code-to-message mapping in 1.6 come from
  partly garbled decompilation; confirm by testing the real app before copying them exactly.
- How the reference pairs recogniser output with tokenizer words for Chinese and Japanese is unresolved.
- A real 4.0.2 run (e.g. a French script on Automatic, a Spanish script with English fixed) would settle items 1.4,
  1.5 and 3.1 in minutes and is the cheapest way to check this document.
