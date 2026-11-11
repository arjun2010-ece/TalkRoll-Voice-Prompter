# Languages TalkRoll supports on Apple devices

For the App Review notes and the store description. Measured on an iPhone 15 Pro Max (iOS 26.6.2) on 2026-11-02 and 2026-11-03, with test passages spoken by macOS text-to-speech voices (not real speech yet).

## The 33 languages: two separate records

Apple's speech recognition covers **33 languages** on iOS 26 and macOS 26 and later. Narration and Voice mode are measured separately below, because they use different recognisers and a language can work in one and not the other. Both run on the device; a language's pack downloads from Apple once (see "Language packs" further down).

### Voice mode (whole script, voice only), measured 2026-11-03

Method: for each language a two-paragraph script (70 to 240 words or characters) was read aloud by a macOS text-to-speech voice from the Mac's speaker, and the iPhone's microphone listened through Voice mode with the reading language set to that language. The prompter's own tracker counted how many script words the highlight reached. The harness drove the app's real Voice controller (the same code as the Play button), downloading any missing pack first as if the reader had agreed. One run per language; none fell below the 70% bar that would have called for a rerun.

| Language | Tag tested | Words followed | Engine used in the test |
|---|---|---|---|
| Arabic | ar-SA | 77 of 77 (100%) | older recogniser |
| Catalan | ca-ES | 98 of 98 (100%) | older |
| Cantonese (Hong Kong) | yue-Hant-HK | 155 of 155 (100%) | newer |
| Chinese (Simplified) | zh-CN | 175 of 175 (100%) | older |
| Croatian | hr-HR | 84 of 84 (100%) | older |
| Czech | cs-CZ | 83 of 83 (100%) | older |
| Danish | da-DK | 101 of 101 (100%) | older |
| Dutch | nl-NL | 100 of 100 (100%) | older |
| English | en-US | 299 of 300 (earlier run, one paragraph pair of 300 words) | older |
| Finnish | fi-FI | 70 of 71 (99%) | older |
| French | fr-FR | 97 of 105 (92%) | older |
| German | de-DE | 102 of 102 (100%) | newer |
| Greek | el-GR | 96 of 96 (100%) | older |
| Hebrew | he-IL | 77 of 78 (99%) | older |
| Hindi | hi-IN | 118 of 118 (100%) | older |
| Hungarian | hu-HU | 80 of 80 (100%) | older |
| Indonesian | id-ID | 90 of 90 (100%) | older |
| Italian | it-IT | 96 of 96 (100%) | newer |
| Japanese | ja-JP | 240 of 240 characters (100%) | newer |
| Korean | ko-KR | 70 of 70 (100%) | newer |
| Malay | ms-MY | 89 of 91 (98%) | older |
| Norwegian Bokmål | nb-NO | 98 of 98 (100%) | older |
| Polish | pl-PL | 81 of 82 (99%) | older |
| Portuguese | pt-BR | 90 of 90 (100%) | newer |
| Romanian | ro-RO | 96 of 96 (100%) | older |
| Russian | ru-RU | 86 of 86 (100%) | older |
| Slovak | sk-SK | 82 of 83 (99%) | older |
| Spanish | es-ES | 101 of 101 (100%) | newer |
| Swedish | sv-SE | 98 of 98 (100%) | older |
| Thai | th-TH | 16 of 16 whitespace words (100%); Thai is followed by letters, so this is a weaker measure | older |
| Turkish | tr-TR | 74 of 74 (100%) | older |
| Ukrainian | uk-UA | 84 of 84 (100%) | older |
| Vietnamese | vi-VN | 136 of 136 (100%) | older |

Result: **all 33 languages followed in Voice mode on this phone, 92% to 100%, no failures.** Other tags of the same language (en-GB, pt-PT, es-MX, fr-CA, zh-TW and so on) were not run.

Read these with care:

- **"Older" and "newer" depended on what the phone already had.** Voice uses the older recogniser where it reports an on-device model for the language at that moment, and the newer engine otherwise (always for Portuguese). On this phone, many languages had an older on-device model only because their dictation pack had been installed earlier by Narration tests. On a phone where that pack was never installed, those languages would use the newer engine instead and would first ask to download its pack. That path was measured for Portuguese, Russian, German, Turkish, Vietnamese and Chinese earlier, not for each language again.
- **Synthetic speech, one phone, one run each.** A real voice, background noise, other iPhones and iOS versions are untested. Text-to-speech through a speaker is cleaner than most people, so real-world numbers may be lower.
- **English** was measured earlier (299 of 300 words in one run), not in this batch.

### Narration mode (a recorded file transcribed on the device, then played with the highlight), measured 2026-11-03

Method: for each language the same two-paragraph script as the Voice test was spoken by a macOS text-to-speech voice and saved as an audio file. The app transcribed the file on the phone (downloading any missing pack first), lined the transcript up with the script, and played the file through the real Narration controller; the prompter's own tracker counted how many script words the highlight reached. Narration engine: "Speech" is Apple's newer `SpeechTranscriber` (10 languages), "Dictation" is `DictationTranscriber` (the other 23); the app picks it. One run per language.

