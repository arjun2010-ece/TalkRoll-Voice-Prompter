# TalkRoll App Store listings

Prepared for iPhone/iPad: 38 researched locales plus en-US. These are copyable name, subtitle and keyword fields; descriptions and promotional text are outside this file's scope.

Sources: [English keyword research and US intent audit](en-keywords.md), [localized research including deeper passes](localized-keywords.md), [locale-by-locale intent audit](locale-intent-audit.md), [selected branding](branding.md), [app brief](../../App-Brief.md), and the Flutter [mode labels](../../app/lib/core/settings/labels.dart) and [reading flow](../../app/lib/features/read/read_screen.dart). Most seed scores are from the 2026-11-07/08 research snapshots; the en-US singular/plural check and all locale search-result intent checks were run in Astro on 2026-11-09.

## Demand-first selection with native supplements

The latest user instruction supersedes the former preference for translating every category term. **Relevant measured demand leads, regardless of language.** The selected English name remains TalkRoll: Voice Prompter. Other names keep TalkRoll and use a strong relevant measured category query; natural native names remain where the research supports them. Subtitles use a strong supporting query or natural copy communicating the reading/recording benefit. In weak native-search markets, English phrases and native copy can coexist intentionally.

Keywords first cover useful measured phrases not already represented by the name/subtitle, then add directly relevant native words for additional plausible coverage. Popularity >20 and difficulty <60 is the preferred opportunity filter. Values of 6–20 can still supply secondary coverage; a value of 5 is treated as a low-data/low-demand signal, not proof of zero demand or a confirmed number of occasional searches. A score of 5 alone does not establish any traffic or ranking probability.

Relevant translations and distinct spellings can intentionally share a field (for example script/स्क्रिप्ट); they address different query strings. They are not exact-word duplication. Native inflections and compounds are preserved for readability; Apple may stem or combine words differently, and neither cross-field combinations nor language variants guarantee a match. The tables below cite scores for exact researched queries, not newly composed metadata strings.

