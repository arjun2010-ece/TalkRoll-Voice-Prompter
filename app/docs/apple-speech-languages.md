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

## How it behaves

- **Narration** (iOS 26 and macOS 26 and later): the chosen or detected language's pack is downloaded the first time (the Narration card says "Downloading the … language pack (one time)…", and starts it as soon as the language is known, before a recording is chosen), then the recording is transcribed on the device and every word has a time.
- **Voice mode:** English, Spanish, French, Italian, Thai and Chinese use Apple's older recogniser on the device. **Portuguese always uses the newer engine** (the older engine's Portuguese model returned 22% of a test passage). Every other language uses the newer engine unless the older recogniser reports an on-device model for it at that moment. The pack is downloaded first, with progress shown as the status.
- **Reading language Automatic:** the language is detected from the script with Apple's language recogniser (`NLLanguageRecognizer`), then matched to the device's own regional variants (a `pt-PT` phone gets `pt-PT` for a Portuguese script). A fixed language in Settings overrides it. If the recording is in another language than the script, Narration says "It was read as …; if it is in another language, change the reading language."
- **Older systems (iOS 15 to 25, macOS 13 to 25):** none of the above applies. Narration and Voice use Apple's older recogniser, which works on the device only for the languages the system has downloaded under Settings > General > Keyboard > Dictation (seven languages by default). The store text should say the 33 languages need **iOS 26 / macOS 26 or later**.

## What this was not tested with

Real human speech (only text-to-speech voices), Android (it has its own recognisers and is not covered here), macOS at run time (the macOS code is the same Swift and compiles, but was not run), and iPad.
