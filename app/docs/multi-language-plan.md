# Multi-language voice tracking: reference findings and our plan

Status: **plan only, not implemented.** Sources: the decompiled reference app (`~/projects/vp-apk/work/jadx-out/sources/`,
see `voice-tracking-handoff.md`) and our code as of branch `mobile-redesign`. Confidence: **[read]** from decompiled
code, **[inferred]** reasoned from garbled output.

## 1. How the reference app does multiple languages

1. **Two speech backends** (`app/voiceprompter/speech/SpeechBackend`) [read]: `SYSTEM` ("Google / device default",
   Android `SpeechRecognizer`) and `OFFLINE` ("Offline (Vosk)"). Each `OfflineModel` has `id, locale, name, url, sha256,
   downloadBytes, installedBytes, archiveRoot, license`, so every offline language is a separate model download.
2. **A fixed list of 44 language tags** (`defpackage/kw2.java:93`) [read]: en-US, en-GB, en-AU, en-IN, ar-SA, bg-BG,
   ca-ES, cs-CZ, da-DK, de-DE, el-GR, es-ES, es-MX, es-US, fi-FI, fr-CA, fr-FR, he-IL, hi-IN, hr-HR, hu-HU, id-ID,
   it-IT, ja-JP, ko-KR, ms-MY, nb-NO, nl-NL, pl-PL, pt-BR, pt-PT, ro-RO, ru-RU, sk-SK, sl-SI, sv-SE, th-TH, tr-TR,
   uk-UA, vi-VN, yue-Hant-HK, zh-CN, zh-TW. `en-US` is sorted first; the rest are sorted by display name
   (`u74.c` = `Locale.forLanguageTag(tag).getDisplayName()`).
3. **Language setting = a tag or `"auto"`** (`rg3.w()`) [read]. In `auto` the app first detects the language from the
   *script text* (see our `android-voice-reference-parity.md` correction: Latin text with no language-specific letters
   gives no detection, so `en-US`). Where the script gives nothing, `pt3.java:683` falls back to the device locale
   (`Locale.getDefault().getLanguage()`) matched against the list, and then to `en-US`.
4. **The chosen tag goes straight to the recogniser** as `EXTRA_LANGUAGE`. The on-device model pack is requested per
   language (language-pack download, `ModelDownloadListener`).
5. **Per-language voice-command tables** (`o15`/`vl1`) for ~37 locales (handoff §6). We dropped voice commands, so this
   does not apply to us.
6. **Localised sample text** for the voice test (`kt3.java:1662`): 17 languages (ar, de, en, es, fr, hi, it, ja, ko, nl,
   pl, pt, ru, tr, uk, zh ...). RTL handling exists for `ar` and `he` (`g55.java:89`).
7. The script-matching code is language-agnostic (it compares tokens); only the recogniser and the command tables are
   per-language.

## 2. What our app supports today

**English only, on every platform.**

| Platform | Evidence | State |
| --- | --- | --- |
| Android | `SpeechChannel.kt:645` `LANGUAGE = "en-US"`, used for `EXTRA_LANGUAGE`, the on-device pack download (`:407`) and the fallback; user message "can't recognize English" (`:646`) | Hard-coded en-US |
| iOS / iPadOS / macOS | `SpeechRecognizerChannel.swift` in `packages/echoprompter_camera` (iOS) and `packages/echoprompter_window` (macOS) | Hard-coded `Locale(identifier: "en-US")` before this work (the first version of this plan wrongly said Apple had no implementation; it lives in the packages, not in `ios/` or `macos/`) |
| Windows | Not in scope of this request; the engine decision doc says `Windows.Media.SpeechRecognition` | n/a |
| Dart | `NativeSpeechRecognizer` has no language argument; `NativeRecognizerUnavailable` says "no recogniser ... for English" | English assumed in the API and the copy |

What is already language-friendly: `lib/core/script/text.dart` and `script_tracker.dart` use Unicode-aware regexes
(`\p{L}`, `\p{N}`), and the matcher compares tokens, with no English word lists in `lib/core/matching/`.