| Language | Code | Engine | How well the transcript matches the script | Playback highlight |
|---|---|---|---|---|
| Arabic | ar | Dictation | 95% of script words found in the transcript | highlight reached 77 of 77 (end of script) |
| Cantonese (Hong Kong) | yue | Speech | 95% of script words found in the transcript | highlight reached 155 of 155 (end of script) |
| Catalan | ca | Dictation | 94% of script words found in the transcript | highlight reached 98 of 98 (end of script) |
| Chinese | zh | Speech | 89% of script words found in the transcript | highlight reached 175 of 175 (end of script) |
| Croatian | hr | Dictation | 86% of script words found in the transcript | highlight reached 84 of 84 (end of script) |
| Czech | cs | Dictation | 98% of script words found in the transcript | highlight reached 83 of 83 (end of script) |
| Danish | da | Dictation | 91% of script words found in the transcript | highlight reached 101 of 101 (end of script) |
| Dutch | nl | Dictation | 98% of script words found in the transcript | highlight reached 100 of 100 (end of script) |
| English | en | Speech | 299 of 300 transcribed words earlier (3:59 file 787 of 790); not in the two-paragraph batch | not run in the batch |
| Finnish | fi | Dictation | 86% of script words found in the transcript | highlight reached 71 of 71 (end of script) |
| French | fr | Speech | 85% of script words found in the transcript | highlight reached 105 of 105 (end of script) |
| German | de | Speech | 99% of script words found in the transcript | highlight reached 102 of 102 (end of script) |
| Greek | el | Dictation | 92% of script words found in the transcript | highlight reached 96 of 96 (end of script) |
| Hebrew | he | Dictation | 96% of script words found in the transcript | highlight reached 78 of 78 (end of script) |
| Hindi | hi | Dictation | 84% of script words found in the transcript | highlight reached 118 of 118 (end of script) |
| Hungarian | hu | Dictation | 93% of script words found in the transcript | highlight reached 80 of 80 (end of script) |
| Indonesian | id | Dictation | 99% of script words found in the transcript | highlight reached 90 of 90 (end of script) |
| Italian | it | Speech | 100% of script words found in the transcript | highlight reached 96 of 96 (end of script) |
| Japanese | ja | Speech | 97% of script words found in the transcript | highlight reached 240 of 240 (end of script) |
| Korean | ko | Speech | 81% of script words found in the transcript | highlight reached 70 of 70 (end of script) |
| Malay | ms | Dictation | 93% of script words found in the transcript | highlight reached 91 of 91 (end of script) |
| Norwegian Bokmål | nb | Dictation | 100% of script words found in the transcript | highlight reached 98 of 98 (end of script) |
| Polish | pl | Dictation | 89% of script words found in the transcript | highlight reached 82 of 82 (end of script) |
| Portuguese | pt | Speech | 97% of script words found in the transcript | highlight reached 90 of 90 (end of script) |
| Romanian | ro | Dictation | 90% of script words found in the transcript | highlight reached 96 of 96 (end of script) |
| Russian | ru | Dictation | 98% of script words found in the transcript | highlight reached 86 of 86 (end of script) |
| Slovak | sk | Dictation | 92% of script words found in the transcript | highlight reached 83 of 83 (end of script) |
| Spanish | es | Speech | 97% of script words found in the transcript | highlight reached 101 of 101 (end of script) |
| Swedish | sv | Dictation | 93% of script words found in the transcript | highlight reached 98 of 98 (end of script) |
| Thai | th | Dictation | 100% of script words found in the transcript | highlight reached 16 of 16 (end of script) |
| Turkish | tr | Dictation | 97% of script words found in the transcript | highlight reached 74 of 74 (end of script) |
| Ukrainian | uk | Dictation | 99% of script words found in the transcript | highlight reached 84 of 84 (end of script) |
| Vietnamese | vi | Dictation | 96% of script words found in the transcript | highlight reached 136 of 136 (end of script) |

Result: **Narration plays and the highlight runs to the end of the script in all 32 languages measured**, with 81% to 100% of the script's words found in the transcript.

How to read the two numbers:

- **"Highlight reached the end" is the weaker one.** Narration scrolls by the audio's playing time, so when the audio plays through, the highlight reaches the end. It shows that transcription, alignment and playback work for the language. It does not show every word is lit at the right moment.
- **"% of script words found in the transcript" is the one that tells how exact the timing is.** Words the recogniser missed or misheard are placed by interpolation between the words around them, so a lower percentage means a looser fit. The lowest were Korean 81%, Hindi 84%, French 85%, Finnish 86% and Croatian 86%; the app warns "doesn't seem to match this script" only below 70%. I did not measure the timing error in seconds.
- Text-to-speech through a file is cleaner than a real recording; a real voice, music or room noise would lower the match.

