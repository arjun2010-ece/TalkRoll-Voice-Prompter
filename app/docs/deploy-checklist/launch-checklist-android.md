# Launch checklist: Android (Google Play)

Written 2026-11-07. Companion to `launch-checklist-apple.md`. The shared work (name, icon, domain, onboarding redesign,
security, web deploy, legal text, listing words) is written once in the Apple file; this file points to those items by
letter and only lists what is different on Android.

Tags: **[repo]** = checked in the code on 2026-11-07. **[general]** = my knowledge of Google's process, not re-checked
on Google's pages today. Read the Play Console "Policy" and "App content" pages before you submit, because they change.

## Read this first: Android is probably NOT a one-week job

Google's rule for **new personal developer accounts** (created after November 2023) is that you must run a **closed test
with at least 12 testers opted in for 14 continuous days** before you can apply for production access [general: I
believe the number was 20, lowered to 12 in 2024; confirm it in Play Console]. Organization accounts are exempt.
If your account is personal and new, the earliest production release is about 14 days after you start the test, so:

1. **Do Section B today.** It is the critical path. Start the closed test as soon as one signed build is uploaded.
2. Use the 14 days for billing tests, bug fixes and the rest of this list.
3. Ship Apple first (next week), Android about two weeks later.

If you have an organization account or an older personal one, this does not apply.

## What the repo shows right now

- Application ID and namespace `com.echoprompter.app`, `minSdk = 26`, `compileSdk = 37`, `targetSdk = flutter.targetSdkVersion`, version `1.0.0+1` [repo: `android/app/build.gradle.kts`].
- **Release builds are signed with the debug key** (`signingConfig = signingConfigs.getByName("debug")`, with a TODO) [repo]. Play will reject this. Fixing it is task C1.
- No code shrinking (`isMinifyEnabled`) or ProGuard rules configured [repo].
- Permissions: CAMERA, RECORD_AUDIO, READ_MEDIA_AUDIO; camera is `required="false"` [repo]. Narration does not ask for the microphone [result doc].
- `allowBackup="true"` with `backup_rules.xml` and `data_extraction_rules.xml` that back up `FlutterSharedPreferences.xml` and `app_flutter/EchoPrompter Scripts` [repo]. This carries the free-plan counter across reinstall, and also the user's scripts.
- Product ids `echoprompter.pro.monthly`, `.yearly`, `.lifetime`. Real purchases only run with `--dart-define=PAYMENTS_ANDROID=true` [repo]. Play Billing was never tested against the real store.
- Android Block Store (a second reinstall-proof copy of the counter) is not built.
- Android Narration timing is derived from pauses, not word-level transcription. It was tested on the emulator only (Pixel 6/7), never on a real phone [result doc].

---

## A. Do the shared items first (see the Apple file)

Same decisions and work, done once. Android-specific notes only:

- [ ] **A1. Name, domain, email, icon, pricing, category, age rating** (Apple file A1-A7). Play uses a different icon format: a **512x512 PNG** store icon, a **1024x500 feature graphic**, and an **adaptive icon** in the app (foreground and background layers; keep the artwork inside the safe zone).
- [ ] **A2. App name on Android:** change `android:label` in `AndroidManifest.xml` and any strings (Apple file A3). Keep `com.echoprompter.app`. It cannot be changed after the first upload.
- [ ] **A3. Onboarding redesign** (Apple file E). Test it on a small phone, a large phone and a tablet. Android back-button and gesture navigation behave differently from iOS.
- [ ] **A4. Security (Apple file G)** applies equally. Android extras are in section F below.
- [ ] **A5. Web deploy and legal pages** (Apple file K). Play asks for a **Privacy Policy URL** and, in the Data safety form, wants it to match what the app does.

## B. Account and the testing clock (Day 1)