What is English-biased or risky for other languages:

* **Word splitting uses whitespace** (`word_layout.dart:36`, `sections.dart:11` `\S+`). Chinese, Japanese and Thai have no
  spaces, so one "word" would be a whole sentence and highlighting and matching would not work.
* `TextDirection.ltr` is fixed in `word_layout.dart:41`; Arabic and Hebrew need RTL.
* Tracker constants (`_tailLength = 6`, the apostrophe regex, short-word rules) were tuned on English.
* Recogniser output differs by language (numerals, punctuation, spacing in CJK), so `normalized` needs per-language
  rules.
* App UI strings are not localised (separate from script language; out of scope here).

## 3. Plan

Goal: the reader picks the language they read in; Voice mode (and Audio mode) uses it. Platform recognisers only; no
Vosk/sherpa model downloads, so no app-size or hosting cost.

### Phase 1: language setting and plumbing (all platforms, no new risk)

1. Add a `speechLanguage` setting (default `auto`) to the settings store, shown in Settings → Voice as a searchable list.
   Use the reference's 44 tags as the candidate list, **filtered at runtime to what the device actually supports** (below),
   instead of hard-coding it as the reference does.
2. Dart API: `NativeSpeechRecognizer.supportedLanguages()` and a `language` argument on `hypotheses(...)` (event
   channel args, next to `micFallback`/`headset`). `setBias` unchanged.
3. `auto` resolution in Dart (one place): script-language detection first (Unicode-script based: Cyrillic, Greek, Arabic,
   Hebrew, Devanagari, Thai, Hangul, kana/Han; Latin falls to the device locale, then `en-US`), then the device locale, then
   `en-US`. This keeps English scripts at `en-US`, matching the reference.
4. Replace the English-specific copy in `NativeRecognizerUnavailable` and `LANGUAGE_MESSAGE` with a message that names
   the chosen language.

### Phase 2: native recognisers

* **Android** (`SpeechChannel.kt`): replace `LANGUAGE` with the value passed from Dart. Keep the existing fallback chain
  (on-device → system), but use `checkRecognitionSupport` / `triggerModelDownload` with the chosen tag, and
  `getSupportedLanguages` (API 33+) for `supportedLanguages()`. Below API 33, offer only the languages the system
  recogniser reports through `ACTION_GET_LANGUAGE_DETAILS`. The existing `ERROR_LANGUAGE_NOT_SUPPORTED/UNAVAILABLE`
  handling already routes to the system recogniser; just change the final message.
* **iOS / iPadOS / macOS** (when the Apple channel is written): create `SFSpeechRecognizer(locale: Locale(identifier: tag))`
  per session, take `supportedLocales()` for the list, and use `supportsOnDeviceRecognition` to mark which languages
  work offline (others need the network; show that in the picker and respect `requiresOnDeviceRecognition`). Remove
  the "hard-coding en-US can produce nothing useful on a Mac" fallback reasoning once the locale is explicit.
  macOS also needs the matching Dictation language enabled; extend `readiness()` with a `dictationLanguage` key.

### Phase 3: script handling for non-English text

1. **Tokenisation.** Replace `\S+` splitting with a shared tokenizer: whitespace for space-delimited languages;
   ICU word boundaries for `ja`, `zh`, `yue`, `th` (Dart has no built-in segmenter, so use a platform channel to
   `NSLinguisticTagger` / `BreakIterator`, or character-level tokens for CJK as a first cut). The tracker, highlighter
   and word layout must all use the same tokens.
2. **RTL.** Derive `TextDirection` from the script language (`ar`, `he`) in the word layout and prompter screens, and
   check mirror mode and the highlight direction.
3. **Matching.** Make `normalized` language-aware (strip Arabic/Hebrew diacritics, Fold full-width forms, normalise
   numerals to digits in both script and transcript, handle apostrophes/`l'`/`d'` in French and Italian). Re-tune
   `_tailLength` and the short-word rule per language group. Keep the "fall behind rather than skip ahead" bias.
