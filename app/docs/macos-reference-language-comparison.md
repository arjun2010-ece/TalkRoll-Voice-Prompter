# Multi-language: macOS reference app vs our implementation

Status: **analysis; gaps 1 to 4 are done in code (see §5; gap 4 differs from the reference, see §3.4).** Source: the decompiled macOS reference app
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
   (`FUN_10018a2f0`). Candidates are the supported identifiers whose language (and script, `FUN_10018bd40`: it calls
   `languageCode`, `script` and `==`; its body did not decompile, so exactly how a missing script compares is
   [inferred]) equals the detected one, sorted by identifier. The preference list is **four strings, read from the
   call: the user's current choice (`recognitionLanguage`, which is "auto" in Automatic and so matches nothing), the
   system locale identifier, `"en-US"`, then the detected code**. Each is compared to each candidate as a whole tag
   (`_` as `-`, lowercased); the first equal candidate wins, otherwise the first candidate by sort order. Nothing
   detected gives `en-US` (`FUN_100072c60`). Consequences: on an `en_IN` Mac an English script gets `en-IN`; Spanish,
   French and Portuguese fall to the first sorted tag the Mac lists (`es-419`, `fr-BE`, `pt-BR`).
5. **Mismatch prompt** [read, `FUN_100072c60`, run when a script is set or changed, not on Start]: an `NSAlert`
   titled "Different Language Detected" (`FUN_100074720`): "<script language>. Your recognition language is set to
   <choice>. Which language would you like to use? Your choice will be kept for future scripts." with **Use <detected>**
   and **Keep <choice>**. Conditions, all required: the script is not blank; `isEditing` is false (the state reset in
   `FUN_100073b40` sets it with `editingReadingPosition`; the property name is [inferred] from its `didSet`,
   `FUN_100067bb0`); the scrolling mode is the first of three (`voiceTracking`, `voiceActivated`, `constantSpeed`, the
   persisted raw values in `FUN_10006a140`); a language was detected; the choice is not "auto"; and the detected
   language differs from the choice (`FUN_10018a2e0`, the same comparison as above).
6. **Errors** [read, classifier `FUN_1001d6e20`, messages `FUN_100103bc0` area, start `FUN_100105560`]. Domains and
   codes decoded from the packed strings. A stop carries one of four reasons, each with its own message:
   - reason 0, Siri or Dictation disabled: `kLSRErrorDomain` **201 on the second consecutive time**; the first time it
     is retried like any other error.
   - reason 1, failed repeatedly: the **fifth** consecutive other error.
   - reason 2, "unavailable for the selected language": the recogniser could not be made or `isAvailable` is false when
     listening starts (`FUN_100105560`, `0x8002`).
   - reason 3, "permissions are allowed, but macOS rejected the recognition request": `kAFAssistantErrorDomain`
     **1700**, at once.
   - Quiet restarts: `kLSRErrorDomain` 301 (cancelled) and `kAFAssistantErrorDomain` 1110 (no speech).
   The count resets when a result has speech. There is **no switch to the servers after an on-device error**; it
   relies on `supportsOnDeviceRecognition` alone. (An earlier version of this document, and a change made from it,
   read 1700 as "language unavailable"; that was wrong and is corrected.)
