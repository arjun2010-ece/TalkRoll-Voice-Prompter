# Languages EchoPrompter supports on Apple devices

For the App Review notes and the store description. Measured on an iPhone 15 Pro Max (iOS 26.6.2) on 2026-11-02, with a test passage per language spoken by macOS text-to-speech voices (not real speech yet). Score = share of the script's letters found, in order, in what Apple's engine returned.

## The 33 languages

Apple's speech recognition covers **33 languages** on iOS 26 and macOS 26 and later (Narration, and Voice mode through the newer engines). Both of Apple's newer engines run on the device: the speech is not sent anywhere. The first use of a language downloads its language pack from Apple once (a few seconds to a minute); after that the language works offline.

| Language | Code | Engine | Narration score |
|---|---|---|---|
| Arabic | ar | Dictation | 98% |
| Catalan | ca | Dictation | 96% |
| Cantonese (Hong Kong) | yue | Speech | transcript turned into Traditional characters, matches the script |
| Chinese (Simplified, Traditional) | zh | Speech | 89% |
| Croatian | hr | Dictation | 91% |
| Czech | cs | Dictation | 100% |
| Danish | da | Dictation | 94% |
| Dutch | nl | Dictation | 100% |
| English (US, UK, AU, CA, IN, IE, NZ, SG, ZA) | en | Speech | 100% (300 of 300 words; 3:59 file 787 of 790) |
| Finnish | fi | Dictation | 93% |
| French (France, Canada, Belgium, Switzerland) | fr | Speech | 91% |
| German | de | Speech | 100% |
| Greek | el | Dictation | 97% |
| Hebrew | he | Dictation | 98% |
| Hindi | hi | Dictation | 93% |
| Hungarian | hu | Dictation | 99% |
| Indonesian | id | Dictation | 99% |
| Italian | it | Speech | 100% |
| Japanese | ja | Speech | 98% |
| Korean | ko | Speech | 96% |
| Malay | ms | Dictation | 99% |
| Norwegian Bokmål | nb | Dictation | 99% |
| Polish | pl | Dictation | 92% |
| Portuguese (Brazil, Portugal) | pt | Speech | 100% (Brazil tested) |
| Romanian | ro | Dictation | 96% |
| Russian | ru | Dictation | 99% |
| Slovak | sk | Dictation | 97% |
| Spanish (Spain, Mexico, US, Chile) | es | Speech | 98% |
| Swedish | sv | Dictation | 97% |
| Thai | th | Dictation | 96% |
| Turkish | tr | Dictation | 98% |
| Ukrainian | uk | Dictation | 100% |
| Vietnamese | vi | Dictation | 95% |

"Speech" is Apple's newer `SpeechTranscriber` (10 languages); "Dictation" is `DictationTranscriber` (the other 23). The app picks the engine itself.

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

"EchoPrompter's Narration and Voice modes use Apple's on-device speech recognition (Speech framework, SpeechAnalyzer). For a language whose speech pack is not on the device yet, the app asks the user before downloading it from Apple through the system's AssetInventory API; the pack is system speech data, not app code, and the app works without it (Auto-scroll mode, and Voice mode in English). After the one-time download the language works offline and no audio leaves the device."

## What this was not tested with

Real human speech (only text-to-speech voices), Android (it has its own recognisers and is not covered here), macOS at run time (the macOS code is the same Swift and compiles, but was not run), and iPad.
