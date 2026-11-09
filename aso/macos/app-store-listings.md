# TalkRoll macOS App Store metadata

Mac storefront research snapshot: 2026-11-09. Astro temporary app **TalkRoll macOS Keyword Research** (ID `102`, platform `mac`). These are proposed fields, not live App Store Connect data. All 39 requested localizations appear in [Apple’s supported localization list](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations). See [US Mac research](en-keywords.md), [all localized Mac research](localized-keywords.md), and [the word-by-word intent audit](locale-intent-audit.md).

**App Store Connect platform caveat:** Apple defines the localized name and subtitle as app information shared across the platforms in one app record, while keywords are platform-version information. This project currently sets the same `com.talkroll.app` bundle ID for iOS and macOS. If the Mac build is added to the same app record as iOS, use one common name/subtitle per locale and recheck the Mac keyword fields against those shared visible words. The distinct Mac subtitles here require a separate app record with its own bundle ID or a coordinated shared-name/subtitle revision. Do not paste conflicting visible fields into the existing iOS record. [Apple app information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/) · [Apple platform-version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/).

The Mac app displays a floating prompter beside the camera or other windows, follows speech, and can scroll a script. Voice-following availability and accuracy depend on system language and recognition support; validate the shipped build for each market. It does **not** capture video in-app; “for video” means use alongside video calls or recording software. No caption generation, AI writing, or system-wide floating note taking is claimed. The es-MX listing is an **English indexing experiment** carried forward from iOS: its name mirrors the en-US subtitle and may display in English to Mexican customers. Cross-locale indexing is not guaranteed.

Some separately measured category forms (such as `teleprompter` and `prompter`, or native transliterations) are retained across fields where their Mac search results show distinct category demand. This is a testable indexing choice, not proof that Apple will index those forms separately. Native keyword fields use the remaining byte space for directly relevant lower-data features when their combined results support the category.

## Validation

Apple limits: name and subtitle at most 30 characters each; keywords at most 100 UTF-8 bytes and each keyword more than two characters. Counts below use Unicode code points. Comma format, exact duplicates, visible-word overlap, common connector words, and supported-feature claims were checked; native fluency and App Store Connect acceptance still require human review.

| Locale | Name chars | Subtitle chars | Keyword chars | Keyword bytes | Result |
|---|---:|---:|---:|---:|---|
| en-US | 24 | 22 | 97 | 97 | Pass |
| en-GB | 24 | 29 | 95 | 95 | Pass |
| en-CA | 24 | 29 | 95 | 95 | Pass |
| en-AU | 24 | 29 | 95 | 95 | Pass |
| es-MX | 22 | 26 | 89 | 89 | Pass |
| ca | 22 | 29 | 94 | 94 | Pass |
| cs | 22 | 19 | 89 | 92 | Pass |
| da | 22 | 27 | 86 | 87 | Pass |
| de-DE | 22 | 27 | 90 | 91 | Pass |
| el | 22 | 25 | 72 | 89 | Pass |
| es-ES | 22 | 23 | 98 | 99 | Pass |
| fi | 22 | 27 | 88 | 90 | Pass |
| fr-FR | 25 | 23 | 90 | 91 | Pass |
| hi | 22 | 24 | 63 | 91 | Pass |
| hr | 22 | 28 | 94 | 96 | Pass |
| hu | 22 | 25 | 90 | 98 | Pass |
| id | 22 | 26 | 92 | 92 | Pass |
| it | 22 | 27 | 92 | 92 | Pass |
| ja | 12 | 12 | 43 | 93 | Pass |
| ko | 14 | 13 | 46 | 100 | Pass |
| ms | 22 | 20 | 94 | 94 | Pass |
| nl-NL | 22 | 28 | 89 | 89 | Pass |
| no | 22 | 22 | 84 | 85 | Pass |
| pl | 22 | 25 | 88 | 92 | Pass |
| pt-BR | 22 | 25 | 90 | 91 | Pass |
| pt-PT | 22 | 24 | 91 | 93 | Pass |
| ro | 22 | 21 | 93 | 93 | Pass |
| ru | 16 | 22 | 54 | 97 | Pass |
| sk | 22 | 17 | 86 | 90 | Pass |
| sv | 22 | 22 | 88 | 90 | Pass |
| th | 22 | 20 | 42 | 92 | Pass |
| tr | 22 | 27 | 81 | 83 | Pass |
| uk | 20 | 25 | 59 | 99 | Pass |
| vi | 22 | 25 | 77 | 93 | Pass |
| zh-Hans | 14 | 7 | 41 | 95 | Pass |
| zh-Hant | 12 | 7 | 46 | 98 | Pass |
| ar-SA | 22 | 22 | 66 | 94 | Pass |
| he | 22 | 20 | 67 | 93 | Pass |
| sl-SI | 22 | 25 | 91 | 91 | Pass |

