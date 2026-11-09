# Localized App Store keyword research

Astro scores for the iPhone App Store, initially researched 2026-11-08 and followed by a search-result intent audit on 2026-11-09. Each locale uses the storefront named below as a proxy; one storefront does not represent every country using that language. Search results and estimates change over time.

Each section lists the measured seed terms and exploratory variants, ordered with matches to **popularity > 20 and difficulty < 60** first. All other rows are exploratory fallbacks; a popularity of 5 is a low-data signal, not proof of zero demand. Broad terms may have unrelated search intent. Scores are estimates, not a guarantee of rank or traffic.

Top apps are examples from the indicated search, not an endorsement or a suggestion to include competitor names in metadata. The research app also tracks tested terms in Astro. Validate natural wording with native speakers and check release features before using terms in a listing. Floating notes is relevant to iOS per product owner. Some exploratory terms, such as 字幕機, 悬浮字幕 and 滚动字幕, can imply generated captions or subtitles; text reader terms may suggest text-to-speech. Review intent before use and do not claim unsupported features. Storefront selection does not establish Apple metadata-localization availability.

## Search-result intent audit — 2026-11-09

All 38 locale sections below were checked one at a time using standalone keyword searches and category-qualified combinations. The complete per-locale evidence, scores for newly measured combinations, result positions and selection decisions are in [the locale intent audit](locale-intent-audit.md). The resulting metadata is in [the iOS listings](app-store-listings.md). The seed tables below remain historical research: a popularity/difficulty score is **not** approval to use a term in metadata, and a result showing teleprompter apps does not prove a specific word caused their rank. Most newly tested native combinations have popularity 5, so treat them as intent checks rather than meaningful demand estimates.

The audit changed how several seemingly attractive terms should be used:

| Locale(s) | Search-result finding | Metadata decision |
|---|---|---|
| ar-SA | `خطابة` scored 59/48 but returned marriage apps; `خطاب` did too. `video recorder` returned screen recorders. | Removed the two marriage-intent words; added Arabic script and floating-note terms. Kept `recorder` only as lower-priority context for a teleprompter recording combination. |
| ru | `бегущая строка` scored 43/15 but mostly returned LED banners. | Removed its components; used voice, camera and floating-note terms with prompter results. |
| pl, pt-BR, fr-FR | Text-reader phrases scored well but mostly returned text-to-speech or ebook apps. | Removed misleading reader components where applicable and prioritized prompter/script/camera combinations. |
| de-DE, es-ES, id, ms, ro, sv | Broad text, recorder, speech or presentation words led to unrelated apps in standalone searches. | Removed the weakest words and checked replacements in teleprompter combinations. |
| vi | `auto scroll` scored 24/11 but returned auto-clickers; native `chạy` led to running games and its category combination mixed in LED banners. | Kept `auto,scroll` only for the relevant `teleprompter auto scroll` combination; replaced running-text vocabulary with `kịch bản`. |
| tr, he | Turkish `bölüm` and `akış` yielded almost no prompters in category searches. Hebrew `קצב` yielded none; `חזרות` yielded one. | Replaced weak words with tested floating/automatic scrolling or native script/filming terms. |
| zh-Hans, zh-Hant | Import, font and practice words led to utilities, calligraphy, LED or study apps. | Used tested script-reading, creator-speech and recording/voice-pace terms instead. |
| sl-SI | Most native standalone and category-combination searches returned no prompter apps; English teleprompter combinations did. | Retained localized visible copy and native camera/floating-note coverage; used English terms in the keyword field as a documented exception. |
| ca, cs, da, el, fi, hi, hr, hu, it, ja, ko, nl-NL, no, pt-PT, sk, th, uk, en-GB, en-CA, en-AU, es-MX | Standalone feature words were often broad. The detailed audit distinguishes supported category combinations from weak or unrelated searches. | Retained or revised each listing according to its storefront results; see the per-locale evidence before reusing a seed term. |

For iOS, floating notes describes the app's in-app presentation. Search results for `floating notes` and native equivalents vary by storefront; none establish a system-wide overlay feature. Avoid using the scored `autocue` term as metadata because [Autocue is an existing brand](https://www.autocue.com/).

## Catalan (ca) — ES storefront

Competitors for “teleapuntador”: 1. InOne: Teleprónter IA (ID 6785108120); 2. PaceCue: Teleprompter Vídeo (ID 6797831584); 3. Prompter: Teleapuntador (ID 6821574222).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 59 | 46 |
| prompter | 42 | 41 |
| vídeo | 14 | 73 |
| auto scroll | 9 | 9 |
| floating notes | 8 | 39 |
| video teleprompter | 6 | 42 |
| desplaçament automàtic | 5 | 5 |
| notes flotants | 5 | 5 |
| teleapuntador | 5 | 5 |
| lector de guions | 5 | 7 |
| text flotant | 5 | 7 |
| guió | 5 | 13 |
| voice prompter | 5 | 15 |
| script reader | 5 | 21 |
| apuntador | 5 | 33 |
| discurs | 5 | 56 |

## Czech (cs) — CZ storefront

Competitors for “čtecí zařízení”: 1. Ivudi Video Teleprompter (ID 6822838105); 2. CueFlow - Teleprompter (ID 6764818837); 3. Whisprompt: Teleprompter (ID 6784841630).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| video | 50 | 55 |
| teleprompter | 45 | 9 |
| auto scroll | 5 | 5 |
| automatické posouvání | 5 | 5 |
| plovoucí poznámky | 5 | 5 |
| čtecí zařízení | 5 | 5 |
| čtecí zařízení pro video | 5 | 5 |
| prompter | 5 | 9 |
| floating notes | 5 | 11 |
| hlas | 5 | 11 |
| voice prompter | 5 | 11 |
| čtení textu | 5 | 13 |
| script reader | 5 | 15 |
| čtečka textu | 5 | 15 |
| video teleprompter | 5 | 17 |
| scénář | 5 | 23 |

## Danish (da) — DK storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| video | 43 | 58 |
| teleprompter | 37 | 11 |
| auto scroll | 5 | 5 |
| automatisk rulning | 5 | 5 |
| flydende noter | 5 | 5 |
| manuskript | 5 | 5 |
| manuskript læser | 5 | 5 |
| stemmestyring | 5 | 5 |
| tekstlæser | 5 | 5 |
| script reader | 5 | 9 |
| autocue | 5 | 11 |
| prompter | 5 | 11 |
| floating notes | 5 | 13 |
| video teleprompter | 5 | 15 |
| voice prompter | 5 | 15 |
| tale | 5 | 54 |

## German (de-DE) — DE storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter für Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 53 | 45 |
| rede | 39 | 56 |
| prompter | 32 | 42 |
| sprechen | 28 | 47 |
| auto scroll | 23 | 19 |
| autocue | 17 | 35 |
| video aufnehmen | 16 | 52 |
| video teleprompter | 9 | 43 |
| texte vorlesen | 8 | 36 |
| schwebende notizen | 5 | 5 |
| sprachsteuerung | 5 | 5 |
| teleprompter deutsch | 5 | 5 |
| skript lesen | 5 | 7 |
| souffleur | 5 | 7 |
| text scroller | 5 | 9 |
| automatisch scrollen | 5 | 17 |
| script reader | 5 | 19 |
| voice prompter | 5 | 19 |
| teleprompter für video | 5 | 23 |
| floating notes | 5 | 44 |
| text ablesen | 5 | 57 |

## Greek (el) — GR storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 40 | 7 |
| auto scroll | 5 | 5 |
| αυτόματη κύλιση | 5 | 5 |
| κειμενογράφος | 5 | 5 |
| σενάριο | 5 | 5 |
| τηλεβολέας | 5 | 5 |
| υποβολέας | 5 | 5 |
| prompter | 5 | 7 |
| script reader | 5 | 7 |
| ανάγνωση κειμένου | 5 | 7 |
| φωνή | 5 | 7 |
| video teleprompter | 5 | 11 |
| voice prompter | 5 | 11 |
| floating notes | 5 | 15 |
| σημειώσεις | 5 | 19 |
| βίντεο | 5 | 36 |

## Spanish (Spain) (es-ES) — ES storefront

