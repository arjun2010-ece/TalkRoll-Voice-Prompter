# Launch checklist: iOS, iPadOS and macOS (App Store), plus the work shared with Android

Written 2026-11-07. Goal: push 1.0 to App Review within about a week. Work top to bottom; the order matters.
The Android list is `launch-checklist-android.md`. Anything marked **[shared]** is done once for both files.

Tags: **[repo]** = I checked it in the code on 2026-11-07. **[general]** = my knowledge of Apple's process, not
re-checked on Apple's pages today. Re-read the current App Store Review Guidelines and the "Upcoming requirements" page
in App Store Connect before submitting, because those change.

## What the repo shows right now (so the list below is concrete)

- Bundle ID `com.echoprompter.app` on iOS, iPadOS and macOS (`TARGETED_DEVICE_FAMILY = 1,2`), team `N3MNK6X8NN`, version `1.0.0+1`, iOS minimum 15.0 [repo]. **The bundle ID is permanent once the app record is created. Renaming the app does not require changing it.**
- Product ids `echoprompter.pro.monthly`, `.yearly`, `.lifetime` (two subscriptions, one non-consumable) [repo: `purchase_service.dart`]. Real purchases only run with `--dart-define=PAYMENTS_APPLE=true`.
- No `PrivacyInfo.xcprivacy` in `ios/` or `macos/` [repo]. No `ITSAppUsesNonExemptEncryption` and no `LSApplicationCategoryType` in either Info.plist [repo].
- macOS Release entitlements: sandbox, microphone, user-selected files, network client [repo]. No camera entitlement (the Mac app does not record video).
- Crash reporting (Sentry) is opt-in, with no PII, screenshots or breadcrumbs, and needs a DSN [repo: `main.dart`]. This must match the privacy answers.
- `docs/app-review-notes.md` does not exist [repo]. The Phase 0 App Review cleanup (spec §7) was never done: demo copy, sample audio, review notes.
- The website has `/privacy` and `/terms`, written locally and not deployed. The legal text is a draft [repo].
- Open product items: 800-word limit, 60% big-rewrite rule (§6); rating prompt (deferred until the Apple account exists); iPad never tested.

---

## Day plan (one week)

| Day | Sections |
|---|---|
| 1 | A (decisions: name, icon, domain), B1-B2 (accounts and app records) |
| 2 | A (keywords with Astro, listing text), C (billing set up in App Store Connect), D (App Review cleanup) |
| 3 | E (onboarding redesign), F (finish product gaps) |
| 4 | G (security), H (testing, part 1) |
| 5 | H (testing, part 2: memory, hangs, iPad, Mac), I (iOS/macOS build settings and privacy files) |
| 6 | J (store listing, screenshots), K (web deploy), TestFlight upload |
| 7 | L (final pass), submit for review |

If something slips, cut from F first (see "What can wait until 1.1" at the end), never from G, H or the billing test.

---

## A. Decisions that everything else depends on **[shared]** (Day 1)

Do these first. The name changes the listing, icon, screenshots, domain, legal pages and permission strings.

- [ ] **A1. Decide whether to rename.** Spec §11 says an iOS teleprompter called "EchoPrompt" already exists, so the rename is planned (Phase 5). Decide today; do not defer. Rename touches many places (A3).
- [ ] **A2. Check the candidate name is usable.** For each candidate: search the App Store and Google Play, search the USPTO/EUIPO trademark databases (you are in Portugal, so EUIPO matters), check that the `.app` or `.com` domain is free, and that the handle is free on the social sites you care about. Pick one primary and one fallback.
- [ ] **A3. Do the rename in one pass** (use the Phase 5 list in `signature-features-echoprompter.md` §12). Places: iOS `CFBundleDisplayName` and `CFBundleName`, macOS product name and menu items, Android `android:label`, window titles, About screen, onboarding, paywall, permission strings, demo script, exported file names, `web/`, `supportEmail` and `websiteUrl` in `external_links.dart`, `sitemap`, legal pages. Keep bundle ID and application ID unchanged. The spec says to keep the display name in one constant; if that was not done everywhere, grep for "EchoPrompter" in `lib/`, `ios/`, `macos/`, `android/`, `web/`.
- [ ] **A4. Decide the domain and support email now.** The app and the legal pages use `echoprompter.app` and `arjun@echoprompter.app`. If the name changes, buy the new domain, set up the mailbox, and update `external_links.dart`. App Store Connect needs a working Support URL and a Privacy Policy URL.
- [ ] **A5. Decide the final icon.** Design once at 1024x1024, no transparency and no rounded corners (Apple rounds them) for iOS; the Mac icon uses the macOS template with its own shape. Android needs an adaptive icon (foreground and background layers). Replace `ios/Runner/Assets.xcassets/AppIcon.appiconset`, `macos/Runner/Assets.xcassets/AppIcon.appiconset`, Android `mipmap-*` and adaptive icon, `web/app/icon.png`, and `Assets/EchoPrompterAppIcon.png` (CLAUDE.md says the last two stay identical).
- [ ] **A6. Decide pricing.** Monthly, yearly, lifetime, and whether to offer a free trial. Write the three prices down in one place; you need them for the billing setup in C. Decide the same prices (or local equivalents) for Google.
- [ ] **A7. Decide the age rating, category and "made for kids" answer.** Suggested: Productivity or Photo & Video. Not for kids. Write the answers once so both stores match.