## Metadata by locale

## English (US) — en-US

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Teleprompter for Video

**Keywords:** `script,reader,floating,notch,webcam,overlay,auto,scroll,meeting,rehearse,mirror,cues,pace,webinar`

**Counts:** 24 / 22 / 97 chars; 97 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 63/21, `teleprompter for video` 55/15, `voice prompter` 39/5.

## English (UK) — en-GB

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Floating Teleprompter for Mac

**Keywords:** `script,reader,notch,webcam,overlay,auto,scroll,meeting,rehearse,mirror,window,cues,pace,webinar`

**Counts:** 24 / 29 / 95 chars; 95 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 56/11, `voice prompter` 31/5, `script reader` 22/9.

## English (Canada) — en-CA

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Floating Teleprompter for Mac

**Keywords:** `script,reader,notch,webcam,overlay,auto,scroll,meeting,rehearse,mirror,window,cues,pace,webinar`

**Counts:** 24 / 29 / 95 chars; 95 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 57/9, `voice prompter` 27/5, `script reader` 27/9.

## English (Australia) — en-AU

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Floating Teleprompter for Mac

**Keywords:** `script,reader,notch,webcam,overlay,auto,scroll,meeting,rehearse,mirror,window,cues,pace,webinar`

**Counts:** 24 / 29 / 95 chars; 95 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 58/9, `voice prompter` 27/9, `script reader` 24/13.

## Spanish (Mexico; English slot) — es-MX

**Name:** Teleprompter for Video

**Subtitle:** Scripts beside your webcam

**Keywords:** `camera,screen,speech,reading,presenter,presentation,interview,webinar,eye,contact,speaker`

**Counts:** 22 / 26 / 89 chars; 89 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 63/9, `speech` 23/9, `camera` 51/19, `floating teleprompter` 5/9.

**Space:** 11 bytes unused. The remaining English terms either overlap en-US or point to weak video-capture, lecture, or script-line searches in the Mexico Mac store.

## Catalan — ca

**Name:** TalkRoll: Teleprompter

**Subtitle:** Guions al costat de la càmera

**Keywords:** `prompter,script,video,voice,notch,overlay,flotants,veu,mirall,assaig,lector,discurs,text,ritme`

**Counts:** 22 / 29 / 94 chars; 94 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 59/9, `prompter` 42/9, `lector de guions` 5/5.

## Czech — cs

**Name:** TalkRoll: Teleprompter

**Subtitle:** Scénář vedle kamery

**Keywords:** `video,script,reader,voice,notch,overlay,mirror,text,plovoucí,posouvání,hlas,zrcadlo,tempo`

**Counts:** 22 / 19 / 89 chars; 92 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 45/5, `floating teleprompter` 5/5.

**Space:** 8 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Danish — da

**Name:** TalkRoll: Teleprompter

**Subtitle:** Manus ved siden af kameraet

**Keywords:** `voice,mirror,stemme,tekst,notch,overlay,rulning,flydende,tale,spejl,øvelse,tempo,video`

**Counts:** 22 / 27 / 86 chars; 87 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 37/5, `manuskript læser` 5/5.

**Space:** 13 bytes unused. The native Mac feature words checked next were sparse; the high-score `video` intent is already included, and the remaining space is not filled with a repeated camera inflection.

## German — de-DE

**Name:** TalkRoll: Teleprompter

**Subtitle:** Skript direkt an der Kamera

**Keywords:** `prompter,sprechen,auto,scroll,notch,overlay,stimme,schwebende,video,spiegel,üben,rede,text`

**Counts:** 22 / 27 / 90 chars; 91 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 53/9, `prompter` 32/9, `skript lesen` 5/5.

## Greek — el

**Name:** TalkRoll: Teleprompter

**Subtitle:** Κείμενο δίπλα στην κάμερα

**Keywords:** `video,voice,mirror,notes,notch,overlay,reader,script,σενάριο,κύλιση,φωνή`

**Counts:** 22 / 25 / 72 chars; 89 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 40/7, `υποβολέας` 5/5.