- [ ] **B1. Google Play Developer account** ($25 one time) created and identity verified. Verification can take days. [general]
- [ ] **B2. Find out the account type** (personal or organization) and whether the 12-tester / 14-day closed test applies (see top of file).
- [ ] **B3. Gather 12+ testers** (friends, family, a mailing list, testing communities) with Google accounts, and collect their Gmail addresses. Add them to a Google Group or an email list in the testing track. Ask them to opt in and keep the app installed for the 14 days.
- [ ] **B4. Create the app in Play Console:** name, default language, app or game, free, declarations. 
- [ ] **B5. Turn on Play App Signing** (default for new apps). You sign with an **upload key**; Google holds the app signing key.

## C. Signing and the release build (Day 1-2)

- [ ] **C1. Create an upload keystore** (`keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`). **Back it up in two places** (password manager and an encrypted drive). Losing the upload key means a support request with Google. Do not commit it.
- [ ] **C2. Create `android/key.properties`** (git-ignored) and change `build.gradle.kts` so the `release` build type reads it. Remove the debug signing. Check `.gitignore` covers both files.
- [ ] **C3. Decide on code shrinking.** Turn on R8 (`isMinifyEnabled = true`, `isShrinkResources = true`) only with ProGuard rules for Media3 Transformer (`ClipJoin.kt`), Sentry, `in_app_purchase` and the speech channel, then test every feature on the minified build. If time is short, ship without shrinking; the app is larger but works.
- [ ] **C4. Version:** `1.0.0+1`. Every upload needs a higher `versionCode` (the `+N`). Plan the numbers.
- [ ] **C5. Target API level.** Play requires new apps and updates to target a recent API (the requirement rises every August; `compileSdk` is 37, `targetSdk` comes from Flutter). Check the current rule in Play Console, and that `targetSdk` meets it. [general]
- [ ] **C6. 16 KB page size.** Apps targeting Android 15+ must support 16 KB memory pages for native code. [general] Check every native library in the release bundle (Flutter engine, Media3, plugins, any speech model libs): `zipalign -c -P 16 -v 4 app.apk` or the Android Studio APK Analyzer. Update plugins if one fails.
- [ ] **C7. Build the bundle:** `flutter build appbundle --release --dart-define=PAYMENTS_ANDROID=true` (plus the Sentry DSN define). Play takes `.aab`. Confirm the Sentry define is a real DSN or empty, and `WEBSITE_URL` is not a local address.
- [ ] **C8. Install the release build on a real phone** (via `bundletool` or an internal-testing link). Do not release without running it once.

## D. Billing: Google Play (Day 2-3)

- [ ] **D1. Merchant profile / payments profile** set up in Play Console (name, address, bank, tax info). Without it you cannot sell. [general]
- [ ] **D2. Upload a signed build to the Internal testing track first.** Google cannot test Billing without an uploaded build with the same application ID. [repo: `payments-plan.md` §2]
- [ ] **D3. Create the products** with the same ids as the code: subscriptions `echoprompter.pro.monthly` and `echoprompter.pro.yearly` (base plans and prices, optional free-trial offer) and a one-time (in-app) product `echoprompter.pro.lifetime`. Activate each one.
- [ ] **D4. Add licence testers** (Play Console > Settings > License testing) so your test accounts are charged nothing. Add your own Gmail.
- [ ] **D5. Test purchases on a real device or a Play-enabled emulator** from the Internal testing track: buy monthly, yearly, lifetime; cancel; let a subscription lapse (test renewals run on an accelerated clock); Restore on a fresh install and on a second device; cancel the payment sheet; buy offline; a declined payment; a refund.
- [ ] **D6. Subscription copy:** price, period, auto-renew, how to cancel (Play Store > Subscriptions), plus the Terms and Privacy links (already on the paywall on Android [repo]). Check they open once the website is deployed.
- [ ] **D7. Verify the free plan on Android against the real store:** 5 scripts, the pool of 15 changes, the demo exemption, Pro lifting the limit.
- [ ] **D8. Reinstall persistence:** uninstall and reinstall, with backup enabled, and confirm the counter returns (Auto Backup works only with a Google account and cloud backup on, and restores on first install). Never tested. The emulator may not test this faithfully; use a real phone.
- [ ] **D9. Block Store (optional for 1.0).** Auto Backup can be turned off by the user; Block Store would keep the counter anyway. Spec §6 asks for it. If cut, say it in your notes.
- [ ] **D10. Promo codes:** Play promo codes work with the existing purchase code (`gifting-and-promo-licenses.md`). Nothing to build for 1.0.
- [ ] **D11. Confirm the debug fake store and "Preview plan" are absent from the release bundle** (Apple file G7).