## B. Accounts and app records (Day 1)

- [ ] **B1. Apple Developer Program** ($99/year) active, and you are the Account Holder. [general]
- [ ] **B2. Paid Applications Agreement signed, plus bank and tax forms** in App Store Connect > Business. Without it, in-app purchases cannot be tested in the sandbox or sold. This can take days to be approved, so start it first. [general]
- [ ] **B3. Create the App ID** `com.echoprompter.app` in the developer portal (or let Xcode create it with automatic signing). No special capabilities are needed beyond In-App Purchase (and Speech Recognition is a usage string, not a capability).
- [ ] **B4. Create the app record** in App Store Connect: name, primary language, bundle ID, SKU. Create one record that covers iOS, iPadOS and macOS only if you want a universal purchase (same bundle ID across platforms); this is the simplest setup and means one purchase unlocks Pro on iPhone, iPad and Mac. [general] Check this is what you want before you create it; it is hard to change.
- [ ] **B5. Note the numeric Apple ID** once the record exists. It is needed for the review deep link in the rating prompt (`app-store-rating-prompt-plan.md`).
- [ ] **B6. Add yourself and your testers** to TestFlight (internal group first). Add a second Apple ID or a friend's device as a sandbox tester for purchases (Users and Access > Sandbox).

## C. Billing: Apple (Day 2) **(Android is in the other file)**

The purchase code exists (`in_app_purchase`, product ids above, debug fake store). It has never been tested against the real stores [repo: `payments-plan.md` §7].

- [ ] **C1. Create the subscription group and products** in App Store Connect: `echoprompter.pro.monthly`, `echoprompter.pro.yearly` (same group, so a user cannot hold both), and a non-consumable `echoprompter.pro.lifetime`. The ids must match the code exactly.
- [ ] **C2. For each product fill in:** reference name, price tier, localized display name and description, and a review screenshot of the paywall. Subscriptions also need a group display name. Status must reach "Ready to Submit"; the first purchases are submitted together with the app version. [general]
- [ ] **C3. If you offer a trial,** configure it as an introductory offer on the subscription and make sure the paywall text states the price after the trial and the renewal terms. Apple rejects unclear subscription copy (Guideline 3.1.2). [general]
- [ ] **C4. Paywall legal text:** auto-renewal wording, price, period, cancel in Settings, and the Terms and Privacy links. Links were added on all three platforms [repo], but they 404 until the web is deployed (K).
- [ ] **C5. Restore Purchases** is reachable and works. Apple requires it. Test it on a second device.
- [ ] **C6. Test with a StoreKit configuration file in Xcode first** (iOS simulator and a Mac build), then with real sandbox accounts on a TestFlight build with `PAYMENTS_APPLE=true`. Cases: buy monthly, buy yearly, buy lifetime, cancel, expire, restore on a fresh install, refund, buying while offline, cancelling the Apple payment sheet.
- [ ] **C7. Confirm the release build is built with `--dart-define=PAYMENTS_APPLE=true`** and that the fake store is not compiled into release (the plan says it is debug-only; verify with a release build that "Preview plan" is absent).
- [ ] **C8. Verify the free-plan rules against the real store:** 5 scripts, the shared pool of 15 free changes, the demo script exemption, and that Pro lifts all of it. Check the counter survives a reinstall (never tested on any platform: Keychain on iOS, app data on macOS).
- [ ] **C9. Decide about promo codes and gifting** (`gifting-and-promo-licenses.md`). For 1.0 use Apple offer codes only; skip any custom redeem code.