**Space:** 11 bytes unused. Greek UTF-8 bytes constrain the field; the measured native voice, script, and scrolling terms are already included.

## Spanish (Spain) — es-ES

**Name:** TalkRoll: Teleprompter

**Subtitle:** Guion junto a la cámara

**Keywords:** `prompter,texto,pantalla,voz,notch,overlay,vídeo,desplazamiento,ensayo,discurso,espejo,ritmo,lector`

**Counts:** 22 / 23 / 98 chars; 99 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 59/9, `prompter` 42/9, `lector de guiones` 5/5.

## Finnish — fi

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lue teksti kameran vieressä

**Keywords:** `video,prompter,voice,mirror,notch,overlay,notes,ääni,vieritys,muistiinpanot,puhe,peilaus`

**Counts:** 22 / 27 / 88 chars; 90 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 42/7, `prompter` 28/5, `käsikirjoitus` 5/5.

**Space:** 10 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## French — fr-FR

**Name:** TalkRoll: Prompteur vidéo

**Subtitle:** Lisez près de la caméra

**Keywords:** `teleprompteur,auto,scroll,notch,overlay,discours,défilement,flottantes,script,miroir,texte`

**Counts:** 25 / 23 / 90 chars; 91 keyword bytes.

**Measured Mac demand to interpret:** `prompteur` 48/9, `teleprompteur` 31/7, `téléprompteur` 6/7.

## Hindi — hi

**Name:** TalkRoll: Teleprompter

**Subtitle:** Voice Prompter for Video

**Keywords:** `script,reader,scroll,webcam,mirror,notch,overlay,टेलीप्रॉम्प्टर`

**Counts:** 22 / 24 / 63 chars; 91 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 57/9, `voice prompter` 26/7, `टेलीप्रॉम्प्टर` 5/7.

**Language choice:** In the India Mac storefront, English `teleprompter` (57/9) and `voice prompter` (26/7) had stronger measured category demand than the Hindi variants (5). The visible fields therefore target those exact English phrases; the keyword field tests relevant Hindi searches only where the Mac SERP supports them.

**Space:** 9 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Croatian — hr

**Name:** TalkRoll: Teleprompter

**Subtitle:** Tekst uz kameru dok govorite

**Keywords:** `voice,video,glas,notch,overlay,scenarij,pomicanje,plutajuće,zrcalo,kamera,vježba,prozor,brzina`

**Counts:** 22 / 28 / 94 chars; 96 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 37/5, `scenarij` 5/5.

## Hungarian — hu

**Name:** TalkRoll: Teleprompter

**Subtitle:** Szöveg a kamera közelében

**Keywords:** `prompter,voice,mirror,video,notch,overlay,notes,súgógép,hang,görgetés,jegyzet,beszéd,tükör`

**Counts:** 22 / 25 / 90 chars; 98 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 40/5, `prompter` 23/5, `forgatókönyv` 5/5.

## Indonesian — id

**Name:** TalkRoll: Teleprompter

**Subtitle:** Teks berjalan dekat kamera

**Keywords:** `prompter,auto,scroll,video,notch,overlay,suara,mengambang,gulir,otomatis,naskah,cermin,skrip`

**Counts:** 22 / 26 / 92 chars; 92 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 68/9, `prompter` 54/9, `naskah video` 5/5.

## Italian — it

**Name:** TalkRoll: Teleprompter

**Subtitle:** Copione accanto alla webcam

**Keywords:** `prompter,gobbo,discorso,voce,notch,overlay,testo,scorrimento,fluttuanti,video,prove,specchio`

**Counts:** 22 / 27 / 92 chars; 92 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 55/9, `prompter` 29/9, `gobbo` 27/7, `testo scorrevole` 7/7.

## Japanese — ja

**Name:** TalkRoll：カンペ

**Subtitle:** カメラのそばで台本を読む

**Keywords:** `プロンプター,自動スクロール,音声認識,notch,overlay,原稿表示,発表練習`

**Counts:** 12 / 12 / 43 chars; 93 keyword bytes.

**Measured Mac demand to interpret:** `カンペ` 40/7, `プロンプター` 38/7, `テレプロンプター` 28/7.

**Space:** 7 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Korean — ko

**Name:** TalkRoll: 프롬프터

**Subtitle:** 카메라 옆에서 대본 읽기