Competitors for “teleprompter”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprónter (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 59 | 46 |
| prompter | 42 | 41 |
| grabar video | 23 | 57 |
| notas flotantes | 11 | 55 |
| auto scroll | 9 | 9 |
| floating notes | 8 | 39 |
| teleprónter | 6 | 39 |
| video teleprompter | 6 | 42 |
| desplazamiento automático | 5 | 5 |
| teleprompter español | 5 | 5 |
| texto desplazable | 5 | 7 |
| texto flotante | 5 | 7 |
| lector de guiones | 5 | 9 |
| leer guion | 5 | 13 |
| discurso | 5 | 15 |
| voice prompter | 5 | 15 |
| teleprompter vídeo | 5 | 19 |
| guion vídeo | 5 | 21 |
| script reader | 5 | 21 |
| apuntador | 5 | 33 |
| teleprompter para video | 5 | 47 |
| control por voz | 5 | 53 |

## Finnish (fi) — FI storefront

Competitors for “teleprompteri”: 1. OnClip: Teleprompter for Video (ID 6636538421); 2. Teleprompter App Record Videos (ID 1507263544); 3. Cuebox Teleprompter & Captions (ID 6446940217).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 42 | 7 |
| video | 41 | 55 |
| prompter | 28 | 7 |
| auto scroll | 5 | 5 |
| automaattinen vieritys | 5 | 5 |
| kelluvat muistiinpanot | 5 | 5 |
| kuiskaaja | 5 | 5 |
| teleprompteri | 5 | 5 |
| ääniohjaus | 5 | 5 |
| script reader | 5 | 7 |
| voice prompter | 5 | 7 |
| käsikirjoitus | 5 | 9 |
| puhe | 5 | 9 |
| tekstinlukija | 5 | 9 |
| floating notes | 5 | 11 |
| video teleprompter | 5 | 11 |

## French (fr-FR) — FR storefront

Competitors for “téléprompteur”: 1. Téléprompteur (ID 1420515755); 2. Teleprompter (ID 941620509); 3. Téléprompteur: flottants (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| prompteur | 48 | 23 |
| lecteur de texte | 32 | 41 |
| teleprompteur | 31 | 34 |
| auto scroll | 27 | 15 |
| discours | 26 | 51 |
| video teleprompter | 23 | 21 |
| prompter | 7 | 23 |
| téléprompteur | 6 | 37 |
| défilement automatique | 5 | 7 |
| notes flottantes | 5 | 7 |
| texte défilant | 5 | 9 |
| floating notes | 5 | 13 |
| voice prompter | 5 | 15 |
| script reader | 5 | 17 |
| téléprompteur vidéo | 5 | 17 |
| prompteur vidéo | 5 | 23 |
| script vidéo | 5 | 45 |
| lire un texte | 5 | 46 |
| commande vocale | 5 | 48 |
| enregistrer vidéo | 5 | 55 |

## Hindi (hi) — IN storefront

Competitors for “टेलीप्रॉम्प्टर”: 1. Teleprompter-Floating Dialogue (ID 6743192345); 2. Teleprompter.com (ID 1420515755); 3. Edits: Video Editor (ID 6738967378).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 57 | 42 |
| voice prompter | 26 | 9 |
| prompter | 25 | 19 |
| script reader | 21 | 19 |
| आवाज से नियंत्रण | 5 | 5 |
| पाठ पढ़ें | 5 | 5 |
| फ्लोटिंग नोट्स | 5 | 5 |
| स्क्रिप्ट रीडर | 5 | 5 |
| स्वचालित स्क्रॉल | 5 | 5 |
| auto scroll | 5 | 9 |
| वीडियो रिकॉर्डिंग | 5 | 9 |
| स्क्रिप्ट | 5 | 9 |
| भाषण | 5 | 11 |
| floating notes | 5 | 13 |
| video teleprompter | 5 | 15 |
| टेलीप्रॉम्पटर | 5 | 17 |
| टेलीप्रॉम्प्टर | 5 | 17 |

## Croatian (hr) — HR storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 37 | 5 |
| auto scroll | 5 | 5 |
| automatsko pomicanje | 5 | 5 |
| bubica | 5 | 5 |
| glasovno upravljanje | 5 | 5 |
| govor | 5 | 5 |
| plutajuće bilješke | 5 | 5 |
| prompter | 5 | 5 |
| script reader | 5 | 5 |
| voice prompter | 5 | 5 |
| video snimanje | 5 | 7 |
| čitanje teksta | 5 | 7 |
| čitač teksta | 5 | 7 |
| video teleprompter | 5 | 9 |
| floating notes | 5 | 11 |
| scenarij | 5 | 13 |

## Hungarian (hu) — HU storefront

Competitors for “súgógép”: 1. Autocue Teleprompter Recorder (ID 6774933456); 2. Teleprompter Automatic (ID 1607873167); 3. Teleprompter: Captions & Video (ID 6463623914).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 40 | 9 |
| prompter | 23 | 9 |
| auto scroll | 5 | 5 |
| automatikus görgetés | 5 | 5 |
| forgatókönyv | 5 | 5 |
| lebegő jegyzetek | 5 | 5 |
| szövegolvasó | 5 | 5 |
| videófelvétel | 5 | 5 |
| hangvezérlés | 5 | 7 |
| szövegfelolvasó | 5 | 7 |
| voice prompter | 5 | 7 |
| súgógép | 5 | 9 |
| beszéd | 5 | 13 |
| floating notes | 5 | 13 |
| video teleprompter | 5 | 13 |
| script reader | 5 | 15 |

## Indonesian (id) — ID storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter.com (ID 1420515755); 3. Teleprompter: Floating Notes (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 68 | 42 |
| prompter | 54 | 42 |
| teks berjalan | 45 | 21 |
| auto scroll | 30 | 9 |
| teleprompter video | 26 | 23 |
| perekam video | 24 | 42 |
| catatan mengambang | 5 | 5 |
| baca naskah | 5 | 7 |
| gulir otomatis | 5 | 7 |
| kontrol suara | 5 | 7 |
| naskah video | 5 | 7 |
| pidato | 5 | 13 |
| floating notes | 5 | 15 |
| pembaca teks | 5 | 15 |
| voice prompter | 5 | 15 |
| teks berjalan video | 5 | 19 |
| script reader | 5 | 38 |
| video teleprompter | 5 | 39 |
| rekam video | 5 | 41 |

## Italian (it) — IT storefront

Competitors for “teleprompter”: 1. Teleprompter per Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 55 | 41 |
| prompter | 29 | 21 |
| gobbo | 27 | 21 |
| discorso | 24 | 23 |
| auto scroll | 9 | 5 |
| video teleprompter | 9 | 38 |
| lettore testo | 9 | 41 |
| testo scorrevole | 7 | 21 |
| gobbo elettronico | 5 | 7 |
| leggere copione | 5 | 7 |
| scorrimento automatico | 5 | 7 |
| suggeritore | 5 | 11 |
| voice prompter | 5 | 13 |
| script reader | 5 | 19 |
| teleprompter video | 5 | 23 |
| floating notes | 5 | 41 |
| note mobili | 5 | 43 |
| registrare video | 5 | 44 |
| controllo vocale | 5 | 49 |

## Japanese (ja) — JP storefront

Competitors for “プロンプター”: 1. テレプロンプター (ID 1420515755); 2. 日本語プロンプター (ID 6766185725); 3. Teleprompter: フローティングスクリプト (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| 動画撮影 | 43 | 48 |
| カンペ | 40 | 23 |
| プロンプター | 38 | 13 |
| 台本 | 34 | 42 |
| 自動スクロール | 33 | 11 |
| 音声認識 | 32 | 38 |
| テレプロンプター | 28 | 15 |
| スピーチ | 27 | 19 |
| auto scroll | 9 | 13 |
| video teleprompter | 9 | 15 |
| prompter | 7 | 13 |
| 原稿読み上げ | 5 | 5 |
| 浮かぶメモ | 5 | 5 |
| floating notes | 5 | 7 |
| 台本読み | 5 | 7 |
| カンペ カメラ | 5 | 9 |
| カンペ 動画 | 5 | 9 |
| カンペアプリ | 5 | 9 |
| プロンプター 動画 | 5 | 9 |
| 台本 動画 | 5 | 9 |
| script reader | 5 | 13 |
| voice prompter | 5 | 15 |

## Korean (ko) — KR storefront

Competitors for “텔레프롬프터”: 1. Teleprompter (ID 941620509); 2. Teleprompter.com (ID 1420515755); 3. 텔레프롬프터 - 대본 촬영 (ID 6795164330).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| 프롬프트 | 56 | 42 |
| 프롬프터 | 39 | 11 |
| 스크립트 | 37 | 49 |
| 텔레프롬프터 | 36 | 9 |
| 자막 | 36 | 38 |
| 자동 스크롤 | 35 | 13 |
| 동영상 촬영 | 33 | 45 |
| 대본 | 32 | 7 |
| 발표 | 26 | 23 |
| 영상 대본 | 5 | 5 |
| 대본 읽기 | 5 | 7 |
| 대본 카메라 | 5 | 7 |
| auto scroll | 5 | 9 |
| 플로팅 메모 | 5 | 9 |
| prompter | 5 | 11 |
| voice prompter | 5 | 13 |
| video teleprompter | 5 | 15 |
| floating notes | 5 | 17 |
| 프롬프터 카메라 | 5 | 17 |
| script reader | 5 | 19 |
| 음성 인식 | 5 | 36 |

## Malay (ms) — MY storefront

Competitors for “teleprompter”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Video Teleprompter Lite (ID 1031079244).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 69 | 23 |
| prompter | 51 | 21 |
| script reader | 44 | 21 |
| auto scroll | 31 | 7 |
| baca skrip | 5 | 5 |
| nota terapung | 5 | 5 |
| tatal automatik | 5 | 5 |
| pembaca teks | 5 | 7 |
| floating notes | 5 | 9 |
| kawalan suara | 5 | 9 |
| ucapan | 5 | 9 |
| voice prompter | 5 | 17 |
| skrip video | 5 | 38 |
| video teleprompter | 5 | 38 |
| rakam video | 5 | 39 |

## Dutch (nl-NL) — NL storefront

Competitors for “teleprompter”: 1. Teleprompter voor Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 52 | 17 |
| presentatie | 49 | 50 |
| autocue | 37 | 15 |
| prompter | 26 | 15 |
| spraakbesturing | 5 | 5 |
| tekstlezer | 5 | 5 |
| zwevende notities | 5 | 5 |
| auto scroll | 5 | 7 |
| script lezen | 5 | 7 |
| automatisch scrollen | 5 | 9 |
| voice prompter | 5 | 11 |
| script reader | 5 | 13 |
| floating notes | 5 | 17 |
| spreektekst | 5 | 19 |
| video teleprompter | 5 | 21 |
| video opnemen | 5 | 57 |

## Norwegian (no) — NO storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 42 | 9 |
| manus | 30 | 44 |
| automatisk rulling | 5 | 5 |
| flytende notater | 5 | 5 |
| lese manus | 5 | 5 |
| stemmekontroll | 5 | 5 |
| tekstleser | 5 | 5 |
| video teleprompter | 5 | 7 |
| videoopptak | 5 | 7 |
| autocue | 5 | 9 |
| prompter | 5 | 15 |
| voice prompter | 5 | 15 |
| auto scroll | 5 | 21 |
| script reader | 5 | 21 |
| floating notes | 5 | 38 |
| tale | 5 | 41 |

## Polish (pl) — PL storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter: Floating Notes (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 53 | 15 |
| prompter | 43 | 15 |
| czytnik tekstu | 29 | 17 |
| voice prompter | 27 | 11 |
| automatyczne przewijanie | 5 | 5 |
| przemówienie | 5 | 5 |
| pływające notatki | 5 | 5 |
| sterowanie głosem | 5 | 5 |
| scenariusz | 5 | 9 |
| sufler | 5 | 9 |
| auto scroll | 5 | 11 |
| czytanie tekstu | 5 | 11 |
| floating notes | 5 | 13 |
| script reader | 5 | 13 |
| nagrywanie wideo | 5 | 17 |
| video teleprompter | 5 | 19 |

## Portuguese (Brazil) (pt-BR) — BR storefront

Competitors for “teleprompter”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 68 | 56 |
| leitor de texto | 41 | 43 |
| gravar vídeo | 28 | 48 |
| notas flutuantes | 25 | 21 |
| auto scroll | 21 | 13 |
| voice prompter | 21 | 15 |
| video teleprompter | 9 | 42 |
| teleprompter para vídeo | 8 | 44 |
| prompter | 6 | 47 |
| teleprompter português | 5 | 5 |
| texto flutuante | 5 | 9 |
| rolagem automática | 5 | 13 |
| discurso | 5 | 15 |
| leitor de roteiro | 5 | 15 |
| ler roteiro | 5 | 15 |
| controle por voz | 5 | 17 |
| floating notes | 5 | 21 |
| script reader | 5 | 23 |
| teleprompter vídeo | 5 | 41 |
| texto para vídeo | 5 | 45 |
| texto rolando | 5 | 46 |

## Portuguese (Portugal) (pt-PT) — PT storefront

Competitors for “teleponto”: 1. Teleponto (ID 1420515755); 2. Teleprompter (ID 941620509); 3. Teleprompter para Vídeo (ID 1139307843).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 53 | 17 |
| teleponto | 42 | 19 |
| prompter | 26 | 17 |
| auto scroll | 5 | 5 |
| deslocamento automático | 5 | 5 |
| guião | 5 | 5 |
| guião vídeo | 5 | 5 |
| ler guião | 5 | 5 |
| floating notes | 5 | 11 |
| teleponto vídeo | 5 | 11 |
| discurso | 5 | 13 |
| script reader | 5 | 13 |
| leitor de texto | 5 | 17 |
| voice prompter | 5 | 19 |
| gravar vídeo | 5 | 23 |
| video teleprompter | 5 | 23 |
| texto a rolar | 5 | 30 |
| notas flutuantes | 5 | 44 |
| controlo por voz | 5 | 48 |

## Romanian (ro) — RO storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter.com (ID 1420515755); 3. Teleprompter for Video (ID 1139307843).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 45 | 13 |
| prompter | 36 | 13 |
| auto scroll | 5 | 5 |
| derulare automată | 5 | 5 |
| notițe plutitoare | 5 | 5 |
| sufleor | 5 | 9 |
| voice prompter | 5 | 9 |
| floating notes | 5 | 11 |
| script reader | 5 | 11 |
| înregistrare video | 5 | 11 |
| cititor de text | 5 | 13 |
| scenariu | 5 | 13 |
| citește text | 5 | 15 |
| video teleprompter | 5 | 17 |
| control vocal | 5 | 23 |
| discurs | 5 | 53 |

## Russian (ru) — RU storefront

Competitors for “телесуфлер”: 1. Телесуфлёр: Плавающие сценарии (ID 1559566851); 2. Телесуфлер - суфлер для видео (ID 1607873167); 3. Teleprompter app (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| суфлер | 53 | 21 |
| бегущая строка | 43 | 15 |
| текст на экране | 37 | 17 |
| запись видео | 27 | 48 |
| телесуфлер | 24 | 35 |
| auto scroll | 5 | 11 |
| телесуфлер для видео | 5 | 11 |
| script reader | 5 | 13 |
| автопрокрутка | 5 | 13 |
| чтение текста | 5 | 13 |
| плавающие заметки | 5 | 15 |
| prompter | 5 | 17 |
| voice prompter | 5 | 17 |
| video teleprompter | 5 | 21 |
| суфлёр | 5 | 23 |
| телепромптер | 5 | 23 |
| телесуфлёр | 5 | 23 |
| текст для видео | 5 | 44 |
| floating notes | 5 | 53 |
| голосовое управление | 5 | 53 |

## Slovak (sk) — SK storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter.com (ID 1420515755); 3. Teleprompter for Video (ID 1139307843).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 36 | 7 |
| auto scroll | 5 | 5 |
| automatické posúvanie | 5 | 5 |
| hlasové ovládanie | 5 | 5 |
| našepkávač | 5 | 5 |
| plávajúce poznámky | 5 | 5 |
| prejav | 5 | 5 |
| prompter | 5 | 5 |
| script reader | 5 | 5 |
| voice prompter | 5 | 5 |
| nahrávanie videa | 5 | 7 |
| čítačka textu | 5 | 7 |
| video teleprompter | 5 | 9 |
| floating notes | 5 | 11 |
| scenár | 5 | 15 |
| čítanie textu | 5 | 15 |

## Swedish (sv) — SE storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 48 | 11 |
| manus | 29 | 50 |
| prompter | 26 | 11 |
| automatisk rullning | 5 | 5 |
| flytande anteckningar | 5 | 5 |
| läsa manus | 5 | 5 |
| röststyrning | 5 | 5 |
| auto scroll | 5 | 7 |
| script reader | 5 | 9 |
| voice prompter | 5 | 9 |
| autocue | 5 | 11 |
| textläsare | 5 | 11 |
| floating notes | 5 | 15 |
| video teleprompter | 5 | 15 |
| tal | 5 | 48 |
| spela in video | 5 | 60 |

## Thai (th) — TH storefront

Competitors for “เทเลพรอมป์เตอร์”: 1. Teleprompter for Creators (ID 6477770039); 2. Daily Studio: AI Teleprompter (ID 6742501764); 3. Video Teleprompter Pro (ID 1104659250).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 69 | 21 |
| prompter | 33 | 17 |
| อ่านสคริปต์ | 30 | 5 |
| บันทึกวิดีโอ | 27 | 36 |
| ควบคุมด้วยเสียง | 5 | 5 |
| อ่านบท | 5 | 5 |
| อ่านบทพูด | 5 | 5 |
| เครื่องอ่านสคริปต์ | 5 | 5 |
| เทเลพรอมป์เตอร์ | 5 | 5 |
| เทเลพรอมเตอร์ | 5 | 5 |
| เลื่อนข้อความอัตโนมัติ | 5 | 5 |
| สคริปต์วิดีโอ | 5 | 7 |
| อ่านข้อความ | 5 | 9 |
| โน้ตลอย | 5 | 10 |
| auto scroll | 5 | 13 |
| script reader | 5 | 13 |
| video teleprompter | 5 | 13 |
| floating notes | 5 | 17 |
| voice prompter | 5 | 21 |

## Turkish (tr) — TR storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter.com (ID 1420515755); 3. Teleprompter for Video (ID 1139307843).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 52 | 23 |
| prompter | 46 | 21 |
| metin okuyucu | 34 | 13 |
| konuşma | 29 | 52 |
| sesli kontrol | 5 | 5 |
| auto scroll | 5 | 7 |
| video metni | 5 | 7 |
| otomatik kaydırma | 5 | 9 |
| suflör | 5 | 9 |
| floating notes | 5 | 11 |
| video teleprompter | 5 | 11 |
| metin okuma | 5 | 13 |
| voice prompter | 5 | 13 |
| yüzen notlar | 5 | 18 |
| script reader | 5 | 23 |
| video kaydı | 5 | 47 |

## Ukrainian (uk) — UA storefront

Competitors for “телесуфлер”: 1. Teleprompter: Floating Notes (ID 1559566851); 2. Teleprompter.com (ID 1420515755); 3. Teleprompter Automatic (ID 1607873167).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| телесуфлер | 58 | 31 |
| суфлер | 58 | 32 |
| промова | 50 | 36 |
| читання тексту | 26 | 9 |
| голосове керування | 5 | 5 |
| плаваючі нотатки | 5 | 5 |
| телесуфльор | 5 | 5 |
| автопрокрутка | 5 | 7 |
| video teleprompter | 5 | 9 |
| сценарій | 5 | 11 |
| script reader | 5 | 13 |
| voice prompter | 5 | 17 |
| auto scroll | 5 | 19 |
| телепромптер | 5 | 19 |
| prompter | 5 | 21 |
| запис відео | 5 | 23 |
| floating notes | 5 | 52 |

## Vietnamese (vi) — VN storefront

Competitors for “teleprompter”: 1. Teleprompter: Floating Notes (ID 1559566851); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter (ID 941620509).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 62 | 42 |
| máy nhắc chữ | 41 | 21 |
| chạy chữ | 40 | 40 |
| quay video | 40 | 56 |
| nhắc chữ | 34 | 30 |
| video teleprompter | 31 | 39 |
| prompter | 27 | 21 |
| auto scroll | 24 | 11 |
| điều khiển giọng nói | 5 | 7 |
| nhắc chữ quay video | 5 | 9 |
| đọc kịch bản | 5 | 9 |
| cuộn tự động | 5 | 11 |
| floating notes | 5 | 13 |
| bài phát biểu | 5 | 17 |
| script reader | 5 | 17 |
| đọc chữ khi quay video | 5 | 17 |
| ghi chú nổi | 5 | 21 |
| voice prompter | 5 | 21 |
| kịch bản video | 5 | 63 |

## Simplified Chinese (zh-Hans) — CN storefront

Competitors for “提词器”: 1. 灵敢提词器-提词拍摄 口播演讲直播 字幕提示软件 (ID 1513916989); 2. 开拍 - 让口播视频自带网感 (ID 6446305602); 3. 说得AI-提词器相机·数字人口播·智能脚本·视频剪辑全能神器 (ID 1569376400).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| 提词器 | 65 | 55 |
| 口播 | 47 | 50 |
| 提词 | 46 | 49 |
| 悬浮提词器 | 45 | 51 |
| 悬浮字幕 | 44 | 39 |
| 滚动字幕 | 42 | 19 |
| 口播提词器 | 37 | 40 |
| 演讲稿 | 26 | 46 |
| 台词 | 24 | 42 |
| 视频提词器 | 23 | 21 |
| 悬浮提词 | 21 | 55 |
| 录视频 | 31 | 71 |
| video teleprompter | 9 | 19 |
| prompter | 7 | 11 |
| voice prompter | 5 | 9 |
| auto scroll | 5 | 11 |
| 滚动提词 | 5 | 11 |
| 语音提词 | 5 | 15 |
| 语音跟读 | 5 | 15 |
| 智能提词 | 5 | 19 |
| script reader | 5 | 21 |
| 台词提词器 | 5 | 23 |
| 提词器悬浮窗 | 5 | 23 |
| 视频提词 | 5 | 36 |
| floating notes | 5 | 38 |
| 自动滚动 | 5 | 43 |

## Traditional Chinese (zh-Hant) — TW storefront

Competitors for “提詞器”: 1. 提詞器 (ID 1420515755); 2. 提词器-直播助手口播短视频拍摄软件 (ID 1513916989); 3. 開拍 - 讓口播影片自帶網感 (ID 6446305602).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| 錄影 | 53 | 49 |
| 提詞器 | 47 | 19 |
| 字幕機 | 28 | 23 |
| 讀稿機 | 27 | 21 |
| auto scroll | 5 | 5 |
| 懸浮筆記 | 5 | 5 |
| 懸浮提詞 | 5 | 7 |
| 浮動提詞 | 5 | 7 |
| video teleprompter | 5 | 9 |
| prompter | 5 | 11 |
| 語音提詞 | 5 | 11 |
| script reader | 5 | 13 |
| voice prompter | 5 | 13 |
| 影片提詞 | 5 | 13 |
| 演講稿 | 5 | 13 |
| 滾動字幕 | 5 | 15 |
| 自動捲動 | 5 | 15 |
| 讀稿 | 5 | 15 |
| floating notes | 5 | 17 |
| 提詞器拍影片 | 5 | 17 |
| 影片讀稿 | 5 | 19 |
| 提字機 | 5 | 19 |
| 提詞 | 5 | 21 |
| 提詞機 | 5 | 23 |

## Arabic (Saudi Arabia) (ar-SA) — SA storefront

Competitors for “تلقين”: 1. Talqeen - تلقين (ID 6804219399); 2. تلقين - tlqeen (ID 6748644310); 3. Teleprompter: Prompterly (ID 6762012994).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 40 | 11 |
| تصوير فيديو | 32 | 46 |
| تلقين | 23 | 23 |
| قارئ النصوص | 21 | 5 |
| النصوص العائمة | 5 | 5 |
| ملاحظات عائمة | 5 | 5 |
| voice prompter | 5 | 7 |
| التمرير التلقائي | 5 | 7 |
| قراءة النصوص | 5 | 7 |
| ملقن | 5 | 7 |
| auto scroll | 5 | 9 |
| video teleprompter | 5 | 9 |
| النص المتحرك | 5 | 9 |
| تلقين الكلمات | 5 | 9 |
| prompter | 5 | 11 |
| floating notes | 5 | 15 |
| تلقين نصوص | 5 | 17 |
| script reader | 5 | 19 |
| التحكم الصوتي | 5 | 21 |
| جهاز تلقين | 5 | 22 |
| تلقين الفيديو | 5 | 67 |

## Hebrew (he) — IL storefront

Competitors for “טלפרומפטר”: 1. Teleprompter.com (ID 1420515755); 2. BIGVU Teleprompter Captions AI (ID 1124958568); 3. Teleprompter for Video (ID 1139307843).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 53 | 17 |
| טלפרומפטר | 35 | 17 |
| prompter | 30 | 17 |
| auto scroll | 5 | 5 |
| גלילה אוטומטית | 5 | 5 |
| מקריא טקסט | 5 | 5 |
| נאום | 5 | 5 |
| פתקים צפים | 5 | 5 |
| קריאת טקסט | 5 | 5 |
| שליטה קולית | 5 | 5 |
| תסריט | 5 | 5 |
| טקסט רץ | 5 | 8 |
| video teleprompter | 5 | 11 |
| הקלטת וידאו | 5 | 11 |
| floating notes | 5 | 15 |
| voice prompter | 5 | 15 |
| טלפרומפטר וידאו | 5 | 15 |
| script reader | 5 | 17 |
| טלפרומטר | 5 | 17 |

## Slovenian (sl-SI) — SI storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 33 | 5 |
| auto scroll | 5 | 5 |
| bralnik besedila | 5 | 5 |
| branje besedila | 5 | 5 |
| glasovno upravljanje | 5 | 5 |
| plavajoči zapiski | 5 | 5 |
| prompter | 5 | 5 |
| samodejno drsenje | 5 | 5 |
| script reader | 5 | 5 |
| snemanje videa | 5 | 5 |
| trotlboben | 5 | 5 |
| voice prompter | 5 | 5 |
| floating notes | 5 | 9 |
| govor | 5 | 11 |
| scenarij | 5 | 11 |
| video teleprompter | 5 | 11 |

## English (UK) (en-GB) — GB storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 56 | 45 |
| autocue | 36 | 19 |
| script rehearser | 33 | 7 |
| voice prompter | 31 | 5 |
| auto scroll | 28 | 5 |
| prompter | 28 | 23 |
| public speaking | 23 | 21 |
| video teleprompter | 22 | 19 |
| script reader | 22 | 21 |
| floating notes | 9 | 13 |
| voice teleprompter | 5 | 13 |
| speech notes | 5 | 17 |

## English (Canada) (en-CA) — CA storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 57 | 44 |
| prompter | 32 | 21 |
| voice prompter | 27 | 7 |
| script reader | 27 | 17 |
| auto scroll | 24 | 11 |
| script rehearser | 23 | 11 |
| autocue | 15 | 17 |
| floating notes | 9 | 15 |
| video teleprompter | 6 | 19 |
| public speaking | 6 | 38 |
| voice teleprompter | 5 | 7 |
| speech notes | 5 | 21 |

## English (Australia) (en-AU) — AU storefront

Competitors for “teleprompter”: 1. Teleprompter (ID 941620509); 2. Teleprompter for Video (ID 1139307843); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 58 | 41 |
| voice prompter | 27 | 7 |
| auto scroll | 25 | 7 |
| script rehearser | 24 | 7 |
| script reader | 24 | 13 |
| autocue | 24 | 15 |
| prompter | 24 | 17 |
| video teleprompter | 9 | 17 |
| floating notes | 6 | 13 |
| public speaking | 6 | 21 |
| voice teleprompter | 5 | 9 |
| speech notes | 5 | 39 |

## Spanish (Mexico) (es-MX) — MX storefront

Competitors for “teleprompter”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprompter: Floating Notes (ID 1559566851); 3. Teleprompter (ID 941620509).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| teleprompter | 63 | 45 |
| prompter | 47 | 37 |
| grabar video | 37 | 47 |
| notas flotantes | 26 | 13 |
| teleprompter para video | 22 | 38 |
| apuntador | 5 | 5 |
| desplazamiento automático | 5 | 5 |
| lector de guiones | 5 | 5 |
| texto flotante | 5 | 5 |
| auto scroll | 5 | 7 |
| voice prompter | 5 | 11 |
| guion para video | 5 | 13 |
| leer guion | 5 | 13 |
| discurso | 5 | 15 |
| guion video | 5 | 15 |
| texto desplazable | 5 | 17 |
| teleprónter | 5 | 32 |
| script reader | 5 | 37 |
| video teleprompter | 5 | 38 |
| control por voz | 5 | 40 |
| teleprompter video | 5 | 40 |
| floating notes | 5 | 43 |

## Targeted follow-up: Spain, India, Saudi Arabia and Israel

Astro iPhone storefront research, 2026-11-08. These tables add the newly measured terms from a deeper competitor and spelling review; prior terms remain in the locale sections above. Results meeting popularity > 20 and difficulty < 60 appear first. Other results are exploratory. A score of 5 may indicate limited data. Threshold matches are not automatically suitable: assess feature fit, search intent and natural wording.

### es-ES — ES

Strong phrase-level candidates include **leer mientras grabas**, **grabar con texto**, and **texto en pantalla**. Presentaciones, texto, and voz are broader. Notas de voz usually means voice memos and is a poor fit despite its score. Pricing-related terms should not be included in metadata.

Search for “leer mientras grabas”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprónter (ID 1420515755); 3. Teleprompter (ID 941620509).

Search for “grabar con texto”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprónter (ID 1420515755); 3. Teleprompter (ID 941620509).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notas de voz | 58 | 43 |
| presentaciones | 49 | 44 |
| texto | 39 | 51 |
| texto en pantalla | 38 | 42 |
| grabar con texto | 36 | 44 |
| leer texto | 34 | 45 |
| voz | 34 | 48 |
| leer mientras grabas | 32 | 42 |
| video | 53 | 70 |
| autocue | 17 | 38 |
| vídeo | 14 | 73 |
| teleprompter para vídeo | 9 | 43 |
| presentación | 9 | 61 |
| oratoria | 8 | 11 |
| guion | 6 | 13 |
| presentacion | 6 | 62 |
| autocue español | 5 | 5 |
| desplazamiento por voz | 5 | 5 |
| ensayar discursos | 5 | 5 |
| guion para hablar | 5 | 5 |
| practicar discurso | 5 | 5 |
| teleprompter en español | 5 | 5 |
| texto deslizante | 5 | 5 |
| texto que se mueve | 5 | 5 |
| presentar | 5 | 7 |
| teleprompter flotante | 5 | 7 |
| guion para vídeo | 5 | 9 |
| notas para hablar | 5 | 9 |
| teleprompter con voz | 5 | 9 |
| guion para videos | 5 | 11 |
| guión | 5 | 11 |
| teleprompter por voz | 5 | 13 |
| apuntador de texto | 5 | 17 |
| guiones | 5 | 17 |
| texto en movimiento | 5 | 17 |
| prompter de voz | 5 | 19 |
| guion de video | 5 | 23 |
| leer mientras grabas video | 5 | 23 |
| notas para presentación | 5 | 33 |
| texto para vídeos hablados | 5 | 34 |
| leer y grabar | 5 | 36 |
| notas en pantalla | 5 | 42 |
| teleprompter video | 5 | 42 |
| grabación de vídeo | 5 | 45 |
| grabar vídeo | 5 | 47 |
| texto para leer | 5 | 55 |
| control de voz | 5 | 57 |
| texto para video | 5 | 63 |
| texto para vídeos | 5 | 63 |

### hi — IN

The strongest directly relevant additional result is **teleprompter for video**. Script and speech notes are broader, while float and mirror depend on the features and can have unrelated intent. Teleprompter free is pricing-related and should not be used in metadata. Most Hindi-script variants scored 5; spelling and naturalness need native review.

Search for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter: Floating Notes (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| scroll | 52 | 47 |
| teleprompter for video | 49 | 39 |
| float | 47 | 17 |
| mirror | 46 | 15 |
| recording | 42 | 54 |
| text | 36 | 50 |
| script | 33 | 17 |
| teleprompter free | 25 | 21 |
| speech notes | 22 | 23 |
| public speaking | 20 | 40 |
| आवाज पहचान | 5 | 5 |
| आवाज से चलने वाला टेलीप्रॉम्प्टर | 5 | 5 |
| आवाज से स्क्रॉल | 5 | 5 |
| ऑटो स्क्रॉल | 5 | 5 |
| चलता हुआ टेक्स्ट | 5 | 5 |
| चलता हुआ पाठ | 5 | 5 |
| टेलीप्रॉम्पटर वीडियो | 5 | 5 |
| टेलीप्रॉम्पटर हिंदी | 5 | 5 |
| टेलीप्रॉम्प्टर वीडियो | 5 | 5 |
| टेलीप्रॉम्प्टर हिंदी | 5 | 5 |
| प्रॉम्पटर | 5 | 5 |
| प्रॉम्प्टर | 5 | 5 |
| फ्लोटिंग टेक्स्ट | 5 | 5 |
| फ्लोटिंग स्क्रिप्ट | 5 | 5 |
| बोलते हुए पढ़ें | 5 | 5 |
| बोलने का अभ्यास | 5 | 5 |
| भाषण की तैयारी | 5 | 5 |
| भाषण लिखें | 5 | 5 |
| लिखा हुआ पढ़ें | 5 | 5 |
| वीडियो के लिए स्क्रिप्ट | 5 | 5 |
| वीडियो टेलीप्रॉम्प्टर | 5 | 5 |
| वीडियो प्रॉम्प्टर | 5 | 5 |
| वीडियो बनाएं | 5 | 5 |
| वीडियो रिकॉर्ड करें | 5 | 5 |
| वीडियो रिकॉर्डर | 5 | 5 |
| वीडियो स्क्रिप्ट | 5 | 5 |
| स्क्रिप्ट पढ़ना | 5 | 5 |
| स्क्रिप्ट पढ़ें | 5 | 5 |
| हिंदी टेलीप्रॉम्प्टर | 5 | 5 |
| हिंदी प्रॉम्प्टर | 5 | 5 |
| हिंदी स्क्रिप्ट | 5 | 5 |
| scrolling text | 5 | 9 |
| प्रॉम्प्ट | 5 | 13 |
| hindi teleprompter | 5 | 16 |
| teleprompter hindi | 5 | 16 |
| auto cue | 5 | 17 |
| video prompter | 5 | 17 |
| टेली प्रॉम्पटर | 5 | 17 |
| टेली प्रॉम्प्टर | 5 | 17 |
| autocue | 5 | 19 |
| teleprompter camera | 5 | 19 |
| teleprompter app | 5 | 21 |
| voice teleprompter | 5 | 36 |
| वीडियो बनाना | 5 | 54 |

### ar-SA — SA

**الملقن** and **teleprompter for video** merit consideration. Search results for الملقن were teleprompter apps, but the standalone word can have broader meanings. The 2026-11-09 Saudi storefront audit found that **خطابة** and **خطاب** primarily returned marriage apps despite the former's high score, so neither belongs in this teleprompter listing. ملاحظات is broad alone but its teleprompter and floating-note combinations were relevant. The earlier seed تلقين returned unrelated apps as well as teleprompters. See [the full intent audit](locale-intent-audit.md).

Search for “الملقن”: 1. Teleprompter: Floating Notes (ID 1559566851); 2. OnClip: Teleprompter for Video (ID 6636538421); 3. Teleprompter (ID 941620509).

Search for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter: Floating Notes (ID 1559566851).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| الملاحظات | 65 | 49 |
| خطابة | 59 | 48 |
| voice | 42 | 45 |
| mirror | 37 | 38 |
| reader | 35 | 11 |
| text | 35 | 56 |
| script | 32 | 39 |
| video recorder | 31 | 37 |
| teleprompter for video | 27 | 13 |
| الملقن | 24 | 11 |
| خطاب | 22 | 38 |
| تسجيل فيديو | 21 | 32 |
| private | 27 | 62 |
| arabic teleprompter | 5 | 5 |
| الملاحظات العائمة | 5 | 5 |
| تصوير فيديو بالنص | 5 | 5 |
| تلي برومبتر | 5 | 5 |
| تليبرومبتر | 5 | 5 |
| تليبرومبتير | 5 | 5 |
| قراءة النص أثناء التصوير | 5 | 5 |
| ملقن الفيديو | 5 | 5 |
| ملقن الفيديوهات | 5 | 5 |
| مُلقِّن | 5 | 5 |
| نص عائم | 5 | 5 |
| نص متحرك | 5 | 5 |
| التمرير الصوتي | 5 | 7 |
| تلقين الكلام | 5 | 7 |
| تمرير النص | 5 | 7 |
| ملقن نصوص | 5 | 7 |
| التمرير الآلي | 5 | 8 |
| تيلي برومبتر | 5 | 9 |
| ملقن النصوص | 5 | 9 |
| نص الخطاب | 5 | 9 |
| التعرف على الصوت | 5 | 11 |
| تيليبرومبتر | 5 | 11 |
| نصوص الفيديو | 5 | 11 |
| نصوص عائمة | 5 | 11 |
| نصوص متحركة | 5 | 11 |
| teleprompter arabic | 5 | 13 |
| قراءة النص | 5 | 13 |
| speech notes | 5 | 15 |
| video prompter | 5 | 15 |
| نص على الشاشة | 5 | 17 |
| voice teleprompter | 5 | 19 |
| اقرأ النص | 5 | 23 |
| كتابة النصوص | 5 | 23 |
| تلقين النصوص | 5 | 32 |
| نص الفيديو | 5 | 32 |
| نص التصوير | 5 | 41 |
| تلقين النص | 5 | 49 |
| التلقين | 5 | 55 |
| تلقين صوتي | 5 | 57 |
| التلقين للفيديو | 5 | 74 |

### he — IL

**פרומטר** is a promising alternate spelling and **teleprompter for video** is directly relevant. Voice, script, record, text, and camera are broad; verify native spelling and search intent. Most longer Hebrew variants scored 5.

Search for “פרומטר”: 1. Teleprompter.com (ID 1420515755); 2. BIGVU Teleprompter Captions AI (ID 1124958568); 3. Teleprompter Automatic (ID 1607873167).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| camera | 57 | 23 |
| record | 43 | 40 |
| teleprompter for video | 36 | 15 |
| voice | 36 | 17 |
| פרומטר | 29 | 19 |
| text | 28 | 45 |
| script | 27 | 13 |
| hebrew teleprompter | 5 | 5 |
| teleprompter hebrew | 5 | 5 |
| גלילה קולית | 5 | 5 |
| גלילת טקסט | 5 | 5 |
| הכנה לנאום | 5 | 5 |
| הערות צפות | 5 | 5 |
| טלפרומטר בעברית | 5 | 5 |
| טלפרומטר וידאו | 5 | 5 |
| טלפרומטר לצילום | 5 | 5 |
| טלפרומפטר לצילום | 5 | 5 |
| טקסט זז | 5 | 5 |
| טקסט לווידאו | 5 | 5 |
| טקסט לוידאו | 5 | 5 |
| טקסט לסרטון | 5 | 5 |
| טקסט מתגלגל | 5 | 5 |
| טקסט על המסך | 5 | 5 |
| כתוביות רצות | 5 | 5 |
| לקרוא ולצלם | 5 | 5 |
| נאומים | 5 | 5 |
| עברית teleprompter | 5 | 5 |
| פתק צף | 5 | 5 |
| קורא טקסטים | 5 | 5 |
| קריאה בזמן צילום | 5 | 5 |
| קריאת תסריט | 5 | 5 |
| קריאת תסריטים | 5 | 5 |
| תסריט לווידאו | 5 | 5 |
| תסריט לסרטון | 5 | 5 |
| תרגול נאום | 5 | 5 |
| מעקב קול | 5 | 7 |
| קורא טקסט | 5 | 9 |
| טלפרומפטר חינם | 5 | 12 |
| פרומפטר | 5 | 13 |
| הקלטת סרטון | 5 | 14 |
| autocue | 5 | 15 |
| speech notes | 5 | 15 |
| פרומפטר וידאו | 5 | 15 |
| צילום סרטונים | 5 | 15 |
| זיהוי קול | 5 | 17 |
| טלפרומפטר בעברית | 5 | 18 |
| voice teleprompter | 5 | 19 |
| טלפרומפטר קולי | 5 | 19 |
| video prompter | 5 | 21 |
| קריין | 5 | 23 |
| טלפרומפטר לסרטון | 5 | 27 |
| צילום וידאו | 5 | 31 |

## Targeted follow-up: Czech, Danish, Finnish, Croatian and Hungarian

Astro iPhone research, 2026-11-08. These tables add newly tracked terms to the original locale sections above. Terms with popularity > 20 and difficulty < 60 are listed first; the remainder are exploratory fallbacks. Scores of 5 can indicate limited data. Search rankings and metrics are snapshots, and the numeric threshold alone does not imply keyword relevance or a likely rank. Competitor app names are for research and should not be copied into metadata.

### Czech (cs) — CZ

Teleprompter for video is directly relevant. Although prezentace scored 57/40, its top results were Google Slides, Microsoft PowerPoint and Canva, indicating presentation software intent. Broad terms such as notes, auto and text should be used cautiously.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

Top results for “prezentace”: 1. Google Slides (ID 879478102); 2. Microsoft PowerPoint (ID 586449534); 3. Canva: AI Video & Photo Editor (ID 897446215).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 69 | 54 |
| prezentace | 57 | 40 |
| auto | 56 | 38 |
| text | 39 | 47 |
| voice | 36 | 38 |
| mirror | 34 | 17 |
| text editor | 34 | 48 |
| script | 28 | 39 |
| teleprompter for video | 27 | 13 |
| automatické posouvání textu | 5 | 5 |
| automatické rolování | 5 | 5 |
| běžící text | 5 | 5 |
| hlasové ovládání | 5 | 5 |
| hlasové sledování | 5 | 5 |
| nahrát video | 5 | 5 |
| nápověda textu | 5 | 5 |
| pohyblivý text | 5 | 5 |
| posouvání textu | 5 | 5 |
| poznámky na obrazovce | 5 | 5 |
| příprava projevu | 5 | 5 |
| rolující text | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| scénář pro video | 5 | 5 |
| scénář videa | 5 | 5 |
| teleprompter v češtině | 5 | 5 |
| teleprompter česky | 5 | 5 |
| text na obrazovce | 5 | 5 |
| text při natáčení | 5 | 5 |
| čtecí okno | 5 | 5 |
| čtení scénáře | 5 | 5 |
| čtení textu při natáčení | 5 | 5 |
| natáčení videa | 5 | 7 |
| speech notes | 5 | 7 |
| autocue | 5 | 9 |
| nahrávání videa | 5 | 9 |
| nápověda | 5 | 9 |
| teleprompter app | 5 | 9 |
| teleprompter video | 5 | 9 |
| voice teleprompter | 5 | 9 |
| public speaking | 5 | 11 |
| teleprompter free | 5 | 13 |
| teleprompter hlas | 5 | 13 |
| video prompter | 5 | 13 |
| mluvené slovo | 5 | 15 |
| teleprompter pro video | 5 | 17 |
| record video | 5 | 19 |
| teleprompter kamera | 5 | 23 |
| video recorder | 5 | 23 |
| recording | 5 | 33 |
| projev | 5 | 36 |
| text ve videu | 5 | 70 |

### Danish (da) — DK

Teleprompter for video is directly relevant. Although manus scored 26/47, the top results included Manus - AI Agent & Automation, Claude and ChatGPT, so its search intent is a poor fit. Broad terms need care.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Video Teleprompter Lite (ID 1031079244).

Top results for “manus”: 1. Manus - AI Agent & Automation (ID 6740909540); 2. Claude by Anthropic (ID 6473753684); 3. ChatGPT (ID 6448311069).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 57 | 42 |
| auto | 40 | 48 |
| text | 38 | 42 |
| voice | 35 | 43 |
| mirror | 32 | 17 |
| teleprompter for video | 31 | 15 |
| manus | 26 | 47 |
| autocue dansk | 5 | 5 |
| automatisk scrolling | 5 | 5 |
| fremlæggelse | 5 | 5 |
| læs mens du optager | 5 | 5 |
| læse manus | 5 | 5 |
| læse manuskript | 5 | 5 |
| manuskript til video | 5 | 5 |
| oplæsning af tekst | 5 | 5 |
| rullende tekst | 5 | 5 |
| script rehearser | 5 | 5 |
| scrollende tekst | 5 | 5 |
| stemmekontrol | 5 | 5 |
| talegenkendelse | 5 | 5 |
| talenoter | 5 | 5 |
| teleprompter dansk | 5 | 5 |
| teleprompter med stemme | 5 | 5 |
| video manuskript | 5 | 5 |
| videooptagelse | 5 | 5 |
| videoscript | 5 | 5 |
| noter på skærmen | 5 | 7 |
| optag med tekst | 5 | 7 |
| scrolling text | 5 | 7 |
| tale noter | 5 | 7 |
| tekst på skærmen | 5 | 7 |
| løbende tekst | 5 | 8 |
| public speaking | 5 | 9 |
| teleprompter video | 5 | 9 |
| video prompter | 5 | 9 |
| autocue til video | 5 | 11 |
| teleprompter app | 5 | 11 |
| teleprompter free | 5 | 11 |
| voice teleprompter | 5 | 11 |
| speech notes | 5 | 15 |
| teleprompter kamera | 5 | 15 |
| record video | 5 | 17 |
| teleprompter til video | 5 | 17 |
| text editor | 5 | 17 |
| præsentation | 5 | 19 |
| script | 5 | 21 |
| video recorder | 5 | 23 |
| recording | 5 | 36 |
| optag video | 5 | 49 |

### Finnish (fi) — FI

Teleprompter for video is directly relevant. The tested Finnish-language variants predominantly scored 5; validate natural wording with a native speaker. Voice, mirror and notes are relevant features but broad searches.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 58 | 38 |
| auto | 43 | 52 |
| voice | 35 | 21 |
| text | 30 | 23 |
| mirror | 29 | 13 |
| teleprompter for video | 28 | 11 |
| automaattinen vierittäminen | 5 | 5 |
| esityksen muistiinpanot | 5 | 5 |
| liikkuva teksti | 5 | 5 |
| muistiinpanot näytöllä | 5 | 5 |
| prompteri | 5 | 5 |
| prompteri video | 5 | 5 |
| puheen harjoittelu | 5 | 5 |
| puhemuistiinpanot | 5 | 5 |
| puhesufflööri | 5 | 5 |
| puheteksti | 5 | 5 |
| rullaava teksti | 5 | 5 |
| sanelulaite | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| sufflööri | 5 | 5 |
| tallenna video | 5 | 5 |
| teksti näytöllä | 5 | 5 |
| tekstin lukeminen | 5 | 5 |
| tekstin lukeminen videolle | 5 | 5 |
| videokuvaus | 5 | 5 |
| vierivä teksti | 5 | 5 |
| äänen seuranta | 5 | 5 |
| autocue | 5 | 7 |
| puheentunnistus | 5 | 7 |
| teleprompter app | 5 | 7 |
| teleprompter free | 5 | 7 |
| teleprompter video | 5 | 7 |
| voice teleprompter | 5 | 7 |
| public speaking | 5 | 9 |
| speech notes | 5 | 9 |
| videon käsikirjoitus | 5 | 9 |
| script | 5 | 11 |
| teleprompteri video | 5 | 11 |
| video prompter | 5 | 11 |
| record video | 5 | 15 |
| video recorder | 5 | 15 |
| recording | 5 | 21 |
| videon tallennus | 5 | 31 |
| teleprompteri suomi | 5 | 41 |
| text editor | 5 | 41 |
| teleprompter suomi | 5 | 42 |

### Croatian (hr) — HR

No newly measured specific teleprompter phrase met the strict threshold. Teleprompter for video scored 19/5 and is a relevant low-data fallback; search results showed teleprompter apps. Voice, notes and auto meet the numerical threshold but are broad. The prior result teleprompter 37/5 remains a direct candidate.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. BIGVU Teleprompter Captions AI (ID 1124958568).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 58 | 21 |
| auto | 50 | 34 |
| voice | 30 | 19 |
| mirror | 20 | 13 |
| text | 20 | 15 |
| teleprompter for video | 19 | 5 |
| recording | 19 | 23 |
| autocue | 5 | 5 |
| automatsko pomicanje teksta | 5 | 5 |
| automatsko skrolanje | 5 | 5 |
| bilješke na ekranu | 5 | 5 |
| javni nastup | 5 | 5 |
| klizni tekst | 5 | 5 |
| pokretni tekst | 5 | 5 |
| pomični tekst | 5 | 5 |
| prepoznavanje glasa | 5 | 5 |
| priprema govora | 5 | 5 |
| scenarij za video | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| snimanje videa s tekstom | 5 | 5 |
| sufler | 5 | 5 |
| sufler za tekst | 5 | 5 |
| sufler za video | 5 | 5 |
| tekst na ekranu | 5 | 5 |
| tekst na zaslonu | 5 | 5 |
| teleprompter app | 5 | 5 |
| teleprompter free | 5 | 5 |
| teleprompter hrvatski | 5 | 5 |
| teleprompter na hrvatskom | 5 | 5 |
| video skripta | 5 | 5 |
| voice teleprompter | 5 | 5 |
| čitanje dok snimaš | 5 | 5 |
| čitanje scenarija | 5 | 5 |
| šalabahter | 5 | 5 |
| public speaking | 5 | 7 |
| snimanje videa | 5 | 7 |
| speech notes | 5 | 7 |
| teleprompter video | 5 | 9 |
| video prompter | 5 | 9 |
| script | 5 | 15 |
| record video | 5 | 17 |
| teleprompter za video | 5 | 17 |
| text editor | 5 | 19 |
| video recorder | 5 | 21 |
| prezentacija | 5 | 42 |
| snimi video | 5 | 45 |

### Hungarian (hu) — HU

Teleprompter for video is directly relevant. Most Hungarian-language variants scored 5. Voice, mirror and notes can describe features but are broad searches; verify Hungarian wording with a native speaker.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 65 | 45 |
| auto | 51 | 54 |
| voice | 38 | 21 |
| mirror | 35 | 15 |
| text | 30 | 41 |
| teleprompter for video | 25 | 15 |
| forgatókönyv olvasó | 5 | 5 |
| futó szöveg | 5 | 5 |
| gördülő szöveg | 5 | 5 |
| hangkövetés | 5 | 5 |
| jegyzetek a képernyőn | 5 | 5 |
| mozgó szöveg | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| szöveg a képernyőn | 5 | 5 |
| szöveg görgetése | 5 | 5 |
| szöveg olvasása | 5 | 5 |
| szövegsúgó | 5 | 5 |
| súgó alkalmazás | 5 | 5 |
| súgógép videóhoz | 5 | 5 |
| teleprompter magyarul | 5 | 5 |
| teleprompter videóhoz | 5 | 5 |
| videó forgatókönyv | 5 | 5 |
| előadás | 5 | 7 |
| hangfelismerés | 5 | 7 |
| prezentáció | 5 | 7 |
| public speaking | 5 | 7 |
| autocue | 5 | 9 |
| speech notes | 5 | 9 |
| teleprompter app | 5 | 9 |
| teleprompter free | 5 | 9 |
| voice teleprompter | 5 | 9 |
| beszéd gyakorlás | 5 | 11 |
| beszéd szöveg | 5 | 13 |
| teleprompter videó | 5 | 13 |
| video prompter | 5 | 13 |
| videó felvétel | 5 | 13 |
| videó készítés | 5 | 13 |
| record video | 5 | 15 |
| video recorder | 5 | 17 |
| teleprompter kamera | 5 | 21 |
| text editor | 5 | 23 |
| súgó | 5 | 28 |
| script | 5 | 38 |
| recording | 5 | 39 |
| videó szöveg | 5 | 39 |
| teleprompter magyar | 5 | 76 |

## Targeted follow-up: Catalan, Greek, Malay, Norwegian, Romanian, Slovak, Slovenian and Swedish

Astro iPhone research, 2026-11-08. These tables add newly tracked terms to the original locale sections and earlier follow-ups above. Results with popularity > 20 and difficulty < 60 appear first; the rest are exploratory. Popularity 5 can indicate limited data. Numerical matches do not guarantee ranking or relevant search intent. Native-speaker review is needed before publishing localized copy. Notes is a broad term, although floating notes is an iOS feature per the product owner. Competitor names are for research, not metadata.

### Catalan (ca) — ES

Top results for “teleprompter for video”: 1. Teleprompter para Vídeo (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprónter (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| voice | 47 | 48 |
| auto | 47 | 59 |
| teleprompter for video | 42 | 43 |
| mirror | 38 | 47 |
| script | 36 | 21 |
| video recorder | 36 | 45 |
| text | 32 | 46 |
| text editor | 24 | 47 |
| notes | 62 | 65 |
| public speaking | 9 | 19 |
| teleprompter app | 9 | 41 |
| recording | 9 | 47 |
| assaig de discurs | 5 | 5 |
| llegir guió | 5 | 5 |
| llegir mentre graves | 5 | 5 |
| seguiment de veu | 5 | 5 |
| teleprompter català | 5 | 5 |
| teleprompter en català | 5 | 5 |
| text desplaçable | 5 | 5 |
| text en moviment | 5 | 5 |
| control per veu | 5 | 11 |
| guió de vídeo | 5 | 13 |
| script rehearser | 5 | 13 |
| scrolling text | 5 | 15 |
| lector de text | 5 | 17 |
| apuntador de text | 5 | 19 |
| text en pantalla | 5 | 21 |
| voice teleprompter | 5 | 21 |
| speech notes | 5 | 23 |
| teleprompter per vídeo | 5 | 30 |
| presentacions | 5 | 36 |
| video prompter | 5 | 44 |
| notes a la pantalla | 5 | 47 |
| record video | 5 | 49 |
| gravar vídeo | 5 | 57 |

### Greek (el) — GR

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 62 | 41 |
| voice | 36 | 19 |
| auto | 33 | 49 |
| mirror | 30 | 17 |
| teleprompter for video | 28 | 11 |
| video recorder | 28 | 21 |
| text | 28 | 23 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| αιωρούμενες σημειώσεις | 5 | 5 |
| αναγνώριση φωνής | 5 | 5 |
| κείμενο στην οθόνη | 5 | 5 |
| κυλιόμενο κείμενο | 5 | 5 |
| παρουσίαση | 5 | 5 |
| προβολέας κειμένου | 5 | 5 |
| προμπτερ | 5 | 5 |
| σενάριο βίντεο | 5 | 5 |
| σημειώσεις στην οθόνη | 5 | 5 |
| τηλεπρομπτερ | 5 | 5 |
| τηλεπρομπτερ βίντεο | 5 | 5 |
| τηλεπρομπτερ για βίντεο | 5 | 5 |
| τηλεπρομπτερ ελληνικά | 5 | 5 |
| φωνητικός έλεγχος | 5 | 5 |
| autocue | 5 | 7 |
| teleprompter app | 5 | 7 |
| video prompter | 5 | 7 |
| ομιλία | 5 | 7 |
| public speaking | 5 | 9 |
| speech notes | 5 | 9 |
| εγγραφή βίντεο | 5 | 9 |
| script | 5 | 11 |
| voice teleprompter | 5 | 15 |
| record video | 5 | 17 |
| text editor | 5 | 19 |
| λήψη βίντεο | 5 | 19 |
| recording | 5 | 36 |

### Malay (ms) — MY

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter - Captions (ID 6670697259).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 69 | 53 |
| mirror | 45 | 11 |
| voice | 40 | 40 |
| script | 39 | 41 |
| video recorder | 39 | 45 |
| text | 37 | 49 |
| auto | 36 | 11 |
| text editor | 33 | 19 |
| teleprompter for video | 31 | 33 |
| recording | 19 | 44 |
| baca sambil rakam | 5 | 5 |
| latihan ucapan | 5 | 5 |
| pengesanan suara | 5 | 5 |
| script rehearser | 5 | 5 |
| skrip untuk video | 5 | 5 |
| skrol automatik | 5 | 5 |
| teks di skrin | 5 | 5 |
| teleprompter bahasa melayu | 5 | 5 |
| nota di skrin | 5 | 8 |
| pembentangan | 5 | 9 |
| rakaman video | 5 | 9 |
| teks bergerak | 5 | 9 |
| teks berjalan | 5 | 11 |
| public speaking | 5 | 13 |
| baca teks | 5 | 15 |
| speech notes | 5 | 15 |
| autocue | 5 | 17 |
| teleprompter app | 5 | 23 |
| teleprompter video | 5 | 23 |
| teleprompter untuk video | 5 | 37 |
| prompter video | 5 | 38 |
| scrolling text | 5 | 40 |
| record video | 5 | 41 |
| voice teleprompter | 5 | 43 |
| video prompter | 5 | 46 |

### Norwegian (no) — NO

**Intent caution:** “presentasjon” returned Google Slides, PowerPoint and Keynote among the first results; users may be looking for slide software.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Video Teleprompter Lite (ID 1031079244).

Top results for “presentasjon”: 1. Google Slides (ID 879478102); 2. Microsoft PowerPoint (ID 586449534); 3. Keynote: Design Presentations (ID 361285480).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 61 | 40 |
| presentasjon | 54 | 43 |
| text | 36 | 21 |
| voice | 34 | 15 |
| mirror | 30 | 9 |
| teleprompter for video | 28 | 7 |
| auto | 28 | 41 |
| autocue norsk | 5 | 5 |
| automatisk scrolling | 5 | 5 |
| lese mens du filmer | 5 | 5 |
| løpende tekst | 5 | 5 |
| manuskript | 5 | 5 |
| notater på skjermen | 5 | 5 |
| rullende tekst | 5 | 5 |
| script rehearser | 5 | 5 |
| stemmestyring | 5 | 5 |
| talegjenkjenning | 5 | 5 |
| tekst på skjermen | 5 | 5 |
| teleprompter norsk | 5 | 5 |
| teleprompter på norsk | 5 | 5 |
| videomanus | 5 | 5 |
| ta opp video | 5 | 7 |
| teleprompter video | 5 | 7 |
| text editor | 5 | 7 |
| lese tekst | 5 | 9 |
| speech notes | 5 | 9 |
| teleprompter app | 5 | 9 |
| public speaking | 5 | 15 |
| video prompter | 5 | 15 |
| voice teleprompter | 5 | 17 |
| script | 5 | 21 |
| scrolling text | 5 | 21 |
| recording | 5 | 32 |
| øve på tale | 5 | 42 |
| video recorder | 5 | 43 |
| record video | 5 | 49 |

### Romanian (ro) — RO

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 64 | 47 |
| voice | 40 | 23 |
| text | 35 | 47 |
| mirror | 32 | 19 |
| teleprompter for video | 31 | 17 |
| text editor | 31 | 39 |
| script | 29 | 19 |
| video recorder | 27 | 43 |
| auto | 53 | 60 |
| citește scenariul | 5 | 5 |
| citește în timp ce filmezi | 5 | 5 |
| filmează video | 5 | 5 |
| notițe pe ecran | 5 | 5 |
| recunoaștere vocală | 5 | 5 |
| scenariu video | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| sufleur | 5 | 5 |
| teleprompter pentru video | 5 | 5 |
| teleprompter română | 5 | 5 |
| teleprompter în română | 5 | 5 |
| text care se derulează | 5 | 5 |
| text derulant | 5 | 5 |
| text pe ecran | 5 | 5 |
| urmărire voce | 5 | 5 |
| public speaking | 5 | 11 |
| speech notes | 5 | 11 |
| teleprompter video | 5 | 11 |
| video prompter | 5 | 11 |
| autocue | 5 | 13 |
| teleprompter app | 5 | 13 |
| voice teleprompter | 5 | 13 |
| prompter video | 5 | 19 |
| record video | 5 | 23 |
| citire text | 5 | 37 |
| prezentare | 5 | 47 |
| recording | 5 | 47 |

### Slovak (sk) — SK

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. BIGVU Teleprompter Captions AI (ID 1124958568).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 66 | 44 |
| auto | 53 | 33 |
| mirror | 31 | 11 |
| voice | 31 | 15 |
| text | 30 | 21 |
| teleprompter for video | 21 | 9 |
| autocue | 5 | 5 |
| bežiaci text | 5 | 5 |
| natáčanie videa | 5 | 5 |
| pohyblivý text | 5 | 5 |
| posúvanie textu | 5 | 5 |
| poznámky na obrazovke | 5 | 5 |
| príprava prejavu | 5 | 5 |
| rozpoznávanie hlasu | 5 | 5 |
| script rehearser | 5 | 5 |
| teleprompter app | 5 | 5 |
| teleprompter po slovensky | 5 | 5 |
| teleprompter slovensky | 5 | 5 |
| text na obrazovke | 5 | 5 |
| voice teleprompter | 5 | 5 |
| čítanie scenára | 5 | 5 |
| čítať počas natáčania | 5 | 5 |
| speech notes | 5 | 7 |
| public speaking | 5 | 9 |
| scenár videa | 5 | 9 |
| teleprompter video | 5 | 9 |
| video prompter | 5 | 9 |
| prezentácia | 5 | 13 |
| script | 5 | 13 |
| scrolling text | 5 | 13 |
| record video | 5 | 15 |
| video recorder | 5 | 15 |
| teleprompter pre video | 5 | 17 |
| text editor | 5 | 19 |
| recording | 5 | 23 |

### Slovenian (sl-SI) — SI

The new terms did not produce a specific teleprompter phrase meeting the original thresholds. The earlier “teleprompter” result remains a direct candidate.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| notes | 63 | 21 |
| auto | 41 | 38 |
| voice | 22 | 9 |
| mirror | 19 | 9 |
| text | 19 | 15 |
| autocue | 5 | 5 |
| besedilo na zaslonu | 5 | 5 |
| branje med snemanjem | 5 | 5 |
| branje scenarija | 5 | 5 |
| predstavitev | 5 | 5 |
| premikajoče se besedilo | 5 | 5 |
| prepoznavanje govora | 5 | 5 |
| priprava govora | 5 | 5 |
| scenarij za video | 5 | 5 |
| script rehearser | 5 | 5 |
| scrolling text | 5 | 5 |
| snemanje videoposnetka | 5 | 5 |
| tekoče besedilo | 5 | 5 |
| teleprompter app | 5 | 5 |
| teleprompter v slovenščini | 5 | 5 |
| teleprompter video | 5 | 5 |
| video prompter | 5 | 5 |
| voice teleprompter | 5 | 5 |
| zapiski na zaslonu | 5 | 5 |
| public speaking | 5 | 7 |
| speech notes | 5 | 7 |
| script | 5 | 9 |
| teleprompter for video | 5 | 9 |
| record video | 5 | 13 |
| text editor | 5 | 13 |
| video recorder | 5 | 13 |
| recording | 5 | 17 |
| teleprompter za video | 5 | 42 |
| teleprompter slovensko | 5 | 60 |

### Swedish (sv) — SE

**Intent caution:** “presentation” returned Google Presentations, PowerPoint and Google Docs among the first results; users may be looking for slide software.

Top results for “teleprompter for video”: 1. Teleprompter for Video (ID 1139307843); 2. Teleprompter (ID 941620509); 3. Teleprompter.com (ID 1420515755).

Top results for “presentation”: 1. Google Presentationer (ID 879478102); 2. Microsoft PowerPoint (ID 586449534); 3. Google Dokument (ID 842842640).

| Keyword | Popularity | Difficulty |
|---|---:|---:|
| presentation | 63 | 47 |
| notes | 61 | 43 |
| voice | 42 | 44 |
| text | 42 | 54 |
| mirror | 34 | 23 |
| auto | 34 | 56 |
| teleprompter for video | 33 | 11 |
| text editor | 27 | 39 |
| script | 26 | 19 |
| autocue svenska | 5 | 5 |
| automatisk scrollning | 5 | 5 |
| läsa medan du filmar | 5 | 5 |
| löpande text | 5 | 5 |
| manuskript | 5 | 5 |
| rullande text | 5 | 5 |
| röstigenkänning | 5 | 5 |
| tala inför publik | 5 | 5 |
| teleprompter på svenska | 5 | 5 |
| anteckningar på skärmen | 5 | 7 |
| public speaking | 5 | 7 |
| scrolling text | 5 | 7 |
| text på skärmen | 5 | 7 |
| script rehearser | 5 | 9 |
| teleprompter video | 5 | 9 |
| teleprompter app | 5 | 11 |
| teleprompter för video | 5 | 11 |
| voice teleprompter | 5 | 11 |
| speech notes | 5 | 15 |
| video prompter | 5 | 15 |
| läsa text | 5 | 19 |
| videoinspelning | 5 | 19 |
| record video | 5 | 23 |
| öva tal | 5 | 39 |
| video recorder | 5 | 40 |
| videomanus | 5 | 42 |
| recording | 5 | 43 |
| teleprompter svenska | 5 | 45 |