## D. App Review cleanup, spec §7 (Day 2)

- [ ] **D1. Demo script:** replace the placeholder copy ("Brightside…") with real copy that explains the app, shows sections, and has at least two action cues, one a hold. Search for `lorem` and other placeholder text. (A quick search found none in `lib/`, but the demo copy itself still needs your review.)
- [ ] **D2. Bundled sample audio** (20-30 s) matching the demo script so the reviewer can try Narration at once. You provide the recording; until then mark `TODO(arjun): replace sample audio`.
- [ ] **D3. Remove "Hidden from screen recording" on iOS and iPadOS** (and Android). Keep it on macOS. Verify it is gone from Settings and "More text options", and from the code on mobile.
- [ ] **D4. Competitor names:** none in the app, strings, metadata, screenshots, web, or the docs you attach. A search for "voiceprompter" in `lib/`, `web/app` and the native folders found none, but the keyword field in D5 must also be clean.
- [ ] **D5. Write `docs/app-review-notes.md`:** open the demo script, Section by section, Narration with the sample, reach a hold cue, Continue, Retake a section, (mobile) export the video. Add: how to reach the paywall, that no account is needed, and that the speech and camera permissions are used on the device only. Paste the same text into the App Review Information box in App Store Connect.
- [ ] **D6. Permission strings:** iOS has camera, microphone, speech recognition, and Photos add-only; macOS has microphone and speech recognition [repo]. Check each is specific and matches what the app does. Permission explainer screens say "Continue", not "Allow".
- [ ] **D7. Language-pack download copy** (`language_pack_prompt.dart`) and `docs/apple-speech-languages.md`: reread, because the reviewer may hit the download dialog on a first run with a non-English language.

## E. Redesign the onboarding (Day 3)

The current flow was built from `onboarding-plan.md` (implemented 2026-10-28, checked on Android and macOS only; iOS and iPad were not run).

- [ ] **E1. List what is wrong with it today.** Run it fresh on an iPhone, an Android phone and a Mac, write down every screen, and note where you would quit. Ask two or three people who have never seen the app to use it and say what they expected.
- [ ] **E2. Define the goal in one sentence,** for example "the user reads a script in a prompter within 60 seconds and sees why it follows their voice".
- [ ] **E3. Write the new screen list** (keep it short: 3 screens or fewer before the demo script). Typical: what it does, the three modes in one line each, permissions only when needed. Do not ask for the microphone until Voice is started.
- [ ] **E4. Mock the new flow,** get your own approval, then build it. Keep platform gates (CLAUDE.md): build and test on one platform before the next.
- [ ] **E5. Decide about a survey** ("How did you hear about us?") and about analytics. If you add any analytics, the privacy answers in J change. Prefer no analytics in 1.0.
- [ ] **E6. Re-test** the free-plan card, the demo script exemption, first-run permissions, and "skip" paths. Check light and dark, portrait and landscape, iPad.
- [ ] **E7. Update the screenshots** (J) after the redesign, not before.

## F. Finish the product gaps (Day 3, cut if short on time)

- [ ] **F1. 800-words-per-script limit and the "612 / 800 words" counter** (spec §6). Not built. Needs a decision: if you cut it, remove it from the paywall copy and the store text so nothing promises it.
- [ ] **F2. 60% word-diff "big rewrite" rule** (spec §6). Not built: today typing over the demo script saves as a new script and takes a change with no warning.
- [ ] **F3. Rating prompt** (`app-store-rating-prompt-plan.md`): needs the Apple ID from B5. Optional for 1.0; add it in 1.0.1 if short on time.
- [ ] **F4. Open items in the spec you chose not to fix:** list them in a backlog file. From the result doc: Android timing precision inside long sentences, Voice last-word matching with synthetic speech, after "Sections…" the prompter waits paused with no hint on the camera screen, Narration camera option wording "Voice only / Voice + camera", macOS Studio "Start ⌘↩" shows a blue emoji box, macOS Narration needs a click on Play to start.
- [ ] **F5. Run the pending Cross-platform fixes** in `signature-features-echoprompter.md` and set statuses.