**Keywords:** `텔레프롬프터,스크립트,자동스크롤,음성인식,notch,overlay,발표연습,원고읽기`

**Counts:** 14 / 13 / 46 chars; 100 keyword bytes.

**Measured Mac demand to interpret:** `프롬프터` 39/9, `텔레프롬프터` 36/11, `대본` 32/7.

**Space:** 0 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Malay — ms

**Name:** TalkRoll: Teleprompter

**Subtitle:** Skrip di sisi kamera

**Keywords:** `prompter,script,reader,auto,notch,overlay,scroll,video,teks,suara,terapung,tatal,ucapan,cermin`

**Counts:** 22 / 20 / 94 chars; 94 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 69/7, `prompter` 51/7, `baca skrip` 5/5.

## Dutch — nl-NL

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lees je script bij de camera

**Keywords:** `prompter,stem,tekst,scrollen,notch,overlay,zwevende,video,toespraak,oefenen,spiegel,tempo`

**Counts:** 22 / 28 / 89 chars; 89 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 52/7, `prompter` 26/7, `script lezen` 5/5.

**Space:** 11 bytes unused. Broad `presentatie` results led to slide tools and `autocue` risks a competitor-brand term; the one-byte gap is left open.

## Norwegian — no

**Name:** TalkRoll: Teleprompter

**Subtitle:** Les manus ved kameraet

**Keywords:** `video,voice,mirror,notes,notch,overlay,stemme,tekst,rulling,notater,tale,øving,speil`

**Counts:** 22 / 22 / 84 chars; 85 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 42/5, `floating teleprompter` 5/5.

**Space:** 15 bytes unused. `automatisk` led to generic scrollers and a caption app in the Mac combination, so the unused bytes are preferable.

## Polish — pl

**Name:** TalkRoll: Teleprompter

**Subtitle:** Czytaj tekst przy kamerze

**Keywords:** `prompter,kamera,skrypt,voice,notch,overlay,głos,wideo,przewijanie,pływające,przemówienie`

**Counts:** 22 / 25 / 88 chars; 92 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 53/5, `prompter` 43/5, `voice prompter` 27/9.

**Space:** 8 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Portuguese (Brazil) — pt-BR

**Name:** TalkRoll: Teleprompter

**Subtitle:** Roteiro ao lado da câmera

**Keywords:** `texto,flutuante,notch,overlay,auto,scroll,voice,prompter,voz,vídeo,rolagem,discurso,ensaio`

**Counts:** 22 / 25 / 90 chars; 91 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 68/9, `voice prompter` 21/11.

## Portuguese (Portugal) — pt-PT

**Name:** TalkRoll: Teleprompter

**Subtitle:** Teleponto junto à câmara

**Keywords:** `prompter,texto,flutuante,notch,overlay,vídeo,deslocamento,discurso,ensaio,espelho,guião,voz`

**Counts:** 22 / 24 / 91 chars; 93 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 53/5, `teleponto` 42/5, `prompter` 26/5.

## Romanian — ro

**Name:** TalkRoll: Teleprompter

**Subtitle:** Scenariu lângă cameră

**Keywords:** `prompter,script,video,notch,overlay,voice,mirror,reader,plutitoare,voce,derulare,discurs,ritm`

**Counts:** 22 / 21 / 93 chars; 93 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 45/5, `prompter` 36/5, `scenariu` 5/5.

## Russian — ru

**Name:** TalkRoll: Суфлёр

**Subtitle:** Читайте текст у камеры

**Keywords:** `телесуфлер,голос,камера,видео,сценарий,notch,прокрутка`

**Counts:** 16 / 22 / 54 chars; 97 keyword bytes.

**Measured Mac demand to interpret:** `суфлер` 53/7, `телесуфлер` 24/7.

**Space:** 3 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Slovak — sk

**Name:** TalkRoll: Teleprompter

**Subtitle:** Scenár pri kamere

**Keywords:** `video,voice,mirror,skript,notch,overlay,hlas,posúvanie,plávajúce,prejav,zrkadlo,nácvik`

**Counts:** 22 / 17 / 86 chars; 90 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 36/5.

**Space:** 10 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Swedish — sv

**Name:** TalkRoll: Teleprompter

**Subtitle:** Läs manus nära kameran

**Keywords:** `prompter,script,video,voice,notch,overlay,mirror,flytande,röst,rullning,tal,övning,tempo`

**Counts:** 22 / 22 / 88 chars; 90 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 48/5, `prompter` 26/5, `läsa manus` 5/5.

