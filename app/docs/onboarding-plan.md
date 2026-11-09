# Onboarding plan (first-run experience and permissions)

Status: **implemented 2026-10-28** in `app/lib/features/onboarding/`. Checked on the Android emulator (API 37) and on
macOS (debug build); not yet run on iOS, iPadOS or Windows. Sections 1 to 10 are the research and decisions; section 11
is the implementation plan that was followed. The mock-up screens were approved before building.

Platforms: iOS, iPadOS, Android (mobile), macOS (desktop). Windows is covered briefly at the end.

## 1. What the reference apps actually do

I read the three reverse-engineered/reference codebases next to this repo. **The Android app does** (§1.1): a first-run sequence plus a voice-setup
wizard.

| Reference | Platform | First-run behaviour | Permission handling |
|---|---|---|---|
| VoicePrompter web (`../VoicePrompter`, GPL-3.0) | Browser / PWA, also the base for its iOS/iPad/Mac pages | Seeds a **demo script** that explains the app by being the script (`src/main.ts`, "Seed demo script for first-time users"). No tour, no sign-up. | Lazy. Camera/mic prompt appears on the first record or on focusing a device picker (`requestPermissionsOnSelectFocus`). Denial → a bare `alert(...)`. |
| VoicePrompter Android APK (`../vp-apk`, decompiled, R8-obfuscated) | Android | Demo script → "How did you hear about…" survey → voice-setup wizard → paywall. See §1.1. | Mic is requested inside the wizard's test step, not on a separate permission screen. |

### 1.1 Android app first-run, as recovered from the decompile

Where: `~/projects/vp-apk/work/jadx-out/sources/` (path from `voice-tracking-handoff.md`). Package
`app.voiceprompter` holds the readable bits (`setup/SetupPage.java`, `VoiceMode.java`, `CheckOutcome.java`,
`VoiceChoice.java`, `SetupProgress.java`); the Compose UI is obfuscated in `defpackage/` (wizard screen `pt3.java`,
setup state `i25.java`, first-run gating in `uy2.java`, survey `tx0.java`/`ni2.java`, demo script `yb5.java`/`pv.java`).
Confidence: **[read]** for everything below except the exact on-screen order, which is **[inferred]** from the
`SharedPreferences` flags and Compose control flow.

First-run sequence:

1. **Demo script** is loaded ("[Read this demo script to try VoicePrompter] Welcome to VoicePrompter…"). Flag
   `welcomeSeen` marks it done.
2. **Survey** "How did you hear about VoicePrompter? Choose one to continue." Single choice, required (Continue is
   disabled until one is picked): Play Store, Google Search, YouTube, Word of mouth, TikTok, Instagram, LinkedIn,
   Reddit, X / Twitter, AI assistant, Other. Stored as `discoverySource`, sent as an `onboardingSurveyCompleted`
   event, flag `hasShownOnboardingSurvey`.