## E. Product pieces specific to Android

- [ ] **E1. Test on a real phone,** not only the emulator: Voice with a real voice, Narration timing, camera recording, section clips, export to the gallery, the Play Billing flow. At least two phones, one of them old (API 26-29) and one recent.
- [ ] **E2. Narration timing:** the spec asks for word-level accuracy; Android uses pauses. Test with a 3-5 minute recording and a long sentence script. Decide if it is good enough for 1.0, and say so in the store text only if you are happy with it.
- [ ] **E3. Android language detection** ("Automatic") falls back to English for French, Italian, Dutch and Spanish without special letters. Decide whether to list the languages or recommend choosing the language by hand.
- [ ] **E4. Voice mode on devices without on-device speech** (no Google speech services, some Huawei and degoogled phones): confirm the app shows a clear message rather than crashing.
- [ ] **E5. Android 13 and 14/15/16 behaviours:** notification and media permissions, predictive back, edge-to-edge (forced on Android 15), foldables and tablets, landscape. Run the app at least once on API 33 and on the newest version you have. Result doc says Android 13 was "works by design, not run".
- [ ] **E6. Camera screen in landscape and with a cut-out** (the iPhone landscape fix was iOS-only; Android and iPad landscape were not looked at, see "Cross-platform fixes pending").
- [ ] **E7. Interruptions:** phone call, alarm, low storage, battery saver, app killed during a take, "Don't keep activities".
- [ ] **E8. Memory leaks and hangs:** Android Studio Profiler (memory and CPU) on a release or profile build, and the loops in the Apple file H4-H6. Add Android's own checks: `adb shell dumpsys meminfo com.echoprompter.app` before and after 30 open/close cycles, and watch for ANRs in Play Console pre-launch report and Logcat.
- [ ] **E9. Permission matrix:** camera, microphone: deny, "only this time", deny permanently ("don't ask again"), then re-enable from Settings. The app must show a clear path, not crash.
- [ ] **E10. Accessibility:** TalkBack on the paywall and onboarding, font scale 200%, display size large.
- [ ] **E11. Test on Pre-launch report:** upload to the Internal track and read Google's automatic device test results (crashes, accessibility, security).

## F. Security checks specific to Android (Day 4)

- [ ] **F1. Do the shared security list** (Apple file G1-G10).
- [ ] **F2. Manifest review:** `exported` only where needed (MainActivity is exported for the launcher, and that is correct). No unneeded permission. No cleartext HTTP traffic (set `usesCleartextTraffic="false"` or a network security config if any plugin needs it).
- [ ] **F3. Backup contents:** `allowBackup=true` stores the user's scripts and the counter in Google's backup. That is by design [repo: `free-script-limit-persistence.md`], but it must be in the Data safety answers and the privacy page. Decide if scripts should really be in cloud backup.
- [ ] **F4. READ_MEDIA_AUDIO** is used for picking narration files. Check whether the system file picker already gives you access without the permission (a photo picker or `ACTION_OPEN_DOCUMENT` does). If so, remove the permission, because Play asks you to justify sensitive permissions.
- [ ] **F5. Run the Play pre-launch security report** and fix any item it flags. Optionally run `MobSF` on the release APK.
- [ ] **F6. Debuggable flag false in release** and logs do not contain script text.