Both records together: every one of the 33 languages works in both modes by these measurements (English in Narration from the earlier runs, the other 32 in the batch). Voice mode and Narration mode were each measured end to end for every language; both use text-to-speech audio, one phone, one run each.

## Not supported on Apple

The reading-language list the app shows on Android also has **Bulgarian (bg-BG)** and **Slovenian (sl-SI)**. Apple has neither, so the Apple picker does not offer them (it lists only what the device reports). A Bulgarian or Slovenian script set to Automatic is read as English.

## Language packs: what is downloaded, when, and what the reader is asked

Measured on the iPhone (iOS 26.6.2) on 2026-11-02.

- **Nothing is downloaded without the reader's agreement.** Narration shows, on its card, "Needs the Hindi language pack: a one-time download from Apple, then it works offline", with **Download** and **Not now**; Start stays off until it is done. Voice mode asks when Start is pressed ("Download the Russian language pack? ... It downloads once from Apple, so it needs an internet connection now, and then works without one", **Download** / **Not now**), shows a progress dialog while it runs, and says "Couldn't download it" with a way out if it fails. Choosing Voice from inside the reader never downloads: it says "Voice needs the Turkish language pack. Close the prompter and press Start to download it." Auto-scroll needs nothing and never asks.
- **Size:** Apple reports no size for these packs (the install request says 0 of 0, "indeterminate"), so the app cannot show one. A Finnish pack took 10 s over Wi-Fi, Danish 1 s, Spanish (Mexico) 1.5 s. The dialog says it needs a connection now and gives no number. Whether the system restricts these downloads on mobile data is not documented by Apple and was not tested (the phone was on Wi-Fi).
- **Guideline 4.2.3(ii)** (disclose the size and prompt before downloading resources the app needs *to function on initial launch*) does not apply: the app works on first launch with no download, English Voice uses the system recogniser, and the packs are system speech data installed by iOS through `AssetInventory`, not code (2.5.2). The consent step above is there anyway so a download is never a surprise.
- **Voice and Narration share packs, per engine.** Measured: installing a **dictation** pack (`DictationTranscriber`) also gives the older recogniser an on-device model for that language (Finnish: no model before the install, one after), and that model stays after the pack is released. A **speech** pack (`SpeechTranscriber`, e.g. Spanish (Mexico)) is separate: the older recogniser stays without a model. So: a dictation language is one download for both modes; a speech language is one download for Narration and for Voice wherever Voice uses the newer engine (Portuguese, German, Spanish and every language the older recogniser has no model for); for a language where the older recogniser has its own on-device model Voice needs no download, and Narration needs the pack for its engine.
- **Five languages at a time.** The system lets an app keep five language packs (`AssetInventory.maximumReservedLocales`). The app keeps each pack it uses reserved, and when a sixth is needed the one used least recently is let go; it then asks again before downloading. Measured: after adding Finnish, Russian, German and Hindi, the English and Chinese packs had been let go and Narration asked for them again. English Voice and the older-recogniser languages are not affected.
- **Narration with a recording already transcribed** uses the saved transcript and needs no pack.
- **Reading language Automatic:** the language is detected from the script with Apple's language recogniser (`NLLanguageRecognizer`), then matched to the device's own regional variants (a `pt-PT` phone gets `pt-PT` for a Portuguese script). A fixed language in Settings overrides it. If the recording is in another language than the script, Narration says "It was read as ...; if it is in another language, change the reading language."
- **Voice engine choice:** where the older recogniser reports an on-device model (on the test iPhone: English, French (France), Chinese (Simplified), Danish and Portuguese (Brazil, Portugal); a dictation download adds more, e.g. Finnish) Voice uses it, except Portuguese, which always uses the newer engine (the older one's Portuguese model returned 22% of a test passage and nothing after the first pause). Every other language uses the newer engine. The choice is made each time Voice starts.
- **Older systems (iOS 15 to 25, macOS 13 to 25):** none of the above applies. Narration and Voice use Apple's older recogniser, which works on the device only for the languages the system has downloaded under Settings > General > Keyboard > Dictation (seven languages by default). The store text should say the 33 languages need **iOS 26 / macOS 26 or later**.

### Suggested App Review note

"TalkRoll's Narration and Voice modes use Apple's on-device speech recognition (Speech framework, SpeechAnalyzer). For a language whose speech pack is not on the device yet, the app asks the user before downloading it from Apple through the system's AssetInventory API; the pack is system speech data, not app code, and the app works without it (Auto-scroll mode, and Voice mode in English). After the one-time download the language works offline. Speech is processed on the device where the device supports it, and the app never records or uploads it for its own use."

## What this was not tested with

Real human speech (only text-to-speech voices), Android (it has its own recognisers and is not covered here), macOS at run time (the macOS code is the same Swift and compiles, but was not run), and iPad.