**Space:** 10 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Thai — th

**Name:** TalkRoll: Teleprompter

**Subtitle:** อ่านสคริปต์ใกล้กล้อง

**Keywords:** `prompter,เลื่อนอัตโนมัติ,บทพูด,เสียง,notch`

**Counts:** 22 / 20 / 42 chars; 92 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 69/7, `prompter` 33/11, `อ่านสคริปต์` 30/5.

**Space:** 8 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Turkish — tr

**Name:** TalkRoll: Teleprompter

**Subtitle:** Metni kameranın yanında oku

**Keywords:** `prompter,ses,notch,overlay,senaryo,kaydırma,prova,ayna,yüzen,otomatik,sunum,video`

**Counts:** 22 / 27 / 81 chars; 83 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 52/13, `prompter` 46/7, `video metni` 5/5.

**Space:** 17 bytes unused. `hız` led to VPN/speed utilities and a caption app in the Mac combination; the remaining tested words added little relevant intent.

## Ukrainian — uk

**Name:** TalkRoll: Телесуфлер

**Subtitle:** Читайте текст біля камери

**Keywords:** `відео,сценарій,нотатки,прокрутка,notch,overlay,голос,суфлер`

**Counts:** 20 / 25 / 59 chars; 99 keyword bytes.

**Measured Mac demand to interpret:** `телесуфлер` 58/7, `суфлер` 58/7, `промова` 50/5.

**Space:** 1 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Vietnamese — vi

**Name:** TalkRoll: Teleprompter

**Subtitle:** Máy nhắc chữ bên máy quay

**Keywords:** `prompter,auto,scroll,giọng nói,notch,overlay,cuộn,nổi,luyện tập,gương,văn bản`

**Counts:** 22 / 25 / 77 chars; 93 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 62/7, `máy nhắc chữ` 41/5, `nhắc chữ` 34/9, `prompter` 27/11.

**Space:** 7 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Chinese (Simplified) — zh-Hans

**Name:** TalkRoll：悬浮提词器

**Subtitle:** 口播时轻松读稿

**Keywords:** `视频提词器,演讲稿,自动滚动,镜像模式,overlay,语音跟随,脚本分段,摄像头`

**Counts:** 14 / 7 / 41 chars; 95 keyword bytes.

**Measured Mac demand to interpret:** `提词器` 65/13, `悬浮提词器` 45/9, `口播提词器` 37/9, `视频提词器` 23/9.

**Space:** 5 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Chinese (Traditional) — zh-Hant

**Name:** TalkRoll：提詞器

**Subtitle:** 鏡頭旁輕鬆讀稿

**Keywords:** `讀稿機,影片腳本,自動捲動,notch,overlay,演講稿,鏡像模式,懸浮提詞,語音提詞`

**Counts:** 12 / 7 / 46 chars; 98 keyword bytes.

**Measured Mac demand to interpret:** `提詞器` 47/5, `讀稿機` 27/7.

**Space:** 2 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Arabic (Saudi Arabia) — ar-SA

**Name:** TalkRoll: Teleprompter

**Subtitle:** اقرأ النص قرب الكاميرا

**Keywords:** `تلقين,voice,script,نصوص,video,notch,overlay,عائمة,تمرير,تدريب,مرآة`

**Counts:** 22 / 22 / 66 chars; 94 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 40/5, `تلقين` 23/15, `تلقين نصوص` 5/5.

**Space:** 6 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Hebrew — he

**Name:** TalkRoll: Teleprompter

**Subtitle:** טלפרומפטר ליד המצלמה

**Keywords:** `video,prompter,script,טקסט,notch,overlay,גלילה,צפות,נאום,תסריט,מראה`

**Counts:** 22 / 20 / 67 chars; 93 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 53/5, `טלפרומפטר` 35/5, `prompter` 30/7.

**Space:** 7 bytes unused. Remaining tested terms had weaker or unrelated intent, repeated a visible word, or exceeded the UTF-8 limit.

## Slovenian — sl-SI

**Name:** TalkRoll: Teleprompter

**Subtitle:** Berite besedilo ob kameri

**Keywords:** `voice,video,script,reader,notch,overlay,floating,scroll,mirror,practice,webcam,meeting,cues`

**Counts:** 22 / 25 / 91 chars; 91 keyword bytes.

**Measured Mac demand to interpret:** `teleprompter` 33/5, `floating teleprompter` 5/5.