## G. Store listing, Data safety and policy (Days 2-6)

- [ ] **G1. Use the Astro research** (Apple file J1-J2). Play ranks on the **title (30 characters), short description (80) and full description (4000)**; there is no keyword field, so keywords have to appear naturally in the text. Repeat each important keyword a few times but write for people.
- [ ] **G2. Graphics:** 512x512 icon, 1024x500 feature graphic, at least 2 phone screenshots (aim for 6-8), and optional 7-inch and 10-inch tablet screenshots. Take them after the onboarding redesign.
- [ ] **G3. Data safety form:** declare what is collected and shared. For this app: no accounts; scripts and recordings stay on the device; purchases handled by Google; crash data only if the user turns on Sentry (declare it). Say whether data is encrypted in transit (HTTPS) and whether users can ask for deletion (uninstall deletes local data; backups are with Google). Match the privacy page (Apple file G8).
- [ ] **G4. Content rating questionnaire** (IARC) in "App content".
- [ ] **G5. Target audience:** 18+ or 13+; not designed for children. Declare no ads.
- [ ] **G6. Other App content declarations:** ads (none), news app (no), COVID (no), government (no), financial features (no), health (no), advertising ID (no), and any "sensitive permissions" forms. If you keep camera and microphone, state why in the permissions declaration.
- [ ] **G7. Photo/video and media permission policy:** if the app only saves its own recordings and picks audio via the picker, you should not need the broad media permissions (F4).
- [ ] **G8. Store listing text must not mention competitors** (Apple file D4) or promise features not built (800 words, 60% rule: Apple file F1/F2).
- [ ] **G9. Contact details:** support email, website and privacy URL (Apple file A4, K).
- [ ] **G10. Pricing and distribution:** countries, free app with in-app purchases, "contains in-app purchases" flag, content guidelines and US export laws accepted.

## H. Testing tracks and release (Day 2 to +14 days)

- [ ] **H1. Upload the first signed `.aab` to Internal testing** (instant, up to 100 testers) to test billing and install paths (D2).
- [ ] **H2. Create the Closed testing track** and upload the release candidate. Invite the 12+ testers (B3). **Start the 14-day clock here.** Fix and re-upload new versions in the same track without restarting the clock if the testers stay opted in. [general; confirm in Play Console]
- [ ] **H3. During the 14 days:** collect crash reports (Play Console > Android vitals), answer tester feedback, run the E-section checks on real phones, and fix.
- [ ] **H4. Apply for production access** after the 14 days (Play Console asks about your testing and the app). Google reviews that request, which can take a few days. [general]
- [ ] **H5. Production release:** staged rollout (for example 10% then 50% then 100%), release notes, and the AAB from the closed track promoted.
- [ ] **H6. After release:** watch Android vitals (crashes, ANRs), reviews, and purchase errors. Keep the upload keystore safe.

## I. Final Android pass before the first production upload

- [ ] **I1. Fresh install of the exact bundle** from the testing track: onboarding, demo script, each mode, purchase with a licence tester, restore, paywall links open the deployed website.
- [ ] **I2. Check Play policy pages** for subscriptions, user data and permissions once more.
- [ ] **I3. Confirm** `versionCode` is higher than every earlier upload, the privacy URL works, the Data safety form is submitted, and the content rating is done. Play will list any missing declaration under "Publishing overview".

---

## What can wait until 1.1

- R8 shrinking (C3) if it causes issues.
- Block Store (D9).
- Tablet screenshots, a promo video, and listing translations.
- 800-word limit and the 60% rewrite rule (Apple file F1/F2).

## Things I could not confirm

- Your Play account type and whether the 12-tester / 14-day rule applies; this decides the whole schedule.
- The current target-API and 16 KB requirements on the day you upload.
- Real-phone behaviour: every Android test so far was on the emulator.