Broad words such as notes, voice, text, mirror and recording are only used in explicit teleprompter/script context. Their popularity scores may reflect unrelated search intent, so they are secondary context vocabulary rather than evidence of an equally large teleprompter audience. Known slide-making, voice-memo, AI-prompt, caption-generation and competitor-name traps remain excluded. [Autocue is an existing brand](https://www.autocue.com/) and is not included. Floating-note terms describe the in-app camera overlay on iOS, not a system-wide overlay.

The es-MX listing remains the explicitly requested complementary English slot: its name equals the en-US subtitle. Its keywords have zero exact-word overlap with all en-US fields. Related word families can overlap semantically. This is a testable strategy, not a promise of cross-locale keyword pooling. It displays English to customers receiving that localization.

## Limits and validation

Apple's [product-page guide](https://developer.apple.com/app-store/product-page/) specifies 30-character names/subtitles and a 100-character keyword field; its [App Store Connect reference](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information) specifies 100 bytes for keywords. This file conservatively fits **both 100 Unicode code points and 100 UTF-8 bytes**. Commas, spaces and punctuation are included in counts. Native supplements use remaining byte space; no unrelated words are added to fill the budget.

All 39 sets pass name/subtitle/keyword limits, comma formatting, exact duplicate-entry and word checks, cross-field exact-word checks, connector/query-word checks in both English and the native language, and the approved brand check. Visible fields have no pricing/promotional claims. Native readability, semantic overlap, product relevance and unsupported claims were reviewed editorially. The review was not a native-speaker panel or an App Store Connect submission. CJK/Thai segmentation and morphological matching cannot be proved by automated checks.

| Locale | Name chars /30 | Subtitle chars /30 | Keyword chars /100 | Keyword UTF-8 bytes /100 | Result |
|---|---:|---:|---:|---:|---|
| en-US | 24 | 27 | 96 | 96 | Pass |
| en-GB | 24 | 27 | 96 | 96 | Pass |
| en-CA | 24 | 27 | 96 | 96 | Pass |
| en-AU | 24 | 27 | 97 | 97 | Pass |
| es-MX | 27 | 21 | 88 | 88 | Pass |
| ca | 22 | 29 | 87 | 88 | Pass |
| cs | 22 | 25 | 92 | 96 | Pass |
| da | 22 | 26 | 96 | 98 | Pass |
| de-DE | 22 | 28 | 96 | 97 | Pass |
| el | 22 | 28 | 71 | 100 | Pass |
| es-ES | 22 | 19 | 97 | 99 | Pass |
| fi | 22 | 29 | 93 | 95 | Pass |
| fr-FR | 25 | 24 | 94 | 98 | Pass |
| hi | 24 | 22 | 48 | 98 | Pass |
| hr | 22 | 25 | 95 | 97 | Pass |
| hu | 22 | 29 | 89 | 99 | Pass |
| id | 22 | 26 | 100 | 100 | Pass |
| it | 22 | 27 | 100 | 100 | Pass |
| ja | 12 | 12 | 37 | 95 | Pass |
| ko | 14 | 13 | 39 | 95 | Pass |
| ms | 22 | 25 | 100 | 100 | Pass |
| nl-NL | 22 | 25 | 98 | 98 | Pass |
| no | 22 | 24 | 95 | 96 | Pass |
| pl | 22 | 28 | 95 | 99 | Pass |
| pt-BR | 22 | 29 | 97 | 99 | Pass |
| pt-PT | 22 | 29 | 94 | 97 | Pass |
| ro | 22 | 30 | 96 | 99 | Pass |
| ru | 16 | 28 | 52 | 98 | Pass |
| sk | 22 | 28 | 93 | 97 | Pass |
| sv | 22 | 25 | 95 | 97 | Pass |
| th | 22 | 26 | 41 | 99 | Pass |
| tr | 22 | 26 | 95 | 100 | Pass |
| uk | 20 | 30 | 52 | 98 | Pass |
| vi | 22 | 27 | 72 | 90 | Pass |
| zh-Hans | 14 | 13 | 41 | 99 | Pass |
| zh-Hant | 12 | 12 | 39 | 95 | Pass |
| ar-SA | 22 | 21 | 64 | 95 | Pass |
| he | 22 | 24 | 62 | 96 | Pass |
| sl-SI | 22 | 29 | 98 | 99 | Pass |

## Evidence and provenance

The demand anchors under each listing are a selected set of relevant measured queries guiding the combined metadata. Their scores belong to the exact full phrases; distributing content words across fields does not transfer the full phrase's score to a single word. Connector words are omitted from the keyword field. Broader phrases and native inflections are qualified in the locale notes.

**R** = exact researched term or a content word from a researched phrase in that storefront, including low-data phrases. **P** = directly relevant product/category vocabulary or a native close variant, without a measured score implied: speech following, script reading/editing, recording, scrolling, floating notes, rehearsal, mirror mode, sections or reading speed. This accounts for every keyword. R does not mean high popularity; see the demand anchors and original research for exact scores.


## English (US) — en-US

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Script & Video Teleprompter

**Keywords:**

`rehearser,auto,scroll,reader,floating,notes,follow,camera,mirror,recording,practice,vlog,filming`

**Counts:** name 24/30; subtitle 27/30; keywords 96/100 characters, 96/100 bytes.

**Demand anchors — US iPhone storefront (popularity/difficulty):** voice prompter (39/11); video teleprompter (28/49); script (45/48); script reader (36/45); script rehearser (33/15); auto scroll (33/17); floating notes (25/13); voice scroll (19/5). Lower-data but relevant combinations: voice follow (5/9); teleprompter camera (5/43); teleprompter mirror (5/51); teleprompter recording (5/19); teleprompter practice (5/19); vlog teleprompter (5/15); teleprompter filming (5/17). Astro's 2026-11-09 comparison found scripts (6/42), video teleprompter scripts (5/11), and teleprompter scripts (5/11).

**Selection:** The exact user-selected name is retained. Script is the stronger measured singular query and appears visibly beside the intact Video Teleprompter phrase. The subtitle describes script handling and video prompting, though it is a compact category statement rather than a sentence. The singular is not repeated in keywords. A US Astro search-result audit found script reader, script rehearser, floating notes and voice scroll relevant enough to keep their component words. The lower-data camera, mirror, recording, practice, vlog and filming terms also returned teleprompter apps when paired with teleprompter. Writing mainly returned screenwriting apps; speech, narration, record and sections were also too broad or misleading as standalone intents, so they were removed. Apple's [search guidance](https://developer.apple.com/app-store/search/) treats singular/plural pairs as duplicate keyword coverage, but does not promise identical ranking for every query.

**Keyword provenance:** R: rehearser, auto, scroll, reader, floating, notes, follow, camera, mirror, recording, practice, vlog, filming; P: none. Each R term is a component of a measured query listed above; the popularity/difficulty value belongs to that full query, not the component word.

**Space use:** 96 characters use 96 bytes, within the preferred 95–100-character range.

## English (UK) — en-GB

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Script & Video Teleprompter

**Keywords:**

`rehearser,auto,scroll,reader,floating,notes,follow,camera,mirror,recording,practice,vlog,filming`

**Counts:** name 24/30; subtitle 27/30; keywords 96/100 characters, 96/100 bytes.

**Demand anchors — GB iPhone storefront (popularity/difficulty):** voice prompter (31/5); teleprompter (56/45); script rehearser (33/7); auto scroll (28/5); script reader (22/21); video teleprompter (22/19); floating notes (9/13). Low-data combinations checked in Astro: voice scroll (5/17); teleprompter camera (5/36); teleprompter mirror (5/39); teleprompter recording (5/11); voice follow (5/23); teleprompter practice (5/19); vlog teleprompter (5/13); teleprompter filming (5/13).

**Selection:** The user-selected brand and the measured video teleprompter phrase stay visible. Script replaces the low-value Your while supporting script reader and script rehearser combinations. Astro's UK search results support those clusters, though script rehearser is an adjacent acting-rehearsal audience. Auto scroll is dominated by auto-clickers and remains a secondary feature term. Floating notes is mixed but includes teleprompter apps at ranks 2 and 3. Camera, mirror, recording, practice, vlog and filming returned teleprompter apps when combined with teleprompter. Standalone speech, narration and sections returned mostly unrelated apps; record was replaced by the better-contextualized recording term. Search-result positions do not prove the cause of a competitor's rank.

**Keyword provenance:** R: rehearser, auto, scroll, reader, floating, notes, follow, camera, mirror, recording, practice, vlog, filming; P: none. R scores belong to full measured queries, not these isolated component words.

**Space use:** 96 characters use 96 bytes, within the preferred 95–100-character range.

## English (Canada) — en-CA

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Script & Video Teleprompter

**Keywords:**

`rehearser,auto,scroll,reader,floating,notes,follow,camera,mirror,recording,practice,vlog,filming`

**Counts:** name 24/30; subtitle 27/30; keywords 96/100 characters, 96/100 bytes.

**Demand anchors — CA iPhone storefront (popularity/difficulty):** voice prompter (27/7); teleprompter (57/44); script reader (27/17); auto scroll (24/11); script rehearser (23/11); floating notes (9/15). Low-data combinations checked in Astro: voice scroll (5/15); teleprompter camera (5/17); teleprompter mirror (5/19); teleprompter recording (5/9); voice follow (5/40); teleprompter practice (5/13); vlog teleprompter (5/9); teleprompter filming (5/11).

**Selection:** Script replaces the low-value Your in the subtitle and supports the relevant script reader result cluster. Script rehearser reaches the adjacent actor rehearsal audience. Auto scroll is mostly auto-clickers and browser scrollers, so auto/scroll remain secondary feature vocabulary. Floating notes is mixed but includes teleprompter results at ranks 1 and 8. Camera, mirror, recording, practice, vlog and filming returned teleprompter apps throughout their top 10 when paired with teleprompter. Voice follow returned teleprompters at ranks 1, 6 and 8. Standalone speech, narration and sections were off-target; record was replaced by recording. Search-result positions do not prove the cause of a competitor's rank.

**Keyword provenance:** R: rehearser, auto, scroll, reader, floating, notes, follow, camera, mirror, recording, practice, vlog, filming; P: none. R scores belong to full measured queries, not these isolated component words.

**Space use:** 96 characters use 96 bytes, within the preferred 95–100-character range.

## English (Australia) — en-AU

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Script & Video Teleprompter

**Keywords:**

`rehearser,reader,auto,scroll,floating,notes,camera,mirror,recording,cues,pace,vlog,filming,follow`

**Counts:** name 24/30; subtitle 27/30; keywords 97/100 characters, 97/100 bytes.

**Demand anchors — AU iPhone storefront (popularity/difficulty):** voice prompter (27/7); teleprompter (58/41); auto scroll (25/7); script reader (24/13); script rehearser (24/7); floating notes (6/13). Low-data combinations checked in Astro: voice scroll (5/17); teleprompter camera (5/23); teleprompter mirror (5/17); teleprompter recording (5/9); voice follow (5/41); vlog teleprompter (5/9); teleprompter filming (5/9); script cues (5/7); teleprompter pace (5/11).

**Selection:** Script moves into the subtitle, replacing Your; this gives the otherwise mixed Australian script query explicit teleprompter context. Script reader returned teleprompters at ranks 1 and 2, while script rehearser reached an adjacent actor-rehearsal audience. Auto scroll was dominated by auto-clickers and remains secondary feature vocabulary. Floating notes returned teleprompters at ranks 1 and 2. Camera, mirror, recording, vlog and filming returned teleprompter apps throughout their top 10 when paired with teleprompter. Script cues and teleprompter pace also returned teleprompter or adjacent script apps, so those original terms stay despite unrelated standalone results. Speech and narration were off-target; record was replaced by recording. Voice follow was mixed but included directly comparable voice-following prompters. Search-result positions do not prove the cause of a competitor's rank.

**Keyword provenance:** R: rehearser, reader, auto, scroll, floating, notes, camera, mirror, recording, cues, pace, vlog, filming, follow; P: none. R scores belong to full measured queries, not these isolated component words.

**Space use:** 97 characters use 97 bytes, within the preferred 95–100-character range.

## Spanish (Mexico), English indexing slot — es-MX

**Name:** Script & Video Teleprompter

**Subtitle:** Read with Auto Scroll

**Keywords:**

`presenter,cues,retake,pace,rehearsal,creator,speaker,presentation,interview,course,lines`

**Counts:** name 27/30; subtitle 21/30; keywords 88/100 characters, 88/100 bytes.

**Demand anchors — MX iPhone storefront (popularity/difficulty):** teleprompter (63/45); video teleprompter (5/38); auto scroll (5/7); teleprompter presenter (5/5); script cues (5/17); script retake (5/5); teleprompter pace (5/5); script rehearsal (5/7); teleprompter creator (5/21); teleprompter speaker (5/17); teleprompter presentation (5/11); teleprompter interview (5/5); teleprompter course (5/5); memorize lines (5/9). For the intentional English indexing experiment, the corresponding US research measured script (45/48), video teleprompter (28/49), and auto scroll (33/17); US scores are not Mexican demand estimates.

**Selection:** Intentional English slot: the name exactly equals the en-US subtitle; the keyword field has zero exact-word overlap with all en-US fields. The Mexico results for standalone memorize, public, speaking, takes, playback and editing were mainly unrelated or represented dedicated features TalkRoll does not claim. Those words were removed. Script cues, script retake and teleprompter presenter/pace returned relevant prompters; rehearsal, creator, speaker, presentation, interview and course are directly relevant audiences or uses, but every checked MX phrase scored only 5. Lines is a secondary script-rehearsal term, not a memorization-feature claim. The title/subtitle and English field are an indexing experiment, not proof of cross-locale pooling or Mexican search demand. No Spanish fallback is added because this specific strategy was explicitly requested.

**Keyword provenance:** R: presenter, cues, retake, pace, rehearsal, creator, speaker, presentation, interview, course, lines; P: none. Each R term comes from a measured MX phrase above; 5 is a weak/low-data signal.

**Space use:** 88 characters use 88 bytes. The field stays below 90 rather than reintroducing unrelated terms or overlaps with en-US.

## Catalan — ca

**Name:** TalkRoll: Teleprompter

**Subtitle:** Llegeix el guió mentre graves

**Keywords:**

`prompter,script,video,voice,notes,flotants,veu,càmera,mirall,assaig,lector,discurs,text`

**Counts:** name 22/30; subtitle 29/30; keywords 87/100 characters, 88/100 bytes.

**Demand anchors — ES iPhone storefront (popularity/difficulty):** teleprompter (59/46); prompter (42/41); teleprompter for video (42/43); script (36/21); notes flotants (5/5); lector de guions (5/7); teleprompter veu (5/7); teleprompter mirall (5/7); teleprompter assaig (5/5); teleprompter càmera (5/17); teleprompter discurs (5/11); teleprompter text (5/42).

**Selection:** Spain's strong teleprompter/prompter and script searches retain priority. In Astro, prompter's top results were teleprompter apps, and script also returned teleprompters at ranks 1, 4 and 8. Video stays to support the relevant teleprompter-for-video query, while video recorder's top results were screen recorders, so recorder was removed. Notes flotants, teleprompter veu, teleprompter mirall, teleprompter assaig, teleprompter càmera, teleprompter discurs and lector de guions returned teleprompter or directly adjacent script apps; their native content words provide secondary coverage. Text stays only as a low-data category combination with teleprompter. Pantalla mainly returned wallpapers, and text en pantalla returned LED signs; desplaçament automàtic mainly returned web/PDF scrollers. Those words were removed. A score of 5 does not prove search demand or a likely rank.

**Keyword provenance:** R: prompter, script, video, voice, notes, flotants, veu, càmera, mirall, assaig, lector, discurs, text; P: none. Scores belong to the full measured queries above, not the isolated words.

**Space use:** 87 characters use 88 bytes. The remaining space is left unused instead of restoring screen-recorder, wallpaper or auto-scroller terms.

## Czech — cs

**Name:** TalkRoll: Teleprompter

**Subtitle:** Čtěte scénář při natáčení

**Keywords:**

`video,script,reader,voice,mirror,text,poznámky,plovoucí,posouvání,hlas,zrcadlo,projev,kamera`

**Counts:** name 22/30; subtitle 25/30; keywords 92/100 characters, 96/100 bytes.

**Demand anchors — CZ iPhone storefront (popularity/difficulty):** teleprompter (45/9); teleprompter for video (27/13); script (28/39); voice (36/38); reader (31/39). Lower-data intent checks: script reader (5/15); voice teleprompter (5/9); floating notes (5/11); plovoucí poznámky (5/5); teleprompter hlas (5/13); teleprompter kamera (5/23); teleprompter mirror (5/9); teleprompter zrcadlo (5/5); teleprompter text (5/9); teleprompter projev (5/5); posouvání textu (5/5).

**Selection:** The category loanword leads. Video alone returned editors but teleprompter for video returned teleprompters throughout the top eight. Script alone mixed developer apps and teleprompters, while script reader returned teleprompters at ranks 1, 2 and 6; reader replaces sekce, whose standalone results were shopping and whose teleprompter combination returned no results. Voice alone returned voice changers but voice teleprompter was on-target. Czech floating-note, scrolling, speech, camera and mirror terms stay as low-data secondary combinations: their standalone results were broad, but the checked category phrases returned teleprompters or adjacent script apps. Text editor and běžící text were rejected because they returned code editors and LED signs. Prezentace remains excluded because its checked results favored slide software. A popularity score of 5 does not establish demand.

**Keyword provenance:** R: video, script, reader, voice, mirror, text, poznámky, plovoucí, posouvání, hlas, zrcadlo, projev, kamera; P: none. Scores above belong to full measured queries, not individual components.

**Space use:** 92 characters use 96 bytes, within the preferred 90–100-character range.

## Danish — da

**Name:** TalkRoll: Teleprompter

**Subtitle:** Læs dit manus, optag video

**Keywords:**

`voice,mirror,stemme,tekst,rulning,noter,flydende,tale,spejl,øvelse,kamera,tempo,manuskript,læser`

**Counts:** name 22/30; subtitle 26/30; keywords 96/100 characters, 98/100 bytes.

**Demand anchors — DK iPhone storefront (popularity/difficulty):** teleprompter (37/11); teleprompter for video (31/15); voice (35/43); mirror (32/17). Low-data phrase checks: voice teleprompter (5/11); teleprompter med stemme (5/5); flydende noter (5/5); teleprompter spejl (5/5); teleprompter mirror (5/11); teleprompter tekst (5/7); teleprompter rulning (5/5); teleprompter tale (5/5); teleprompter øvelse (5/5); teleprompter kamera (5/15); teleprompter tempo (5/5); manuskript læser (5/5).

**Selection:** The category loanword leads; the natural Danish subtitle describes reading while filming. Standalone voice, mirror and text were broad, but voice teleprompter and teleprompter mirror returned category apps; text was removed because its tracked scrolling-text result was dominated by LED signs. Native stemme, tekst, rulning, tale, spejl, øvelse and kamera remain low-data feature words after their teleprompter combinations returned prompters. Noter stays with newly added flydende: flydende noter returned several prompters amid floating-window apps. New manuskript and læser support the on-target manuscript-reader query; the visible short form manus may or may not be combined with manuskript by Apple. Hastighed alone returned speedometers, while teleprompter tempo had prompter/reading-speed results; tempo stays and hastighed is removed. Sektioner had unrelated results and no teleprompter results, so it was removed. Each popularity-5 phrase is weak evidence of demand.

**Keyword provenance:** R: voice, mirror, stemme, tekst, rulning, noter, flydende, tale, spejl, øvelse, kamera, tempo, manuskript, læser; P: none. Scores belong to the full measured queries above, not isolated components.

**Space use:** 96 characters use 98 bytes, within the preferred 95–100-character range and byte limit.

## German — de-DE

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lies dein Skript beim Filmen

**Keywords:**

`prompter,sprechen,auto,scroll,stimme,notizen,schwebende,video,spiegel,üben,tempo,aufnahme,kamera`

**Counts:** name 22/30; subtitle 28/30; keywords 96/100 characters, 97/100 bytes.

**Demand anchors — DE iPhone storefront (popularity/difficulty):** teleprompter (53/45); prompter (32/42); sprechen (28/47); auto scroll (23/19); video teleprompter (9/43). Lower-data checks: teleprompter sprechen (5/5); teleprompter stimme (5/5); schwebende notizen (5/5); teleprompter spiegel (5/11); teleprompter üben (5/5); teleprompter tempo (5/5); teleprompter aufnahme (5/9); teleprompter auto scroll (5/7); teleprompter kamera (5/13).

**Selection:** Prompter alone returned teleprompter apps, so the measured category variant stays. Rede scored 39/56 but its standalone results began with Reddit and unrelated apps; despite an on-target teleprompter rede phrase at popularity 5, it was removed rather than treating the broad score as teleprompter demand. Sprechen alone returned language-learning/speech apps, but teleprompter sprechen was on-target, so it stays as secondary speech intent. Auto scroll (23/19) was dominated by clickers, but teleprompter auto scroll returned category apps; the pair stays as secondary feature vocabulary. Text alone was fonts/docs and text scroller was LED signs, so text was replaced by kamera, whose category combination returned teleprompter cameras. Notizen stays with the correctly inflected schwebende for the low-data floating-notes phrase. Stimme, spiegel, üben, tempo and aufnahme were broad alone but their teleprompter combinations returned prompters and describe actual features. Scores of 5 are weak evidence of demand.

**Keyword provenance:** R: prompter, sprechen, auto, scroll, stimme, notizen, schwebende, video, spiegel, üben, tempo, aufnahme, kamera; P: none. Scores belong to the full measured queries above, not isolated components.

**Space use:** 96 characters use 97 bytes, within the preferred 95–100-character range.

## Greek — el

**Name:** TalkRoll: Teleprompter

**Subtitle:** Το κείμενο ακολουθεί τη φωνή

**Keywords:**

`video,voice,mirror,notes,reader,script,σενάριο,κύλιση,σημειώσεις,κάμερα`

**Counts:** name 22/30; subtitle 28/30; keywords 71/100 characters, 100/100 bytes.

**Demand anchors — GR iPhone storefront (popularity/difficulty):** teleprompter (40/7); teleprompter for video (28/11); video recorder (28/21); voice (36/19).

**Selection:** The measured English category term leads in Greek search. The Greek subtitle describes voice following. `video` has an on-target teleprompter combination, while `video recorder` and standalone `recorder` returned screen recorders, so `recorder` was removed. `script reader` returned teleprompters in the top results; both words were added. `σενάριο` alone returned several teleprompters, and `κάμερα` had an on-target Greek category combination. `κύλιση` and `σημειώσεις` remain directly relevant, lower-data feature terms; their standalone results were broader. `ομιλία` alone was dominated by speech synthesis/transcription, so it was removed. `voice`, `mirror`, and `notes` are broad alone, but their category/floating-note combinations returned prompters. None of these checks proves ranking causality.

**Keyword provenance:** R: video, voice, mirror, notes, reader, script, σενάριο, κύλιση, σημειώσεις, κάμερα; P: none.

**Space use:** 71 characters use all 100 bytes; Greek script uses two bytes per character.

## Spanish (Spain) — es-ES

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lee mientras grabas

**Keywords:**

`prompter,texto,pantalla,voz,guion,vídeo,desplazamiento,ensayo,discurso,espejo,ritmo,cámara,lector`

**Counts:** name 22/30; subtitle 19/30; keywords 97/100 characters, 99/100 bytes.

**Demand anchors — ES iPhone storefront (popularity/difficulty):** teleprompter (59/46); prompter (42/41); texto en pantalla (38/42); leer mientras grabas (32/42); grabar con texto (36/44); voz (34/48).

**Selection:** Strong Spanish text/screen, speaking and recording phrases lead. `prompter` alone returned category apps and `guion` returned several. `notas flotantes` returned general notes and widgets rather than teleprompters, so those two words were removed despite the relevant floating-script feature. `lector de guiones` returned teleprompters in nine of the top ten results, and `teleprompter cámara` returned them throughout the top ten; `lector` and `cámara` take that space. `ensayo de guion`, `teleprompter discurso`, `teleprompter espejo`, and `teleprompter ritmo` supported the remaining lower-data words. `texto desplazable` was dominated by LED signs, so `desplazamiento` is retained only as a secondary scrolling-feature word, not a validated high-demand query.

**Keyword provenance:** R: prompter, texto, pantalla, voz, guion, vídeo, desplazamiento, ensayo, discurso, espejo, ritmo, cámara, lector; P: none.

**Space use:** 97 characters use 99 bytes, within the preferred 95–100-character range.

## Finnish — fi

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lue käsikirjoitus kuvatessasi

**Keywords:**

`video,prompter,voice,mirror,notes,ääni,teksti,vieritys,muistiinpanot,puhe,peilaus,harjoittelu`

**Counts:** name 22/30; subtitle 29/30; keywords 93/100 characters, 95/100 bytes.

**Demand anchors — FI iPhone storefront (popularity/difficulty):** teleprompter (42/7); prompter (28/7); teleprompter for video (28/11); voice (35/21).

**Selection:** The measured teleprompter spelling replaces the low-data teleprompteri title. Finnish script-reading copy and native feature words remain.

**Keyword provenance:** R: video, prompter, voice, mirror, notes, teksti, vieritys, muistiinpanot, puhe, harjoittelu; P: ääni, peilaus.

**Space use:** 93 characters use 95 bytes. Remaining space is left for relevance/word boundaries rather than filler.

## French — fr-FR

**Name:** TalkRoll: Prompteur vidéo

**Subtitle:** Le texte suit votre voix

**Keywords:**

`teleprompteur,caméra,auto,scroll,discours,défilement,notes,flottantes,script,miroir,répétition`

**Counts:** name 25/30; subtitle 24/30; keywords 94/100 characters, 98/100 bytes.

**Demand anchors — FR iPhone storefront (popularity/difficulty):** prompteur (48/23); teleprompteur (31/34); lecteur de texte (32/41); auto scroll (27/15); discours (26/51).

**Selection:** Strong native `prompteur` leads. The unaccented `teleprompteur` search returned category apps throughout the top results. `lecteur de texte` (32/41) returned text-to-speech and PDF readers, so `lecteur` was removed despite its score. `caméra` replaces it after `prompteur caméra` (5/11) returned teleprompters and recording apps. `auto scroll` (27/15) was mostly auto-clickers, so its terms are secondary; `prompteur auto scroll` (5/9) returned prompters. `discours`, `défilement`, `miroir`, and `répétition` alone were broad or misleading, but their `prompteur` combinations (all popularity 5) returned on-target apps. `notes flottantes` (5/7) returned several teleprompters among floating note apps. `script vidéo` also returned teleprompters; the remaining `script` is relevant.

**Keyword provenance:** R: teleprompteur, caméra, auto, scroll, discours, défilement, notes, flottantes, script, miroir, répétition; P: none.

**Space use:** 94 characters use 98 bytes, near the UTF-8 byte limit; no unrelated padding was added.

## Hindi — hi

**Name:** TalkRoll: Voice Prompter

**Subtitle:** Teleprompter for Video

**Keywords:**

`script,reader,scroll,टेलीप्रॉम्प्टर,आवाज,स्क्रॉल`

**Counts:** name 24/30; subtitle 22/30; keywords 48/100 characters, 98/100 bytes.

**Demand anchors — IN iPhone storefront (popularity/difficulty):** voice prompter (26/9); teleprompter (57/42); teleprompter for video (49/39); script reader (21/19); scroll (52/47). Supplemental Hindi queries: टेलीप्रॉम्प्टर (5/17); आवाज से स्क्रॉल (5/5).

**Selection:** The selected English name and measured India category phrase retain priority. Script reader and scrolling vocabulary lead the keyword field. टेलीप्रॉम्प्टर, आवाज and स्क्रॉल add specific Hindi category and voice-scrolling coverage instead of broader speech/speed words. The connector से is omitted. The score for आवाज से स्क्रॉल belongs to the full researched phrase, not its individual words; no particular search volume or cross-field match is guaranteed.

**Keyword provenance:** R: script, reader, scroll, टेलीप्रॉम्प्टर, आवाज, स्क्रॉल; P: none.

**Space use:** 48 characters use 98 bytes. The two remaining bytes cannot accommodate another keyword and its comma; the specific Hindi terms take priority over shorter, broader alternatives.

## Croatian — hr

**Name:** TalkRoll: Teleprompter

**Subtitle:** Čitajte tekst dok snimate

**Keywords:**

`voice,notes,video,glas,scenarij,pomicanje,bilješke,plutajuće,govor,zrcalo,kamera,brzina,skripta`

**Counts:** name 22/30; subtitle 25/30; keywords 95/100 characters, 97/100 bytes.

**Demand anchors — HR iPhone storefront (popularity/difficulty):** teleprompter (37/5); voice (30/19).

**Selection:** The category term leads. `voice prompter` and `teleprompter for video` returned prompters. `plutajuće bilješke` returned a teleprompter as its sole result, while `scenarij za video` returned mostly prompters. `govor`, `zrcalo`, `pomicanje`, and `kamera` were broad alone but their teleprompter combinations returned category apps. `vježbanje` alone returned fitness apps and `teleprompter vježbanje` returned no apps, so it was removed. `video skripta` returned several teleprompters; `skripta` replaces it. `brzina` is kept only as low-data speed control vocabulary; its category combination returned two prompters and a PDF scroller.

**Keyword provenance:** R: voice, notes, video, scenarij, pomicanje, bilješke, plutajuće, govor, zrcalo, kamera, brzina, skripta; P: glas.

**Space use:** 95 characters use 97 bytes, within the preferred 95–100-character range.

## Hungarian — hu

**Name:** TalkRoll: Teleprompter

**Subtitle:** Olvasd a szöveget videózáskor

**Keywords:**

`prompter,voice,mirror,video,notes,súgógép,hang,görgetés,jegyzet,beszéd,tükör,forgatókönyv`

**Counts:** name 22/30; subtitle 29/30; keywords 89/100 characters, 99/100 bytes.

**Demand anchors — HU iPhone storefront (popularity/difficulty):** teleprompter (40/9); prompter (23/9); teleprompter for video (25/15); voice (38/21); mirror (35/15).

**Selection:** The stronger teleprompter spelling remains in the title. `prompter` and native `súgógép` alone returned teleprompter apps. English `text` alone returned fonts and `scrolling text` LED signs, so it was replaced with `video`, supported by `teleprompter for video` (25/15). The Hungarian `forgatókönyv` alone returned several prompters. `hang`, `görgetés`, `beszéd`, and `tükör` were broad alone but their category combinations returned mostly teleprompters; `lebegő jegyzetek` returned Cuebox Teleprompter as its sole result, supporting native notes intent. English voice and mirror remain measured category/feature vocabulary, not standalone targeting.

**Keyword provenance:** R: prompter, voice, mirror, video, notes, súgógép, hang, görgetés, jegyzet, beszéd, tükör, forgatókönyv; P: none.

**Space use:** 89 characters use 99 bytes; Hungarian accents use the remaining byte budget.

## Indonesian — id

**Name:** TalkRoll: Teleprompter

**Subtitle:** Teks berjalan saat merekam

**Keywords:**

`prompter,auto,scroll,video,naskah,suara,catatan,mengambang,gulir,otomatis,pidato,cermin,skrip,kamera`

**Counts:** name 22/30; subtitle 26/30; keywords 100/100 characters, 100/100 bytes.

**Demand anchors — ID iPhone storefront (popularity/difficulty):** teleprompter (68/42); prompter (54/42); teks berjalan (45/21); auto scroll (30/9); perekam video (24/42).

**Selection:** The subtitle uses the strong local phrase `teks berjalan` naturally. `prompter` and `teleprompter video` returned category apps; `naskah video` returned prompters throughout the top eight. `perekam video` (24/42) returned screen recorders, so `perekam` was removed despite its score. `skrip` and `kamera` replace it after `teleprompter skrip` and `teleprompter kamera` (both popularity 5) returned mostly prompters. `auto scroll` (30/9) and `gulir otomatis` were dominated by clickers/web scrollers, so those words are secondary feature coverage. `catatan mengambang` returned one prompter among three results; `teleprompter suara`, `teleprompter pidato`, and `teleprompter cermin` returned category apps, supporting those native terms.

**Keyword provenance:** R: prompter, auto, scroll, video, naskah, suara, catatan, mengambang, gulir, otomatis, pidato, cermin, skrip, kamera; P: none.

**Space use:** 100 characters use 100 bytes, fully allocated to relevant words.

## Italian — it

**Name:** TalkRoll: Teleprompter

**Subtitle:** Leggi il copione e registra

**Keywords:**

`prompter,gobbo,discorso,voce,testo,scorrimento,note,fluttuanti,video,prove,specchio,fotocamera,ritmo`

**Counts:** name 22/30; subtitle 27/30; keywords 100/100 characters, 100/100 bytes.

**Demand anchors — IT iPhone storefront (popularity/difficulty):** teleprompter (55/41); prompter (29/21); gobbo (27/21); discorso (24/23).

**Selection:** `prompter` and `gobbo` alone returned several prompters. `discorso` (24/23) alone returned Discord and transcription apps, but `teleprompter discorso` (5/7) returned prompters throughout the top ten; it remains a secondary speaking-intent word, not a claimed high-volume teleprompter query. `note fluttuanti` (5/5) returned only teleprompters, supporting the in-app floating-script feature. `prove copione` returned actor rehearsal and several prompters; `teleprompter scorrimento`, `teleprompter testo`, `teleprompter specchio`, and `teleprompter ritmo` returned category apps. `sezioni` alone returned unrelated anatomy/electrical apps and `teleprompter sezioni` returned no apps, so it was replaced with `fotocamera`, whose teleprompter combination returned mostly prompters.

**Keyword provenance:** R: prompter, gobbo, discorso, voce, testo, scorrimento, note, fluttuanti, video, prove, specchio, fotocamera, ritmo; P: none.

**Space use:** 100 characters use 100 bytes, fully allocated to relevant words.

## Japanese — ja

**Name:** TalkRoll：カンペ

**Subtitle:** 声で進む台本、動画も撮影

**Keywords:**

`プロンプター,自動,スクロール,音声認識,スピーチ,原稿,練習,メモ,録画`

**Counts:** name 12/30; subtitle 12/30; keywords 37/100 characters, 95/100 bytes.

**Demand anchors — JP iPhone storefront (popularity/difficulty):** カンペ (40/23); プロンプター (38/13); 台本 (34/42); 動画撮影 (43/48); 自動スクロール (33/11); 音声認識 (32/38); スピーチ (27/19).

**Selection:** Strong native category and feature queries lead. No English translation is forced into this market; native feature words fill the remaining budget.

**Keyword provenance:** R: プロンプター, 自動, スクロール, 音声認識, スピーチ, 原稿, メモ; P: 練習, 録画.

**Space use:** 37 characters use 95 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Korean — ko

**Name:** TalkRoll: 프롬프터

**Subtitle:** 말에 맞춰 대본을 넘겨요

**Keywords:**

`스크립트,자동,스크롤,동영상,촬영,발표,음성,인식,메모,연습,원고,거울`

**Counts:** name 14/30; subtitle 13/30; keywords 39/100 characters, 95/100 bytes.

**Demand anchors — KR iPhone storefront (popularity/difficulty):** 프롬프터 (39/11); 스크립트 (37/49); 대본 (32/7); 자동 스크롤 (35/13); 동영상 촬영 (33/45); 발표 (26/23).

**Selection:** Strong native category/script/scrolling terms lead. AI-prompt and caption terms remain excluded despite their scores.

**Keyword provenance:** R: 스크립트, 자동, 스크롤, 동영상, 촬영, 발표, 음성, 인식, 메모; P: 연습, 원고, 거울.

**Space use:** 39 characters use 95 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Malay — ms

**Name:** TalkRoll: Teleprompter

**Subtitle:** Baca skrip sambil merakam

**Keywords:**

`prompter,script,reader,auto,scroll,video,rakaman,teks,suara,nota,terapung,tatal,ucapan,cermin,kamera`

**Counts:** name 22/30; subtitle 25/30; keywords 100/100 characters, 100/100 bytes.

**Demand anchors — MY iPhone storefront (popularity/difficulty):** teleprompter (69/23); prompter (51/21); script reader (44/21); auto scroll (31/7); video recorder (39/45).

**Selection:** The category loanword leads. `script reader` (44/21) returned prompters throughout the top eight. `video recorder` (39/45) returned mostly screen recorders, so `recorder` was replaced with native `rakaman` after `teleprompter rakaman` returned category apps. `laju` alone returned speedometers and `teleprompter laju` returned no apps, so `kamera` replaces it; `teleprompter kamera` returned several prompters. `auto scroll` (31/7) was dominated by clickers/web tools and remains secondary feature vocabulary. `nota terapung` returned two prompters among three results; `teleprompter teks`, `teleprompter ucapan`, `teleprompter cermin`, and `teleprompter tatal` returned category apps. English `script` and visible Malay `skrip` are separate observed/native forms, not an assumption about stemming.

**Keyword provenance:** R: prompter, script, reader, auto, scroll, video, rakaman, teks, suara, nota, terapung, tatal, ucapan, cermin, kamera; P: none.

**Space use:** 100 characters use 100 bytes, fully allocated to relevant words.

## Dutch — nl-NL

**Name:** TalkRoll: Teleprompter

**Subtitle:** Lees je script en neem op

**Keywords:**

`prompter,stem,tekst,scrollen,notities,zwevende,video,toespraak,oefenen,spiegel,camera,tempo,opname`

**Counts:** name 22/30; subtitle 25/30; keywords 98/100 characters, 98/100 bytes.

**Demand anchors — NL iPhone storefront (popularity/difficulty):** teleprompter (52/17); prompter (26/15).

**Selection:** `prompter` alone returned category apps throughout the top eight. `delen` alone returned finance, car sharing and file-transfer apps; `teleprompter delen` returned one unrelated app, so it was removed. `snelheid` alone returned speedometers; `teleprompter tempo` (5/5) returned several prompters and reading-speed tools, so `tempo` replaced it. `zwevend` was changed to grammatical `zwevende` after `zwevende notities` returned multiple prompters. `opname` was added after `teleprompter opname` returned prompters throughout the top ten. `stem`, `tekst`, `scrollen`, `toespraak`, `oefenen`, `spiegel`, and `camera` were broad alone but their category combinations returned teleprompters. The last group has popularity 5 and is secondary feature coverage.

**Keyword provenance:** R: prompter, stem, tekst, scrollen, notities, zwevende, video, toespraak, oefenen, spiegel, camera, tempo, opname; P: none.

**Space use:** 98 characters use 98 bytes, within the preferred 95–100-character range.

## Norwegian — no

**Name:** TalkRoll: Teleprompter

**Subtitle:** Les manus mens du filmer

**Keywords:**

`video,voice,mirror,notes,stemme,tekst,rulling,notater,tale,øving,speil,kamera,opptak,manuskript`

**Counts:** name 22/30; subtitle 24/30; keywords 95/100 characters, 96/100 bytes.

**Demand anchors — NO iPhone storefront (popularity/difficulty):** teleprompter (42/9); manus (30/44); teleprompter for video (28/7); voice (34/15); mirror (30/9).

**Selection:** `teleprompter for video` (28/7) returned category apps throughout the top eight; `voice prompter` (5/15) did too. English `text` alone returned fonts and `text editor` developer tools, while native `teleprompter tekst` returned prompters; the English duplicate was removed. `avsnitt` alone returned writing/grammar tools and `teleprompter avsnitt` returned no apps, so it was removed. `manuskript` replaced it after `teleprompter manuskript` (5/5) returned several prompters and adjacent script tools. Native `tale`, `rulling`, `opptak`, `speil`, `øving`, and `kamera` were broad alone but their teleprompter combinations returned category apps. `notes` and `notater` remain lower-data floating-script vocabulary; the checked `flytende notater` query was mostly note/float tools and should not be treated as strong demand.

**Keyword provenance:** R: video, voice, mirror, notes, stemme, tekst, rulling, notater, tale, øving, speil, kamera, opptak, manuskript; P: none.

**Space use:** 95 characters use 96 bytes, within the preferred 95–100-character range.

## Polish — pl

**Name:** TalkRoll: Teleprompter

**Subtitle:** Czytaj scenariusz i nagrywaj

**Keywords:**

`prompter,kamera,skrypt,voice,głos,wideo,przewijanie,notatki,pływające,przemówienie,lustro,tempo`

**Counts:** name 22/30; subtitle 28/30; keywords 95/100 characters, 99/100 bytes.

**Demand anchors — PL iPhone storefront (popularity/difficulty):** teleprompter (53/15); prompter (43/15); czytnik tekstu (29/17); voice prompter (27/11).

**Selection:** `prompter` alone and `voice prompter` (27/11) returned category apps throughout the top eight. `czytnik tekstu` (29/17) returned text-to-speech and ebook readers throughout the top ten, so both components were removed despite the score. `kamera` and `skrypt` replace them after `teleprompter kamera` (5/17) and `teleprompter skrypt` (5/11) returned mostly prompters. `pływające notatki` returned one prompter among two results, supporting low-data floating-note coverage. `przemówienie`, `przewijanie`, `lustro`, and `tempo` alone were broad, but their teleprompter combinations returned category apps; these are secondary feature words.

**Keyword provenance:** R: prompter, kamera, skrypt, voice, głos, wideo, przewijanie, notatki, pływające, przemówienie, lustro, tempo; P: none.

**Space use:** 95 characters use 99 bytes, within the preferred 95–100-character range.

## Portuguese (Brazil) — pt-BR

**Name:** TalkRoll: Teleprompter

**Subtitle:** Leia o roteiro enquanto grava

**Keywords:**

`câmera,texto,notas,flutuante,auto,scroll,voice,prompter,voz,vídeo,rolagem,discurso,ensaio,espelho`

**Counts:** name 22/30; subtitle 29/30; keywords 97/100 characters, 99/100 bytes.

**Demand anchors — BR iPhone storefront (popularity/difficulty):** teleprompter (68/56); gravar vídeo (28/48); auto scroll (21/13); voice prompter (21/15). Off-intent measured phrase: leitor de texto (41/43). Low-data relevant phrase: texto flutuante (5/9). The earlier 25/21 estimate for notas flutuantes was not present in the current temporary-app keyword snapshot, so it is not used as a current demand anchor.

**Selection:** `leitor de texto` (41/43) returned text-to-speech and ebook readers throughout the top eight, so `leitor` was removed despite the score. `teleprompter câmera` (5/39) returned category apps throughout the top ten; `câmera` takes that space. `texto flutuante` returned prompters in eight of the top ten; singular `flutuante` replaces plural `flutuantes` to form this better-supported phrase. `notas flutuantes` returned two prompters amid mostly sticky-note apps, so `notas` remains only secondary floating-note coverage. `auto scroll` (21/13) returned mostly clickers and `voice prompter` (21/15) returned teleprompters; both English pairs are kept with that distinction. `teleprompter rolagem`, `teleprompter discurso`, `teleprompter ensaio`, `teleprompter espelho`, and `teleprompter voz` (all popularity 5) returned category apps, supporting those native terms.

**Keyword provenance:** R: câmera, texto, notas, flutuante, auto, scroll, voice, prompter, voz, vídeo, rolagem, discurso, ensaio, espelho; P: none.

**Space use:** 97 characters use 99 bytes, within the preferred 95–100-character range.

## Portuguese (Portugal) — pt-PT

**Name:** TalkRoll: Teleprompter

**Subtitle:** Teleponto que segue a sua voz

**Keywords:**

`prompter,texto,notas,flutuante,vídeo,guião,deslocamento,discurso,ensaio,espelho,câmara,rolagem`

**Counts:** name 22/30; subtitle 29/30; keywords 94/100 characters, 97/100 bytes.

**Demand anchors — PT iPhone storefront (popularity/difficulty):** teleprompter (53/17); teleponto (42/19); prompter (26/17).

**Selection:** The stronger `teleprompter` term stays in the name and native `teleponto` (42/19) in the natural subtitle. `prompter` and `guião` alone returned several category apps. `notas flutuantes` mostly returned notepads; `texto flutuante` (5/5) returned mostly prompters, so singular `flutuante` replaces plural `flutuantes`. `secções` alone returned one unrelated app and `teleponto secções` returned none, so it was replaced with `rolagem`, whose teleponto combination returned prompters. `deslocamento`, `discurso`, `ensaio`, `espelho`, and `câmara` were broad alone but their `teleponto` combinations (all popularity 5) returned category apps. `notas` remains secondary floating-script vocabulary.

**Keyword provenance:** R: prompter, texto, notas, flutuante, vídeo, guião, deslocamento, discurso, ensaio, espelho, câmara, rolagem; P: none.

**Space use:** 94 characters use 97 bytes; the remaining bytes do not fit another validated useful term.

## Romanian — ro

**Name:** TalkRoll: Teleprompter

**Subtitle:** Citește scenariul când filmezi

**Keywords:**

`prompter,script,video,cameră,voice,mirror,reader,notițe,plutitoare,voce,derulare,discurs,oglindă`

**Counts:** name 22/30; subtitle 30/30; keywords 96/100 characters, 99/100 bytes.

**Demand anchors — RO iPhone storefront (popularity/difficulty):** teleprompter (45/13); prompter (36/13); teleprompter for video (31/17); script (29/19); video recorder (27/43).

**Selection:** `prompter` alone returned teleprompters throughout the top eight and `teleprompter for video` (31/17) did likewise. `video recorder` (27/43) returned screen recorders, so `recorder` was removed. `text` alone returned fonts and `text editor` (31/39) editors, so it was removed. `cameră` and `reader` replace them after `teleprompter cameră` (5/13) and `script reader` (5/11) returned category apps. `notițe plutitoare` returned only Float Cam, so those native terms are speculative floating-script feature coverage. `teleprompter voce`, `teleprompter derulare`, `teleprompter discurs`, and `teleprompter oglindă` (all popularity 5) returned prompters, supporting the other native terms.

**Keyword provenance:** R: prompter, script, video, cameră, voice, mirror, reader, notițe, plutitoare, voce, derulare, discurs, oglindă; P: none.

**Space use:** 96 characters use 99 bytes, within the preferred 95–100-character range.

## Russian — ru

**Name:** TalkRoll: Суфлёр

**Subtitle:** Текст следует за вашей речью

**Keywords:**

`голос,камера,видео,запись,сценарий,прокрутка,заметки`

**Counts:** name 16/30; subtitle 28/30; keywords 52/100 characters, 98/100 bytes.

**Demand anchors — RU iPhone storefront (popularity/difficulty):** суфлер (53/21); запись видео (27/48). Off-intent measured phrase: бегущая строка (43/15), whose search results were dominated by LED banners.

**Selection:** `Суфлёр` is the standard ё spelling of measured `суфлер`; no new score for the spelling variant is implied. `бегущая строка` (43/15) returned mainly LED banners, so both components were removed despite high popularity. `голос` and `камера` replace them after their `телесуфлёр` combinations (5/7 and 5/11) returned prompters in most top positions. `темп` alone returned metronomes and its category combination had only four results; it was replaced by `заметки`, whose `плавающие заметки` search returned a teleprompter #1 among five results. `видео`, `запись`, `сценарий`, and `прокрутка` had broad standalone results but on-target `телесуфлёр` combinations. Scores of 5 are low-data signals.

**Keyword provenance:** R: голос, камера, видео, запись, сценарий, прокрутка, заметки; P: none.

**Space use:** 52 characters use 98 bytes; Cyrillic uses two bytes per character, leaving no room for another useful term.

## Slovak — sk

**Name:** TalkRoll: Teleprompter

**Subtitle:** Čítajte scenár pri nahrávaní

**Keywords:**

`video,voice,mirror,skript,notes,hlas,posúvanie,poznámky,plávajúce,prejav,zrkadlo,kamera,tempo`

**Counts:** name 22/30; subtitle 28/30; keywords 93/100 characters, 97/100 bytes.

**Demand anchors — SK iPhone storefront (popularity/difficulty):** teleprompter (36/7); teleprompter for video (21/9); voice (31/15); mirror (31/11).

**Selection:** `teleprompter for video` (21/9) and `voice prompter` (5/5) returned category apps throughout the top eight. English `text` alone returned fonts and `text na obrazovke` returned drawing/LED apps, so it was replaced with native `skript`, whose teleprompter combination (5/5) returned category apps throughout the top ten. `sekcie` alone returned unrelated apps and its teleprompter combination was mixed camera/caption apps; `tempo` replaces it after `teleprompter tempo` returned prompters and reading-speed apps. `plávajúce poznámky` returned Cuebox Teleprompter #1 among two results. `hlas`, `posúvanie`, `prejav`, `zrkadlo`, and `kamera` were broad alone but their category combinations (all popularity 5) returned prompters.

**Keyword provenance:** R: video, voice, mirror, skript, notes, hlas, posúvanie, poznámky, plávajúce, prejav, zrkadlo, kamera, tempo; P: none.

**Space use:** 93 characters use 97 bytes; remaining space is left for relevance rather than filler.

## Swedish — sv

**Name:** TalkRoll: Teleprompter

**Subtitle:** Läs manus medan du filmar

**Keywords:**

`prompter,script,video,voice,mirror,flytande,röst,rullning,anteckningar,tal,övning,spegel,kamera`

**Counts:** name 22/30; subtitle 25/30; keywords 95/100 characters, 97/100 bytes.

**Demand anchors — SE iPhone storefront (popularity/difficulty):** teleprompter (48/11); prompter (26/11); manus (29/50); teleprompter for video (33/11); script (26/19).

**Selection:** `prompter` and `script reader` returned teleprompter apps near the top, and `teleprompter for video` (33/11) returned category apps throughout the top eight. English `text` alone returned fonts and `text editor` (27/39) developer/writing tools, so it was removed. English `notes` alone returned notepads; `flytande anteckningar` returned two prompters among four results and better fits native floating-script intent, so `flytande` replaced `text,notes` as a pair. `röst`, `rullning`, `tal`, `övning`, `spegel`, and `kamera` were broad alone but their teleprompter combinations (all popularity 5) returned prompters and adjacent speaking/reading tools.

**Keyword provenance:** R: prompter, script, video, voice, mirror, flytande, röst, rullning, anteckningar, tal, övning, spegel, kamera; P: none.

**Space use:** 95 characters use 97 bytes, within the preferred 95–100-character range.

## Thai — th

**Name:** TalkRoll: Teleprompter

**Subtitle:** อ่านสคริปต์ขณะบันทึกวิดีโอ

**Keywords:**

`prompter,เลื่อนอัตโนมัติ,โน้ตลอย,เสียง,บท`

**Counts:** name 22/30; subtitle 26/30; keywords 41/100 characters, 99/100 bytes.

**Demand anchors — TH iPhone storefront (popularity/difficulty):** teleprompter (69/21); prompter (33/17); อ่านสคริปต์ (30/5); บันทึกวิดีโอ (27/36).

**Selection:** Measured teleprompter replaces the low-data native category title. The subtitle covers the strong Thai script-reading and recording phrases; Thai scrolling/floating-note vocabulary remains in keywords.

**Keyword provenance:** R: prompter, โน้ตลอย, เสียง, บท; P: เลื่อนอัตโนมัติ.

**Space use:** 41 characters use 99 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Turkish — tr

**Name:** TalkRoll: Teleprompter

**Subtitle:** Metin okuyarak video çekin

**Keywords:**

`prompter,okuyucu,konuşma,ses,senaryo,kaydırma,notlar,prova,ayna,kayıt,kamera,hız,yüzen,otomatik`

**Counts:** name 22/30; subtitle 26/30; keywords 95/100 characters, 100/100 bytes.

**Demand anchors — TR iPhone storefront (popularity/difficulty):** teleprompter (52/23); prompter (46/21); metin okuyucu (34/13); konuşma (29/52).

**Selection:** Strong native metin okuyucu is represented by visible metin plus backend okuyucu. Prompter and konuşma precede lower-data Turkish feature words. Removed bölüm and akış because their category combinations returned too few relevant results; yüzen and otomatik express supported floating and automatic scrolling features.

**Keyword provenance:** R: prompter, okuyucu, konuşma, kaydırma, notlar, yüzen, otomatik; P: ses, senaryo, prova, ayna, kayıt, kamera, hız.

**Space use:** 95 characters use all 100 bytes.

## Ukrainian — uk

**Name:** TalkRoll: Телесуфлер

**Subtitle:** Читайте текст, готуйте промову

**Keywords:**

`відео,сценарій,нотатки,прокрутка,голос,дзеркало,темп`

**Counts:** name 20/30; subtitle 30/30; keywords 52/100 characters, 98/100 bytes.

**Demand anchors — UA iPhone storefront (popularity/difficulty):** телесуфлер (58/31); промова (50/36).

**Selection:** Strong native телесуфлер remains in the name. The subtitle uses natural inflections for text reading and speech preparation; no identical score is assigned to those inflected strings.

**Keyword provenance:** R: відео, сценарій, нотатки; P: прокрутка, голос, дзеркало, темп.

**Space use:** 52 characters use 98 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Vietnamese — vi

**Name:** TalkRoll: Teleprompter

**Subtitle:** Máy nhắc chữ khi quay video

**Keywords:**

`prompter,auto,scroll,giọng nói,cuộn,ghi chú,nổi,luyện tập,gương,kịch bản`

**Counts:** name 22/30; subtitle 27/30; keywords 72/100 characters, 90/100 bytes.

**Demand anchors — VN iPhone storefront (popularity/difficulty):** teleprompter (62/42); máy nhắc chữ (41/21); nhắc chữ (34/30); quay video (40/56); auto scroll (24/11); chạy chữ (40/40).

**Selection:** Measured teleprompter remains in the name. Strong native máy nhắc chữ and quay video appear naturally in the subtitle. The measured auto scroll pair stays as secondary vocabulary because its standalone search is dominated by auto-clickers; the category-qualified query is relevant. Replaced running-text and duplicate automatic vocabulary with native kịch bản, whose prompter combination returned category apps throughout the top ten.

**Keyword provenance:** R: prompter, auto, scroll, giọng nói, cuộn, ghi chú, nổi, kịch bản; P: luyện tập, gương.

**Space use:** 72 characters use 90 bytes. Ten bytes remain rather than adding a low-fit pacing term or repeating automatic scrolling.

## Chinese (Simplified) — zh-Hans

**Name:** TalkRoll：悬浮提词器

**Subtitle:** 台词跟着声音走，轻松录视频

**Keywords:**

`口播,演讲稿,自动滚动,镜像,读稿,台本,录制,笔记,脚本,拍摄,分段,提示,速度`

**Counts:** name 14/30; subtitle 13/30; keywords 41/100 characters, 99/100 bytes.

**Demand anchors — CN iPhone storefront (popularity/difficulty):** 提词器 (65/55); 悬浮提词器 (45/51); 口播 (47/50); 演讲稿 (26/46).

**Selection:** Strong native 提词器 is present inside 悬浮提词器; 口播 and 演讲稿 lead the backend. Replaced weak standalone practice, import, and font intent with verified script-reading and recording words.

**Keyword provenance:** R: 口播, 演讲稿, 自动滚动, 读稿, 台本, 录制; P: 镜像, 笔记, 脚本, 拍摄, 分段, 提示, 速度.

**Space use:** 41 characters use 99 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Chinese (Traditional) — zh-Hant

**Name:** TalkRoll：提詞器

**Subtitle:** 台詞跟著聲音走，輕鬆錄影

**Keywords:**

`讀稿機,影片,懸浮,自動捲動,演講稿,鏡像,口播,語速,筆記,腳本,拍攝,分段`

**Counts:** name 12/30; subtitle 12/30; keywords 39/100 characters, 95/100 bytes.

**Demand anchors — TW iPhone storefront (popularity/difficulty):** 提詞器 (47/19); 錄影 (53/49); 讀稿機 (27/21).

**Selection:** Strong native 提詞器 remains in the name, with 錄影 in the subtitle and 讀稿機 first in the backend. Replaced low-fit practice and import terms with category-checked creator speech and voice pace terms.

**Keyword provenance:** R: 讀稿機, 影片, 懸浮, 自動捲動, 演講稿, 筆記, 口播, 語速; P: 鏡像, 腳本, 拍攝, 分段.

**Space use:** 39 characters use 95 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Arabic (Saudi Arabia) — ar-SA

**Name:** TalkRoll: Teleprompter

**Subtitle:** الملقن الذي يتبع صوتك

**Keywords:**

`script,video,voice,تلقين,نصوص,ملاحظات,عائمة,تمرير,recorder,تدريب`

**Counts:** name 22/30; subtitle 21/30; keywords 64/100 characters, 95/100 bytes.

**Demand anchors — SA iPhone storefront (popularity/difficulty):** teleprompter (40/11); teleprompter for video (27/13); الملقن (24/11); خطابة (59/48); video recorder (31/37); script (32/39).

**Selection:** Measured teleprompter leads; the strong native الملقن term moves into a natural Arabic subtitle. Removed high-scoring خطابة and خطاب after Saudi search results showed marriage apps. Native نصوص and عائمة add verified prompter-script and floating-note intent; English video and script stay for their relevant category combinations.

**Keyword provenance:** R: script, video, recorder, voice, تلقين, ملاحظات, تمرير, نصوص, عائمة; P: تدريب.

**Space use:** 64 characters use 95 bytes; meaningful native terms and the conservative byte cap limit further additions.

## Hebrew — he

**Name:** TalkRoll: Teleprompter

**Subtitle:** טלפרומפטר שעוקב אחר הקול

**Keywords:**

`video,prompter,script,פרומטר,גלילה,הערות,צפות,נאום,תסריט,צילום`

**Counts:** name 22/30; subtitle 24/30; keywords 62/100 characters, 96/100 bytes.

**Demand anchors — IL iPhone storefront (popularity/difficulty):** teleprompter (53/17); טלפרומפטר (35/17); teleprompter for video (36/15); פרומטר (29/19); script (27/13).

**Selection:** The stronger teleprompter query stays in the name while measured טלפרומפטר remains in a natural Hebrew subtitle. English video/script combinations and alternate Hebrew spelling פרומטר precede low-data native terms. Removed standalone recorder, rehearsal and pace words after they led to unrelated apps or no prompters; native script and filming combinations fit better.

**Keyword provenance:** R: video, prompter, script, פרומטר, גלילה, הערות, צפות, נאום, תסריט, צילום.

**Space use:** 62 characters use 96 bytes; no weaker word was added to use the final four bytes.

## Slovenian — sl-SI

**Name:** TalkRoll: Teleprompter

**Subtitle:** Berite besedilo med snemanjem

**Keywords:**

`voice,video,script,reader,floating,notes,scroll,mirror,recording,practice,kamera,zapiski,plavajoči`

**Counts:** name 22/30; subtitle 29/30; keywords 98/100 characters, 99/100 bytes.

**Demand anchors — SI iPhone storefront (popularity/difficulty):** teleprompter (33/5); voice (22/9).

**Selection:** The category loanword leads and the visible subtitle stays natural Slovenian. The Slovenian storefront returned no prompters for most native keyword searches, even with teleprompter added. English category combinations returned prompters, so the keyword field uses them for discoverability while retaining native camera and floating-note words for directly supported features.

**Keyword provenance:** R: voice, video, script, reader, floating, notes, scroll, mirror, recording, practice, kamera, zapiski, plavajoči.

**Space use:** 98 characters use 99 bytes, within the preferred 95–100-character range.