4. **Recorded Audio mode** uses the same recogniser language; apply Phase 1 plumbing there.

### Phase 4: test and release

* Ship in stages: Phase 1-2 with space-delimited languages first (es, fr, de, pt, it, nl, pl, ru, uk, tr, hi, ...),
  then RTL, then CJK/Thai only after tokenisation is proven.
* Reuse the `tools/voice_latency` harness with one recorded script per language group (Latin, Cyrillic, RTL, CJK) and
  compare against the platform recogniser's own transcript, as in the English runs.
* Tests only when you ask for them (project rule).
* Store listing and website: check `web/` copy and store text for outdated "English only" statements when a language ships.

### Decisions (follow the reference app)

1. **Languages:** offer the reference's full list of 44 tags, filtered to what the device reports as supported. The
   staging in Phase 4 is only the order of building and verifying; CJK/Thai/RTL entries stay hidden until Phase 3
   handles them for that language.
2. **Voice-test sample text:** localise it for the same 17 languages the reference covers (ar, de, en, es, fr, hi, it, ja,
   ko, nl, pl, pt, ru, tr, uk, zh, ...; texts at `kt3.java:1662+` can be translated the same way). Any other language
   falls back to the English sample.
3. **Network recognisers:** allowed. The reference's `SYSTEM` backend ("Google / device default") uses whatever the device
   recogniser does, and offline is the optional extra. We do the same: on-device when the language has a pack, otherwise
   the system recogniser, with an "may use internet" label in the picker. No separate opt-in screen.
4. **`auto` vs an explicit choice:** an explicit tag always wins and is passed to the recogniser unchanged (reference:
   `auto` is resolved only when the setting equals `"auto"`, otherwise `rg3.w()` is used as is).

### Rough effort

Phase 1: ~1 day. Phase 2 Android: ~1 day; Apple: part of the Apple recogniser work. Phase 3 spaced languages (RTL, matching
tuning): 2-3 days. CJK/Thai tokenisation: 3-5 days plus testing with native speakers.

## 4. Implementation status (2026-10-29)

Done, in stages, each stage built (`flutter analyze`, `flutter build macos/apk/ios --debug`):

1. **Setting and API.** `lib/services/speech/speech_languages.dart` (44 tags, port of the reference detector `rg3.e0`/`g0`,
   `resolveSpeechLanguage`), `PromptSettings.speechLanguage` (default `auto`), `NativeSpeechRecognizer.supportedLanguages()`
   and a `language` argument on `hypotheses`, `PrompterController` resolves the language at each Voice/Audio start,
   `lib/ui/speech_language_row.dart` (Settings → Voice language, searchable, narrowed to what the device reports).
2. **Native.** Android `SpeechChannel.kt` (language from Dart, `supportedLanguages` via `checkRecognitionSupport`, message
   names the language); macOS and iOS `SpeechRecognizerChannel.swift` (recogniser built per listen from the tag,
   `supportedLanguages` from `SFSpeechRecognizer.supportedLocales()`).
3. **Script text.** Chinese/Japanese split per character (script and speech use the same rule), combining marks stay in
   their word (Hindi, accents), Arabic/Hebrew vowel marks dropped on both sides, right-to-left layout for Arabic/Hebrew
   scripts. Thai is not offered yet (no word splitting).

Deviation from section 3: `auto` follows the reference exactly (plain Latin text is `en-US`; only `ñ`, `ã/õ`, `ß` and
the other marker letters pick Spanish, Portuguese, German, ...). The device locale only picks the regional variant.

Verification (2026-10-30, driven from this session):

* **macOS (debug build, real UI and speech):** Settings → Voice language lists the languages `SFSpeechRecognizer` reports
  (Bulgarian etc. are hidden, Thai is not offered), the choice persists, and Voice mode follows spoken Portuguese (pt-BR),
  Spanish (es-ES) and English (en-US) played through the Mac speakers into the Mac microphone (the highlight reached the
  end of each script). `Automatic` with the Spanish script (it contains `ñ`) resolved to Spanish and followed the audio.