## G. Security and vulnerability checks **[shared]** (Day 4)

- [ ] **G1. Secret scan of the repo and its history:** `gitleaks detect` (or `trufflehog`). Look for the Sentry DSN, API keys, keystores, and `.env` files. Nothing has been pushed yet, so history is still easy to clean.
- [ ] **G2. Dependency audit:** `flutter pub outdated`, then read the changelog for each security-relevant package (`sentry_flutter`, `file_picker`, `share_plus`, `url_launcher`, `permission_handler`, `in_app_purchase`). In `web/`: `npm audit`. Do not upgrade blindly right before launch; fix only real vulnerabilities.
- [ ] **G3. Data on device:** scripts and recordings are stored in app storage. Confirm nothing is world-readable on Android (`allowBackup` is on and backs up scripts, on purpose) and that iOS file protection is acceptable. Write down what leaves the device: Sentry (opt-in), Apple language-pack download, store purchases, and nothing else.
- [ ] **G4. Network review:** grep for every `http` use. Release builds must only use HTTPS. The `WEBSITE_URL` define must not be set to a local address in release builds (check build scripts).
- [ ] **G5. URL and file handling:** `openExternal` opens fixed URLs only. Check the file-import path (scripts, audio) for huge files and malformed files: import a 100 MB text file, a zero-byte file, and a binary file renamed to `.txt`.
- [ ] **G6. In-app purchase integrity:** the entitlement is decided on the device from the store response. For a $-small app that is the usual choice, but state that a jailbroken device can bypass it, and decide that you accept it for 1.0. (RevenueCat or server receipt checks are the alternative; see `payments-plan.md`.)
- [ ] **G7. Debug features are absent in release:** the fake store, "Preview plan", any debug logging, VM-service hooks, and `debugShowCheckedModeBanner`. Build release and check each.
- [ ] **G8. Privacy truth check:** compare what the privacy page says with what the code does (G3), then fix whichever is wrong. This is also the basis for J.
- [ ] **G9. Web:** headers (CSP, X-Content-Type-Options), HTTPS only, no mixed content, no admin or debug routes. `npm run build` passes.
- [ ] **G10. macOS hardening:** hardened runtime on, sandbox on (already in the entitlements), and no entitlement you do not need. Check the signed app with `codesign -dvv --entitlements -`.

## H. Full testing: features, memory leaks, hangs **[shared]** (Days 4-5)

Run on: iPhone (done so far: 15 Pro Max, iOS 26.6.2), **iPad (never run)**, a second smaller iPhone if you can, macOS, and a release build of each (debug builds hide performance problems). The Android devices are in the other file.

- [ ] **H1. `flutter analyze` is clean;** the existing tests pass. Two tests in `test/prompter_controller_test.dart` fail on committed code (pre-existing, `settingsProvider` throws `UnimplementedError`). Decide: fix, or leave and note it. CLAUDE.md says not to create tests in implementation tasks, so this is your call.
- [ ] **H2. Feature regression pass,** all three modes (Auto-scroll, Voice, Narration) × whole script / section by section × with and without cues, on iPhone, iPad and Mac. Use the result doc (`signature-features-echoprompter-result.md`) "Not covered" lists as the to-do: iPad, Narration without camera in light/landscape, Voice with real human speech, airplane mode, speech permission denied, call interruption, full disk, front camera section clips, a single keeper exported.
- [ ] **H3. Permissions matrix:** for camera, microphone, speech recognition and Photos: first ask, deny, allow later in Settings, "ask next time". The app must not crash or hang in any state.
- [ ] **H4. Memory leaks:** run a release or profile build and watch memory (Xcode Instruments "Leaks" and "Allocations"; Flutter DevTools "Memory"). Repeat 30 times: open the prompter and close it in each mode; start and stop Voice; record and discard a camera take; import a recording and delete it; open the Sections sheet. Memory should return to near the baseline. The camera and audio plugins are the likely places.
- [ ] **H5. Long runs:** 30 minutes of Auto-scroll on a long script; 15 minutes of Voice; a 10-minute Narration with the camera on a phone (check heat, battery and that the recording is complete). Check the screen stays awake (wakelock).
- [ ] **H6. Hangs:** large script (50,000 words) in the editor, in the prompter, and in the Sections list; very large text size; rapid mode switching; backgrounding and returning during a take, during Voice, during Narration, during a purchase.
- [ ] **H7. App lifecycle:** kill the app mid-take and relaunch; low-power mode; device rotation during a take; an incoming call or alarm; Do Not Disturb.
- [ ] **H8. Accessibility:** Dynamic Type, VoiceOver on the paywall and onboarding, and contrast in light and dark.
- [ ] **H9. Reinstall test:** delete and reinstall; check the free-plan counter and purchases (restore). This was never tested.
- [ ] **H10. Upgrade test:** install a build, create scripts, then install the next build over it. Saved scripts and settings must survive.
- [ ] **H11. iPadOS layout:** portrait, landscape, split view and Stage Manager (an iPad app that fails here is rejected under 4.0 / 2.1). Confirm the camera and prompter layouts on iPad (`ios-ipad-camera-and-prompter-findings.md` lists known iPad issues).
- [ ] **H12. Mac:** window resize, fullscreen, multiple displays, notch layout, global hotkeys with another app in front, and menu bar items. Test on a Mac without a notch and, if possible, on macOS 13-15 (spec says macOS 13+; SpeechAnalyzer paths need macOS 26, older paths are the fallback). Confirm the minimum macOS and iOS versions you will really support, and that the oldest one has been run at least once.