3. **Voice-setup wizard** (`SetupPage`: INTRO → TEST → REVIEW → HELP → PIP_OFFER → SUMMARY). Same wizard is reachable
   later from Settings (analytics `entry` = `onboarding` vs `settings`). It is **mode-first**: the user is asked how
   they will use voice (`VoiceMode`: Teleprompter, Video recording, Picture-in-picture) and each chosen mode is
   tested separately. Title copy: "Find your scrolling style" / "Your voice setup".
   - TEST page: "Read aloud in Teleprompter mode. The text follows your voice." with a **Try voice scrolling** button, a
     live "Your voice was detected." / "No words detected yet." indicator, then **"Did the text follow your voice?"
     → "Yes, it worked"**. Video mode records a short test clip, plays it back ("Play the clip and check that you can
     hear yourself."), and deletes it afterwards.
   - Microphone: "Allow microphone access to try Voice or Sound. Constant works without it." The mic prompt comes from
     pressing the test button; "Constant" (their steady-scroll mode) needs no permission.
   - HELP page when the test fails: "Let's try another option": switch to built-in speech vs "Use a downloaded speech
     model… It stays on your phone", or an Android accessibility service ("It does not read your screen") that keeps
     listening while another camera app records. If voice is unavailable: "You can still use Constant scrolling."
   - PIP_OFFER: "Use your own camera app? Keep your script over your camera app while you record."
   - SUMMARY: per-mode result list (`CheckOutcome`: WORKED / UNAVAILABLE / NOT_NEEDED).
4. **Paywall** is queued right after the first completed setup (`postVoiceSetupPaywallPending`).

What this tells us:

- Their onboarding is really a **speech-reliability checker**. It exists because Android voice recognition is
  unreliable across phones. The idea we should keep is "test it live, and offer a fallback if it fails", not their
  screens.
- Mode-first, per-mode test, honest "didn't work → alternatives → keep using steady scroll" is the same shape we
  proposed in §4. Good validation, and it means we must differ visibly in design, copy and structure (§7).
- They do **not** ask for camera in onboarding; it is requested at the first camera use.
- They gate onboarding behind a **required marketing survey** and then a paywall. Both are things we should
  think twice about for App Review friendliness and first-impression (see open question 4 and 8).
- Android manifest: RECORD_AUDIO, CAMERA, POST_NOTIFICATIONS, foreground-service permissions, billing. Requesting
  notifications is tied to their foreground service; we have no such service, so we do not need it.

Take-aways worth keeping:

- **Ask at the moment of need.** Every reference does this; it is also what Apple prefers.
- **The demo script doubles as the tour** (VoicePrompter). We already have one (`StudioNotifier.welcome`, shown
  as "Welcome to TalkRoll" in `script_list.dart`).
- **Denial must degrade gracefully** (NotchPrompter turns the feature off and explains).
- Their weaknesses are our opportunity: a bare `alert()` on denial, no explanation of *why* before the system
  prompt, no recovery path, no preview of what the prompter will look like.

## 2. What we have today

- Lazy permission requests via `requestPermission()` (`lib/services/permissions/permissions.dart`), used on the
  Read screen (mic) and Record screen (camera + mic). Denial → `showMicrophoneDenied` dialog, or an inline state
  on the camera cards.
- Purpose strings already exist: iOS camera, mic, speech, photo-library-add; macOS mic, speech. Android manifest
  has CAMERA, RECORD_AUDIO, READ_MEDIA_AUDIO.
- A welcome sample script and an empty-state in the Studio. Crash reporting is opt-in in Settings (off by default).
- `plan/desktop-ux-plan.md` §3.7 already sketches a macOS first run (sample script, Position tip, first-Start
  toast, permission priming on mode select). This plan builds on it rather than replacing it.
- No first-launch flag, no onboarding screens. Speech-recognition permission on Apple platforms is requested
  by the engine, not by an explicit pre-prompt.

## 3. Principles

1. **Show value before asking for anything.** The user sees a prompter scrolling their kind of script within
   seconds, with zero permissions granted. Normal mode needs none.
2. **Never block on permissions.** Every permission screen has an equally visible, honest "Not now" path. The app
   is fully usable in Normal mode without any of them.
3. **Ask in context, with a reason.** A short "why" screen (our own UI) precedes the system prompt, and the
   prompt itself appears only after the user taps a button that says what will happen.
4. **Ask for the minimum, in the order of usefulness.** Mic + speech together (Voice mode) is the headline
   feature; camera only matters for Record. Camera is *not* asked in onboarding unless the user chooses Record.
5. **Recoverable.** A denied permission can always be fixed later: the feature explains what is off and offers
   "Open Settings".
6. **Short.** Target: first-run ≤ 4 screens on mobile, ≤ 3 on macOS, skippable at every step, never shown again
   (can be replayed from Settings → Help).

## 4. Proposed flow

### 4.1 Mobile (iOS, iPadOS, Android)

| # | Screen | Purpose | Permission |
|---|---|---|---|
| 1 | **Welcome** — one line of promise, an animated prompter preview with highlight following a sample line, "Get started" | Value first | none |
| 2 | **Choose how you read** — three cards: *Voice* (follows you), *Normal* (steady scroll), *Audio* (follows a recording). Selection sets the default mode and decides which of the following steps appear. | Personalises and lets us skip irrelevant asks | none |
| 3 | **Voice setup** (only if Voice or Audio chosen) — plain-language explanation: "To follow your voice, TalkRoll listens through the microphone while you read." Button **Turn on microphone**; secondary **Not now**. Then, on Apple, speech recognition prompt; on Android the system recogniser is used. A live "say a line" test shows words highlighting so the user *sees* it work. | Mic (+ Speech on Apple) | **Mic, Speech** |
| 4 | **Record video?** (optional) — "Want to record yourself while you read?" **Set up camera** / **Skip**. | Camera + mic for Record | **Camera** (mic if not yet) |
| 5 | **Ready** — opens the Studio on the sample script with a first-Start coach mark. | Landing | none |

Notes:
- Photo-library-add is **not** requested up front; it is requested when the first video is saved.
- Android 13+ `READ_MEDIA_AUDIO` is only needed for importing a reference recording; ask when the user picks
  Audio mode's file, ideally through the system file picker which needs no permission.
- Notification permission: not needed, not requested.
- Crash reporting stays opt-in. We may show one neutral switch on the Ready screen ("Help fix crashes — no script
  text is ever sent", default **off**) or leave it only in Settings. Recommendation: leave it in Settings to keep
  onboarding short.

### 4.2 macOS

| # | Screen | Purpose | Permission |
|---|---|---|---|
| 1 | **Welcome** — what the app does; live preview of the prompter under the notch / top-centre | Value first | none |
| 2 | **Position** — pick Notch/Top-centre, Corner or Floating with the existing tile picker, and a note that it can be hidden from screen sharing (best-effort; copy must not over-promise) | Core differentiator | none |
| 3 | **Voice** (optional) — explain mic + speech, **Turn on**/**Not now**, live test | Mic, Speech Recognition | **Mic, Speech** |

macOS has no camera feature, so there is no camera step. Global shortcut tips go in the first-Start toast, not
the flow (no Accessibility permission is required).

### 4.3 Windows (only noted)

Same as macOS minus Speech Recognition; microphone consent is handled by Windows itself. Out of scope for the
first design pass.

## 5. Permission handling matrix

| Case | Behaviour |
|---|---|
| Not determined | Our "why" screen → system prompt on button tap |
| Granted | Skip the step silently (also covers reinstall) |
| Denied (can still ask, Android) | Explain once more, offer to ask again; after two denials treat as permanent |
| Denied permanently / restricted (iOS, macOS) | Show "Open Settings" and the Normal-mode alternative; never re-trigger the system prompt |
| Speech granted but mic denied (or reverse) | Treat Voice as unavailable; say which one is missing |
| Device lacks recognition support | Existing `voice_unsupported_dialog` path |

All requests keep going through `requestPermission()` so the existing `permission_result` analytics event stays
the single source. Re-check status on app resume (user may have changed it in Settings).

## 6. Apple App Review: what we must respect

Checked against the App Store Review Guidelines as I know them; **re-read the current text before submission**
(I could not fetch it in this pass).

- **5.1.1 (Data collection and storage):** purpose strings must be specific and accurate — ours already are.
  Request only what the feature needs, when it is needed. Don't require sign-in or a purchase to use basic
  functionality.
- **5.1.1(iv):** apps must not pressure users to grant permissions or disable the system prompt. Concretely: the
  pre-permission screen **must always offer a way forward without granting** ("Not now"), must not use disabled
  or misleading buttons, and must not loop the user back. A pre-prompt screen is allowed, as long as the button
  leads to the real system prompt and is not labelled as a decision the system makes (avoid "Allow"-styled
  fake dialogs that imitate the OS sheet).
- **Speech recognition privacy:** Apple may send audio to its servers unless on-device recognition is forced.
  The purpose string and our privacy text must say "on this device when your device supports it" only where
  that is true. Android Voice mode may use the network-capable system recogniser (owner decision, see
  `android-voice-reference-parity.md`); the Play Data-safety form and any on-screen privacy claim must match.
  **Never write "100% on-device" or "nothing leaves your phone" in onboarding unless it holds on that platform.**
- **5.1.2 / privacy nutrition label:** declare audio/voice handling accurately; update the label and privacy
  policy if onboarding adds any analytics.
- **2.3 (Accurate metadata):** screenshots/onboarding must show the real app; the "hidden from screen sharing"
  claim is best-effort (see `.claude/specs/prompter-invisibility-and-placement.md`) and must be worded
  that way.
- **4.0 / 4.2 (Design, minimum functionality):** onboarding must not be a splash that gates the app; keep it
  skippable and short.
- **4.1 (Copycats) and 5.2 (Intellectual property):** see §7.
- **Review notes:** state that Voice mode needs mic + speech, that all of it is optional, and how a reviewer can
  reach each feature without a device-specific setup.
- **Android (Play):** request runtime permissions in context, provide the Data-safety declaration for audio, and
  avoid permissions not used (`READ_MEDIA_AUDIO` only if the picker path really needs it).

## 7. Staying original (no copying)

- **VoicePrompter web is GPL-3.0.** Do not copy its code, demo-script text, wording, icons or layouts. We take
  only the *idea* that the sample script can teach the app, which is a generic pattern.
- **The Android APK and NotchPrompter** are other people's products (decompiled/closed or MIT-style per their
  LICENSE; check before relying on anything). We reference *behaviour* only, never code, strings or assets.
- Our own onboarding gets: original copy, our own illustrations/animation of the TalkRoll prompter, our
  own colours/typography from `mobile_theme.dart` / `desktop_theme.dart`, and our own structure (mode-first
  personalisation, live voice test), which none of the references have.
- Keep our own sample script (already written, `StudioNotifier.welcome`) and re-check that it shares no text
  with VoicePrompter's.
- Do not name or imitate competitor apps in onboarding, store text or review notes.

## 8. What makes ours distinctive

1. **Mode-first personalisation:** the choice in step 2 shapes the rest of the flow, so people who only want
   Normal never see a mic ask.
2. **Live proof, not description:** the Voice step ends with the user saying a line and watching it highlight.
3. **Honest privacy copy per platform** (see §6), shown next to each ask.
4. **Graceful denial** with a working Normal-mode fallback and an Open Settings shortcut, instead of an alert.
5. **Replayable** from Settings → Help.

## 9. Implementation sketch (for later, not now)

- A `onboardingDone` flag in `SharedPreferences` (new key beside `settingsKey`), plus a version number so a future
  flow can re-show only new steps.
- A new `lib/features/onboarding/` with one screen widget per step; reuse `fade_route.dart` for transitions and
  the existing adaptive/theming helpers. Mobile and desktop get separate layouts via `adaptive.dart`.
- Permission steps call `requestPermission()`; status read via `permission_handler` already in use.
- Mode choice writes the existing default control-mode setting; position choice reuses `position_picker.dart`.
- Per the repo rules: no stale state. The Studio, Read screen and Record screen must re-read permission status
  and the chosen default mode after onboarding finishes.
- No tests or new dependencies are planned.

## 10. Open questions for you

1. **Camera in onboarding:** ask only if the user opts into Record (recommended), or never in onboarding?
- I go with your recommendation.
2. **Speech on Apple platforms:** ask for mic and speech back-to-back inside our Voice step (recommended), or
   leave speech to first Voice use?
- I go with your recommendation.

3. **Crash-reporting opt-in** on the Ready screen, or only in Settings (recommended)?
- i am going to remove it later and might put it only when the app starts selling.

4. **Sign-in / Pro:** the plan assumes onboarding shows no paywall. Confirm the Pro upsell stays out of the
   first run.
- I go with your recommendation.

5. **Replay entry point:** Settings → Help on both mobile and macOS?
6. **iPad:** same mobile flow in a centred, width-limited layout (recommended), or a split layout?
- I go with your recommendation.

7. Should the live Voice test be required to finish the Voice step, or purely optional? (Recommended: optional.)
- I go with your recommendation.

8. Do we want a marketing survey ("how did you hear about us") at all? Recommendation: no, or optional and
   skippable and placed after the first successful read, never as a gate.
- I go with your recommendation.


---

## 11. Decisions and implementation plan (screens approved 2026-10-28)

Mock-up: https://claude.ai/artifact/1DuTnqLnj7fYzVo5bBo7cR (private). Decisions: camera asked only when the user opts
into Record; mic and speech back-to-back; no paywall, no survey, no crash-reporting switch in the flow; live test
optional; replay from Settings → Help (assumed, not answered); iPad uses the phone flow in a centred, width-limited column.

### 11.1 Code touch points (verified in the repo)

| Area | Where | Change |
|---|---|---|
| First-run flag | `lib/main.dart` (beside `crashReportingKey`), `SharedPreferences` | New key `TalkRoll.onboarding.v1` storing the completed version. |
| Gate | `TalkRollApp.build` `home:` | If not completed: mobile → `MobileOnboarding`, desktop → `DesktopOnboarding`; else existing screens. Finishing writes the flag and swaps `home` (via a small provider so the app rebuilds). |
| Screens | New `lib/features/onboarding/` | `mobile_onboarding.dart` (5 pages in a `PageView`, fixed pager dots), `desktop_onboarding.dart` (3 steps in the Studio window), shared `voice_test.dart` (the "say this" card). |
| Mode choice | `settingsProvider` (`PromptSettings.mode`, `PromptControlMode`) | Step 2 writes the default mode. Normal → skip the voice and camera steps. Hide Voice/Audio cards' ask if `voiceAvailableProvider` is false and show the existing unsupported wording instead of the mic step. |
| Position (macOS) | `lib/ui/position_picker.dart` (`PositionPicker`), `PromptPlacement` | Reuse the picker; write the chosen placement via `settingsProvider`. |
| Permissions | `requestPermission()` in `services/permissions/permissions.dart` | Mic then Speech on step 3 (Android: mic only). Camera on step 4. Status read first so granted steps are skipped; refused → the "Microphone is off" screen using `showMicrophoneDenied` copy. |
| Live test | `PrompterController` / `nativeSpeechProvider` | A short-lived listen against a fixed sentence; must stop on leave and never run in Normal mode (no mic touch). Reuses the real matcher so the highlight is genuine. |
| Replay | `mobile_settings.dart` `_HelpContent`, `preferences_screen.dart` `_HelpTab` | A "Show the tour again" row that clears the flag's runtime state and reopens the flow. |
| Sample script | existing `StudioNotifier.welcome` | Unchanged; check wording against the reference app before release. |

### 11.2 Things to settle while building

- **Overlap with the Record screen:** it already has a camera/mic primer (`_Perm.primer` in `record_screen.dart`). The
  onboarding camera step should reuse that copy and not introduce a second, different explanation. If the primer proves
  sufficient on its own, screen 4 can be dropped without changing anything else.
- **No stale state:** after the flow, the Studio, Read and Record screens must see the chosen mode, placement and
  permission status. Re-check permission on app resume.
- **Copy per platform:** the speech line differs on iOS/macOS and Android (as in the mock-up). The Android line mirrors
  the owner's decision in `android-voice-reference-parity.md`.
- **Resume safe:** quitting mid-flow restarts at screen 1; the flag is written only on finish or Skip.

### 11.3 Order of work

1. Flag + gate + empty pages (app still builds).
2. Mobile pages 1, 2, 5 (no permissions).
3. Voice step with permissions, denied state, and the live test.
4. Camera step.
5. macOS three steps + first-Start toast (`plan/desktop-ux-plan.md` §3.7).
6. Settings → Help replay row.
7. `flutter analyze`, then run on iOS simulator, Android and macOS via the existing `RUN_*.md` docs. No tests (project rule).