* **Android (Pixel 7 emulator, API 37):** the picker lists the languages the on-device service reports; with Spanish
  (Spain) chosen, Voice mode asked Google's service for the Spanish (España) pack (proof the tag reaches the recogniser)
  and, once downloaded, followed spoken Spanish to the end of the script.
* **iOS (iPhone 17e simulator):** a probe of the native channel returned 62 supported locales, from which 39 of our
  languages are shown (pt-BR, es-ES and en-US included, Thai hidden). Listening itself could not be run: the simulator
  can't be given Speech permission without taps (no Simulator UI in this Xcode, `simctl privacy` is refused) and it has no
  camera session for the audio feed. So spoken iOS recognition is **not** verified.

Accent matching, checked against the reference (2026-10-30): the reference's script matcher (`ju3.d`) lowercases and
keeps only `Character.isLetterOrDigit` characters, with **no accent stripping**, and its recogniser tokens are split the
same way, so it is accent-sensitive exactly like ours. The only accent stripping in the reference is `o15.d`, the
tokenizer for its *voice-command phrases* (NFC, then NFD with `\p{M}` removed for Latin-range letters, `ς` to `σ`),
which we don't have. So nothing changes here: a script typed without accents ("anuncio" for "anunció") fails to match
in both apps. (One deliberate difference: we keep combining marks inside a word so Hindi and Thai words aren't cut
at a vowel sign; the reference drops them from script words but still splits spoken text at them.)

iOS and macOS offline-model handling (2026-10-30), matching Android's `triggerModelDownload`:
* `SFSpeechRecognizer` has no download call. On iOS/macOS 26+ `AssetInventory.assetInstallationRequest(supporting: [DictationTranscriber])`
  + `downloadAndInstall()` does. Verified on macOS 26.6: installing the `fr-FR` model flipped `SFSpeechRecognizer(fr-FR).supportsOnDeviceRecognition`
  from false to true, so the same model serves the recogniser we use.
* Both Swift recognisers now call it (`requestModel(for:)`, guarded by `#available(iOS/macOS 26, *)`, once per language per run) when a
  listen starts for a language with no offline model, and after an on-device failure. Meanwhile the session uses Apple's servers
  (`supportsOnDeviceRecognition` is already false for such a language, and an on-device failure drops `requiresOnDeviceRecognition` for
  the rest of the listen). Verified in the app on macOS: choosing German and starting Voice mode made `de-DE` gain on-device support
  about 25 seconds later. Older systems have no such call and keep using the servers until the reader enables the language
  under Settings > Keyboard > Dictation.
* Side effect of testing: the French and German dictation models are now installed on this Mac.

Extra verification (2026-10-30), previously untested items, run with system voices played into the microphone:
* **macOS, `Automatic` language:** Chinese (zh-CN, per-character words, wraps correctly, highlight to 86%), Japanese (ja-JP, to 100%),
  Arabic (right-to-left layout, line wrap correct, to 100%) and Hebrew (right-to-left, to 100%) all followed the speech.
* **Android (Pixel 7 emulator):** Portuguese (Brazil) and English (US) followed the speech to the end of the script. For pt-BR the log
  showed the reference fallback: "on-device recognizer can't handle pt-BR (language model unavailable) -> falling back to system
  recognizer", then Google's offer to download the Portuguese pack. A first attempt with a different synthetic voice was mis-heard
  at the start ("escritorio de ...") and showed "Lost your place"; with a clearer voice it matched, so that was recogniser accuracy on
  synthetic speech, not the language plumbing.
* **Still for a real device:** spoken recognition on iPhone/iPad, and the Android 14+ pack download prompt on a physical phone.

Scope note (2026-10-30): the project now targets macOS, iOS, iPadOS and Android only; Windows is dropped. The Windows recogniser
(`packages/echoprompter_window/windows/speech_recognizer_channel.cpp`) still ignores the language argument and stays English-only; it
is not maintained, so nothing was changed there.