## I. Build settings, privacy files and signing (Day 5)

- [ ] **I1. Add `PrivacyInfo.xcprivacy`** to the iOS and macOS targets. Declare the "required reason" APIs used by Flutter and your plugins (user defaults, file timestamps, disk space, system boot time). Check each plugin's own manifest is included. Declare no tracking. Apple warns or rejects when this is missing. [general]
- [ ] **I2. Add `ITSAppUsesNonExemptEncryption = NO`** to both Info.plists if you only use the OS's standard HTTPS encryption (confirm). It skips the export-compliance question at every upload.
- [ ] **I3. Mac category:** add `LSApplicationCategoryType` (for example `public.app-category.productivity`) to `macos/Runner/Info.plist`.
- [ ] **I4. Version and build numbers:** `1.0.0+1` becomes marketing version 1.0.0 and a build number that increases with every upload. Decide the scheme (for example `+1`, `+2`...).
- [ ] **I5. Deployment targets:** iOS 15.0 is set. Check that the SpeechAnalyzer code paths are guarded (iOS 26) and that the fallbacks run on iOS 15-25. Set the minimum iOS and macOS you will support and write it in the listing.
- [ ] **I6. Orientation and device family:** confirm iPhone and iPad orientations in Info.plist [repo has `UISupportedInterfaceOrientations` and an iPad key] and that `UIRequiresFullScreen` is not blocking iPad multitasking.
- [ ] **I7. Signing:** automatic signing with team `N3MNK6X8NN`. For macOS you need an Apple Distribution certificate and a Mac Installer Distribution certificate for the Mac App Store.
- [ ] **I8. Build release:** `flutter build ipa --release --dart-define=PAYMENTS_APPLE=true` (plus the Sentry DSN define). For the Mac: `flutter build macos --release --dart-define=PAYMENTS_APPLE=true`, then archive and upload from Xcode (Product > Archive > Distribute > App Store Connect). The generated `project.pbxproj` changes from Xcode are expected; review the diff before you commit it.
- [ ] **I9. Upload both builds** and wait for processing; fix any warning e-mail from Apple (missing icons, privacy manifest, deprecated API).
- [ ] **I10. Latest-SDK rule:** Apple only accepts apps built with a current Xcode and SDK (check the yearly requirement in App Store Connect). Make sure your Xcode version qualifies. [general]

## J. Store listing (Days 2 and 6)