7. **Script text** [read]: the script is split on newlines (`FUN_1001d6280`) and words on whitespace, for every
   language. Word matching normalises with `lowercased()` and a split on non-alphanumerics (`FUN_1001d4600`); **no
   diacritic folding** exists in the binary [not found]. Text in `[square brackets]` is ignored. The `NLTokenizer` in
   `FUN_1001d4f20` is created with unit **1 = sentence** (`NLTokenUnit.sentence`), and its results are kept only when
   they hold at least 20 letters or digits: it serves **sentence navigation**, not word splitting (an earlier version
   of this document read it as a word tokenizer, which was wrong). I found no Chinese, Japanese or Thai word
   segmentation anywhere in the matcher.
   **Chinese** [read]: the matcher (`FUN_1001d3570`) is the same algorithm as the Android `ju3`: it compares whole
   tokens, where the script's words are whitespace-split and normalised, and the recogniser's text is lowercased and
   split on non-alphanumerics (`FUN_1001d4600`; CJK ideographs count as alphanumeric, so a run of Chinese is one
   token). It has no segmentation and no fuzzy or prefix comparison (`FUN_1001d4390` only compares strings). So the
   reference can only match Chinese at the granularity the script and the recogniser happen to share, in practice a
   whole unspaced line or clause; our per-character matching tracks it more finely. Not run in the real app.
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
| Automatic detection | `NLLanguageRecognizer` on the script | letter counts per script plus marker letters (`speech_languages.dart`), port of the Android reference | done (3.1) |
| Detected tag to supported locale | picks a locale this device supports | picks from our list; unsupported gives "can't recognise <name>" | done (3.2) |
| Fixed choice vs a different script | asks Use / Keep | silently keeps the choice | done (3.3) |
| Chinese, Japanese, Thai words | whitespace split, no segmentation found; Thai not followable | per-character for Han/kana; Thai followed by letters (Apple only) | ours goes further (3.4) |
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
4. **Chinese, Japanese and Thai.** The reference does not segment words (see 1.7), so it follows Thai no better
   than we did: Apple's Thai recogniser reports a sentence with **no spaces**, and a script split on spaces tracked
   only its first words. We went beyond the reference: when most of a script's letters are Thai, `ScriptTracker`
   follows it by letters (the last letters of the hypothesis are looked up in the script's letters ahead of the cursor,
   nearest first, longest run first, at least three letters). Thai is listed on Apple only. Chinese and Japanese keep
   the per-character split, which already worked.
5. **Errors and wording.** Keep our server fallback. Consider the reference's 201-twice and 1700-stop rules and its
   wording that names Dictation > Languages, which is the thing a Mac user must act on.
6. **Picker list.** The reference shows every `supportedLocale` with localised names; we show our 43. Small: it only
   hides regional variants such as `en-ZA` or `de-AT`.

Not worth copying: the reference never downloads models (ours does on OS 26+), and its voice commands.

## 4. Limits of this analysis

- Only macOS was decompiled; iOS and iPadOS behaviour is assumed to match.
- Read from the code now: the locale preference order (1.4), the prompt conditions (1.5) and the error-to-message mapping
  (1.6). Still inferred: how a missing script subtag compares in `FUN_10018bd40` (its body did not decompile) and the
  name of the `isEditing` flag.
- Not run in the real reference app (it cannot be run here), so none of this was observed live.
- Where we differ on purpose: English stays `en-US` and Spanish, French and Portuguese default to Spain, France and
  Brazil (the reference would give `en-IN`, `es-419`, `fr-BE` on this Mac); the prompt is asked on Start, not when the
  script changes; Thai and per-character Chinese tracking go beyond the reference.

## 5. Done so far

- 3.1 Automatic detection from Apple's `NLLanguageRecognizer` (macOS, iOS, iPadOS); Android keeps its heuristic.
- 3.2 The detected language's region is chosen from the device's own supported locales, `en-US` when it has none.
- 3.3 "Different Language Detected" (`lib/ui/speech_language_prompt.dart`): on Start in Voice or Audio mode, when a fixed
  language differs from the script's (needs four or more words). **Use** sets the detected language as the setting;
  **Keep** (or closing the dialog) keeps it and does not ask again for that script until the app restarts. Apple only.
  Verified on macOS: English fixed + French script gave the prompt, Use tracked French to 100%, Keep went on without
  asking again; Automatic English and Spanish and Normal mode were unaffected.
- 3.4 Thai (`lib/core/matching/script_tracker.dart`, `_updateUnspaced`): verified on macOS with Apple's Thai recogniser
  and a spoken script: 100% on a clean transcript. A poor transcript (the synthetic voice at a low volume was
  recognised as other Thai words) cannot be tracked by any matcher. The Spanish transcript replayed through the changed
  tracker gives the same cursors as before; English and Chinese scripts take the old path.
- 3.5 Errors (macOS, iOS, iPadOS): 301 is a quiet restart; 201 stops on the second in a row; 1700 stops at once with the
  "rejected the recognition request" message; the fifth failure uses the "failed repeatedly" message naming the
  Dictation languages path. Built for macOS and the iOS simulator; the macOS language message was seen in the app before
  this re-read, the error-code rules were not exercised (they need real recogniser errors).