- [ ] **J1. Subscribe to Astro** (https://tryastro.app) only after A1-A2, so you research the right name. Use it to: check keyword popularity and difficulty for your name, subtitle and keyword field; compare the top competitors' titles and subtitles (for ideas only, never their names in your metadata); check ranking per country (start with US, UK, Portugal, Brazil, Germany, France, Spain).
- [ ] **J2. Write the metadata** within Apple's limits (these limits are what I know: name 30 characters, subtitle 30, keywords 100 including commas, promotional text 170, description 4000) [general]. Do not repeat words between name, subtitle and keywords. No competitor names (D4), no "best/#1/free" claims, no prices in the name.
- [ ] **J3. Choose the category** (A7) and a secondary one.
- [ ] **J4. Localize at least English.** Because speech supports 33 languages, consider localizing the listing for a few more (Portuguese, Spanish, German, French). Not needed for the first submission.
- [ ] **J5. Screenshots,** after E7: iPhone 6.9-inch and 6.5-inch sets, iPad 13-inch, Mac. Show: reading with the prompter, the three modes, section clips and export, cues. Check the current required sizes in App Store Connect. Do not show competitor apps or private info.
- [ ] **J6. App preview video** (optional, 15-30 s).
- [ ] **J7. Privacy nutrition label:** answer from G3/G8. If Sentry crash reporting is on only by opt-in and sends no identifiers, declare it accordingly; if the user can enable it, declare "Crash data". Purchases are handled by Apple. No tracking.
- [ ] **J8. Age rating questionnaire** and **content rights** answers (A7). Select "no third-party content" unless true, and list font licenses if asked (the fonts are SIL OFL).
- [ ] **J9. Support URL, marketing URL and privacy URL** (K). Terms: use the standard Apple EULA or link your own `/terms` in the description.
- [ ] **J10. Copyright and contact** fields. Demo account: none needed (no sign-in). State "No account required" in the review notes.
- [ ] **J11. Pricing and availability:** choose territories, price tier for the free download, release option (manual release recommended for 1.0).
- [ ] **J12. Attach the in-app purchases** to the version before you submit (C2).

## K. Website and legal **[shared]** (Day 6)

- [ ] **K1. Deploy `web/`** to Netlify (`netlify.toml` already sets `base = "web"`). Set `NEXT_PUBLIC_SITE_URL`. Point the domain (A4).
- [ ] **K2. Check** `/privacy`, `/terms`, `/sitemap.xml`, `/robots.txt` load over HTTPS, and open them from the app (paywall links on all three platforms).
- [ ] **K3. Review the legal text yourself.** It is a draft: you as controller, Portuguese law, CNPD, a liability cap of 12 months of payments. Have a lawyer or a trusted template check it if you can, and update the "last updated" date. Make it match G8 and the final name.
- [ ] **K4. Add a Support page** or contact section for the Support URL, with the mailbox from A4.
- [ ] **K5. Update the website copy to the final name and screenshots,** and add App Store badges when the app is live.

## L. Final pass and submission (Day 7)

- [ ] **L1. Fresh-install run of the exact TestFlight build** on iPhone, iPad and Mac: onboarding, demo script, each mode, a purchase in sandbox, restore, paywall links.
- [ ] **L2. Re-read the App Store Review Guidelines** sections most likely to bite you: 2.1 (complete app, working purchase), 3.1.1/3.1.2 (purchases and subscription text), 4.0 (design), 5.1.1 (privacy, permission strings, data collection), 5.1.2, and Mac-specific rules.
- [ ] **L3. Fill in "App Review Information"** (D5), notes, contact phone and e-mail.
- [ ] **L4. Select the build, attach the purchases, set release to manual,** and submit for review (iOS/iPadOS and macOS can be submitted separately; do iPhone first).
- [ ] **L5. After submission:** watch for the review e-mail daily; keep the phone and Mac on the exact build; do not change the server (web) or the purchase products during review.
- [ ] **L6. If rejected:** read the exact guideline, reply in App Resolution Center, fix, and resubmit. The most likely reasons for this app: a purchase that does not load, missing privacy manifest, permission wording, the legal links not loading, or an iPad layout problem.

---

## What can wait until 1.1 (do not let these block the submission)

- 800-word limit and the 60% rewrite rule (F1, F2) if you remove their mentions from the copy.
- Rating prompt (F3).
- Localized store listings beyond English (J4).
- App preview video (J6).
- Custom redeem codes and RevenueCat (C9, G6).
- Mac screen recording and the other items listed in the spec §8 "Future scope".

## Things I could not confirm from the repo

- Whether your Apple Developer account and the Paid Applications agreement are active. B1 and B2 are the first risk to a one-week plan.
- Whether the current app name is available on the App Store (A2).
- The exact current Apple requirements for screenshot sizes and the SDK version; read App Store Connect.
- That the privacy manifest list is complete: check each plugin's manifest after the first build.
