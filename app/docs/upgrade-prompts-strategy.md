# Upgrade prompts: what the reference app does, and what we should do

Written 2026-10-29. Sections 1 to 3 are analysis. Sections 4 and 6 are the recommendation and what was built from it
(2026-10-29); section 6 also says what was tested and what is still missing.

Question: after the free limit is used, how does the reference app put an upgrade alert on top of the home screen, with
an option to close it, and can we do something similar without looking like a copy and without risking App Store
rejection?

Confidence tags: **[read]** read directly in the decompiled Android code. **[inferred]** reasoned from what was read,
not run. **[not verifiable]** the code is not available to us.

Decompile location (from `voice-tracking-handoff.md`): `~/projects/vp-apk/work/jadx-out/sources/`; the decoded
manifest and resources were produced separately with `jadx --no-src`. Class names are obfuscated, so references below
are file names under `defpackage/`.

## 1. What the reference app does (Android)

The assumption in the question was "after a few days, or the next time the app opens". That is not what the code does.
I searched for install dates, launch counters, "last shown" timestamps and cooldowns and found none. The prompt is
tied to **events**, and the only timer is a **one-time 24 hour sale window**.

### 1.1 The three triggers [read]

All three call the same thing: if the user is a free user, start the sale window (once), and if the sale was not
already running, open the upgrade sheet.

| Trigger | Where in the code | What happens |
|---|---|---|
| The user tries to create a new script after the 3rd free one | `defpackage/rg3.java` (around lines 980 to 1010): `if (!scriptExists && isFree && customScriptsCreated >= 3)` | Starts the sale window; the first time, opens the upgrade sheet; the script is not created. If the sale is already running it returns silently (no second sheet). |
| The user reads a script to the end (progress reaches 100%) | `defpackage/wd3.java` (around lines 540 to 575) | Same: starts the sale window, and opens the sheet if the sale was not already running. |
| The user chooses to upgrade, or edits beyond the one free edit | `defpackage/rg3.java`, `va3.java` (`hasUsedFreeEdit`) | Opens the same sheet. |

"Free user" is `kr.h()` in `defpackage/kr.java`: not Pro, billing ready, and no reviewer access (see 1.5).

### 1.2 The sale window [read]

- Class `defpackage/f90.java` (a mix of unrelated code, because the obfuscator reused the name). Method `l()` stores
  `promoStartDate = now` in SharedPreferences **only if it is still 0**, so the window starts once per install.
- `g()` is true while `now - promoStartDate < 24 hours` (1 hour when a debug flag is on).
- While the window is open, the lifetime plan is priced differently: `$59.99` instead of `$99.99` (fallbacks in
  `kr.java` around line 333; the real price comes from a second Play product, `pro.lifetime.promo`, in `ar.java`).
- A debug action resets `promoStartDate` (`do1.java`, case 16). It is a developer tool, not shown to users.

### 1.3 The banner on the home screen [read]

- `defpackage/pv.java` (around lines 1218 to 1235) builds the script list. When `promo.isActive() && user is free`, it
  inserts a row at the **top of the list**.
- The row is built in `defpackage/dv.java` (case 1): an icon, then the text **"Promo: <n>% Off Lifetime Ends In
  <countdown>"**, with a thin divider. The countdown is live and comes from the same stored start time.
- I found no close button on this row. It disappears by itself when the 24 hours end. Tapping it opens the upgrade
  sheet. [inferred]
- A second row type in the same list is a one-off nudge stored as `menuBarNudgeVisible` (`dj3.java`); it is not about
  upgrading.

### 1.4 The upgrade sheet [read]

- `rg3.t0(true)` sets a flag that opens the sheet (`rg3.java`, line 1115); `t0(false)` closes it. It is a bottom
  sheet that the user can dismiss, so it is closable. The sheet lists the plans from Google Play Billing (monthly,
  yearly, lifetime, with the promo lifetime product while the window is open).
- After the **voice setup** finishes for the first time, the app sets `postVoiceSetupPaywallPending` so a sheet follows
  the setup (`uy2.java`, near the onboarding survey). That is an onboarding-time prompt, covered in
  `onboarding-plan.md`.

### 1.5 Things in the reference app we should not copy [read]

- **A hidden reviewer unlock.** `kr.java` (lines 60 to 61) reads a SharedPreferences flag `reviewerAccessGranted` and,
  if set, treats the user as Pro. A flag like this is an undocumented way to unlock paid features. Apple's guidelines
  say not to include "hidden, dormant, or undocumented features" (the page text I fetched lists this as 2.5.19; I
  believe it is the 2.3.1(a) wording, so check the live page for the number). It is also an App Review risk in itself,
  because the rule on unlocking is that paid features must go through in-app purchase (3.1.1).
- **Hard-coded fallback prices** (`$59.99`, `$99.99`) shown when the store has not answered. Prices on an Apple
  device must come from StoreKit.
- **A countdown that starts when the user hits the wall.** It creates pressure at the moment the user is blocked.
- **No visible way to dismiss the home-screen banner.**

### 1.6 Android only

All of the above is Android. The iPhone, iPad and Mac apps are closed source. The Mac privacy notice says payments go
through Apple In-App Purchase with local receipt checks, which fits the same design, but how often and where they show
upgrade messages there is [not verifiable].

## 2. What our app had before this work, and now

Before (2026-10-29 morning): `showPaywall` opened only from a locked Start; `UpgradeCard` showed "n of 5 scripts used"
and, at the limit, "All 5 free scripts used"; `proEnforced` was a constant `false`; purchases are still not connected.
Now: see section 6. In short, the limit can be enforced with a build flag, a new script cannot be created once the free
scripts are used, an upgrade sheet opens on app open (once a day) and at every wall, and the sheet and card were
reworded to match.

## 3. What the App Store rules say (checked 2026-10-29)

Quotes are from the live App Review Guidelines page, fetched on the date above. The fetch cut off before section 5, so
5.6 was not read; check it before submitting.

- **3.1.1:** features and functionality that are unlocked must use in-app purchase, and apps "may not use their own
  mechanisms to unlock content or functionality". There must be "a restore mechanism for any restorable in-app
  purchases".
- **3.1.2:** subscriptions must give "ongoing value", last at least seven days, and be available across the user's
  devices. Trials and offers are set up in App Store Connect.
- **2.3.1(a):** "promoting a false price, whether within or outside of the App Store" is grounds for removal. Any
  "limited time" price must be real.
- **3.1.2 and scams:** apps that "trick users into purchasing a subscription under false pretenses or engage in
  bait-and-switch" are removed.
- **4.1(a):** "Don't simply copy the latest popular app ... or make some minor changes to another app's name or UI."
- **4.5.4:** push notifications "should not be used for promotions or direct marketing purposes unless customers have
  explicitly opted in", with a way to opt out.
- **2.3.2:** if there are in-app purchases, the store listing must say which features need them.

The guidelines text has nothing about countdown timers as such. A timer is judged under the accuracy and
bait-and-switch rules above. It is allowed when it is true and the offer is honoured, and it is a common reason for a
"misleading" rejection or user complaints when it resets or is fake.

## 4. Recommendation: a calmer version that is our own

Goal: tell a user who has used the free scripts how to continue, once, clearly, with an easy way out. Do not create
pressure. Do not copy the reference's wording, layout or timer.

### 4.1 What we should build

1. **One upgrade sheet, shown when the user hits the wall.** When a free user tries to present a script beyond the free
   ones (the moment `showPaywall` is already called), show it. It needs a clear **Close** button (visible, at least 44
   points), a **Restore purchases** link, the price and billing period taken from the store, and a short list of what
   Pro adds. Editing and exporting stay free, and the user's first five scripts keep working. Creating a sixth
   script is not possible until Pro (see 6.1a).
2. **A reminder in the Studio, not a banner over the list.** We already have the upgrade card. At 4 of 5 it says
   "1 free script left"; at the limit it turns amber and says "All 5 free scripts used". At the limit it gets a small
   **×** that hides it for the rest of the session; it is back on the next app open, every time, until the user is
   Pro. (An earlier draft capped this at once a week and three hides; for converting free users we keep it on every
   launch, because the card is small and never blocks the Studio.) It must never block the Studio.
3. **A real offer instead of a home-made countdown (optional, later).** If we want a launch discount, set it up as an
   introductory or promotional offer in App Store Connect and Google Play. The price, the end date and the terms are
   then drawn by the store, so they cannot be wrong. Show a plain end date ("Offer ends 30 November"), not a ticking
   clock, and only while that offer really exists.
4. **No unlock by flag.** For App Review, give reviewers a sandbox purchase and a review note. Do not ship any local
   setting, hidden gesture or promo code path that grants Pro.
5. **One sheet on app open, once a day, only after the limit is used.** This answers "the next time the app is opened,
   with an option to close it". It opens about a second after the Studio has drawn, has a ✕ and a Not Now, and the
   Studio is fully usable behind it. It waits at least 24 hours after any upgrade sheet was shown. It never opens
   for Pro, before the limit is used, during onboarding, in the middle of a read, or after a read ends (the reference
   app opens one then; for us that is when the user is most likely to be recording or presenting).
6. **Notifications:** do not send push or local notifications about upgrading. If we ever want to, it needs an
   explicit opt-in in the app (4.5.4).

### 4.2 How this stays different from the reference app

| Reference app | Ours |
|---|---|
| Sheet opens on the 3rd script, and again when a read ends | Sheet opens only when the user tries to present past the free scripts |
| 24 hour sale starts when the user is blocked, with a live countdown row on top of the script list | No countdown. An optional store offer with a real end date |
| Banner row cannot be closed | Reminder card with a visible ×, back on every launch until the user is Pro; a launch sheet at most once a day, always with a ✕ |
| Promo lifetime price swapped in by a second product | One set of prices from the store; offers are store offers |
| Reviewer flag grants Pro | Nothing hidden; sandbox purchase plus review notes |
| Wording "Promo: n% Off Lifetime Ends In ..." | Our own copy, written for our plans and prices |

The overlap is only the general idea that a free user is told about Pro at the point where they are limited. That is
how almost every free tier works and is not something an app owns.

### 4.3 How it was built (see section 6)

- `ProNotifier` (`lib/features/pro/pro_state.dart`) keeps only the time the last upgrade sheet was shown
  (`launchPromptDue()`, `notePromptShown()`). The "hidden three times, once a week" counters from the first draft were
  dropped: the card is small, never blocks the Studio, and is meant to come back on every launch.
- `UpgradeCard` has the × and the "1 free script left" state; `PaywallDialog` has the ✕, Restore Purchases, Not Now, a
  pinned buy button and the terms line; `LaunchUpgradePrompt` opens the sheet on app open and when saving is refused.
- Store prices replace the placeholder `ProPrices` once purchases are connected (Phase 3 of
  `plan/cross-platform-plan.md`), and `proEnforced` goes on only then.
- Events `upgrade_prompt_shown` and `upgrade_prompt_closed` carry the surface (names only, no script text).

### 4.4 Review checklist before submission

- Restore Purchases is reachable from the upgrade sheet and from Settings.
- Every price and period on screen comes from StoreKit or Play Billing, in the user's currency.
- The store listing says that Pro is an in-app purchase and what it unlocks (2.3.2).
- A visible Close on every upgrade surface; the app is fully usable for the free scripts after closing it.
- No claim of "limited time", "% off" or a countdown unless a store offer really backs it.
- Review notes: how to reach the sheet (save five scripts, then try to create a sixth, or press Start on a sixth), the
  sandbox account, and that nothing is unlocked outside in-app purchase.
- No hidden Pro flag, test code or unlock path in the release build.

## 5. Not checked

- I did not run the reference app, so the missing close button on its banner is read from the code, not seen.
- I did not read 5.6 of the App Review Guidelines (the fetch ended in section 5.2). Please read it before submitting.
- I could not inspect the iPhone, iPad or Mac builds of the reference app.
- Google Play's policies on subscription and offer disclosure were not reviewed here.

## 6. Built and tested (2026-10-29)

### 6.1 What changed in the app

| Piece | Where | Behaviour |
|---|---|---|
| Enforcement switch | `lib/core/entitlements/entitlements.dart` | `proEnforced` is now `bool.fromEnvironment('ENFORCE_FREE_LIMIT')`. Default **false**, so a normal build behaves exactly as before. Build with `--dart-define=ENFORCE_FREE_LIMIT=true` to run the full upgrade path. |
| Upgrade sheet | `lib/features/pro/paywall_dialog.dart` | Opens when a free user tries to present past the free scripts, from the card, from Settings and on app open. Added a **✕** in the corner (Not Now and Restore Purchases were already there). `showPaywall(..., source:)` records which surface opened it. |
| Reminder card | `lib/features/pro/upgrade_card.dart` | "1 free script left" at 4 of 5; amber "All 5 free scripts used" at the limit with a **×** that hides it for the session. |
| Sheet on app open | new `lib/features/pro/launch_upgrade_prompt.dart`, wrapped around the Studio in `lib/main.dart` | Once per launch, about 1.2 s after the Studio draws, only if the limit is enforced and used up and no upgrade sheet was shown in the last 24 hours. |
| Timing | `lib/features/pro/pro_state.dart` | `launchPromptDue()` and `notePromptShown()`; the last-shown time is in `SharedPreferences` (`EchoPrompter.upgradePrompt.v1`). `upgradeCardHiddenProvider` is session-only. |
| Events | `showPaywall` | `upgrade_prompt_shown` and `upgrade_prompt_closed`, each with `source` (`start`, `card`, `settings`, `launch`). No script text. |

Nothing hidden is unlocked, and no countdown, "% off" or "limited time" wording was added.

### 6.1a Saving is blocked past the free scripts (added 2026-10-29)

Writing a 6th script used to be allowed, with only presenting locked. That gave free users a draft they could never
play, so it was changed: once the free scripts are used, **a new script cannot be created at all** and the upgrade
sheet opens instead (the reference app does the same at its limit).

- `ProState.canCreate` (`entitlements.dart`): true when the limit is off, the user is Pro, or `used < freeScriptLimit`.
- `StudioNotifier.mayCreate()` (`providers.dart`): the one check. `newScript()`, `duplicate()` and `importScript()` now
  return false (and change nothing) when it fails. `flush()` also refuses to give an unsaved script its first id, which
  covers typing over the demo text and the mobile Save button. The sheet opens once per script being typed, not on
  every autosave.
- The sheet is opened by `LaunchUpgradePrompt`, which listens to `saveBlockedProvider` (`pro_state.dart`), so every path
  gets the same answer. Import checks before opening the file picker.
- Mobile: New script, the empty-library New, the wide-layout New and Import skip opening the editor when blocked.
  Desktop: New, Import and the sidebar + button do the same; Duplicate opens the sheet.
- Existing scripts are untouched: they can still be opened, edited, exported and, if among the first five counted,
  presented. Only creating a new one is refused.
- Copy now says "Editing and exporting your scripts stay free" instead of "Writing, editing and exporting", which is no
  longer true.

Tested on the Android emulator with 6 counted scripts: New script opened the sheet and no editor ("You've used your
5 free scripts, so a new one can't be saved."); typing over the demo and pressing Save opened the sheet and the counted
ids stayed at 6. A normal build (limit off) is unaffected because `canCreate` is true when `proEnforced` is false.

### 6.2 Why enforcement is off by default

A free user locked out with **no way to pay** is worse than no limit: it is a dead end that App Review rejects
(3.1.1 needs an in-app purchase path) and it loses the user. The buy button in the sheet still says "Buying Pro isn't
available in this build yet", because store purchases are not connected (Phase 3 in `plan/cross-platform-plan.md`).
So the prompts are complete and tested, but **converting a free user into a paying one is not possible until
purchases are wired**. The order to ship is: connect StoreKit and Play Billing with Restore, then switch
`proEnforced` to true for release builds. Until then nothing should be advertised as locked.

What "forcing" means here: a firm limit, shown clearly, reached again on every app open, with the buy path always one
tap away. It does not mean trapping the user (no sheet without a Close), hiding the free scripts, or misleading
wording; those are what get an app rejected.

### 6.3 Test results

Android emulator (API 37), build with `ENFORCE_FREE_LIMIT=true`, starting at 2 of 5:

| Step | Result |
|---|---|
| Save script 3 and 4 | Card at 4 of 5 reads "1 free script left" |
| Save script 5 | Card turns amber: "All 5 free scripts used", with ×, price line and Upgrade to Pro… |
| Save script 6 (before blocking was added) | Start shows a lock and "Needs Pro. You've used your 5 free scripts." |
| Tap the locked Start | Upgrade sheet opens with the reason, the three plans, ✕, Restore Purchases, Not Now |
| Tap Subscribe | "Buying Pro isn't available in this build yet." (purchases not connected) |
| Relaunch straight away | No second sheet (24 hour gap works); the amber card is back |
| Set the last-shown time 25 hours back, relaunch | The sheet opens over the Studio at launch |
| Tap the card × | Card hides until the next launch |
| Normal build (no define), same data | "Free plan · 5 of 5", Start not locked, no sheet at launch: unchanged from before |

macOS (enforced debug build, 5 of 5 seeded in the app's preferences): a clean launch opened the sheet over the Studio
("You've used your 5 free scripts. Pro lets you present as many as you like…"), the card read "All 5 free scripts used",
and ⌘N (New Script) opened the sheet with "…so a new one can't be saved." instead of a new script. Driven through the
accessibility tree, not by eye.

iOS simulator (iPhone 17e), enforced build, 5 of 5 seeded: the upgrade sheet opened over the Studio at launch with the
✕. The card, locked Start and × were not re-driven by hand on iOS. macOS and Windows compile (`flutter build macos`
passes) but the prompts were not run there; they use the same shared code. `flutter analyze` is clean.

### 6.4 Copy and layout fixes made (2026-10-29)

- **Sign-in claim removed.** The sheet said "One purchase for up to 5 devices when you sign in", and Settings had a "Use
  Pro on all your devices / Sign in" row (mobile) and an "Account / Sign In…" row (desktop). There is no sign-in, so
  all three were removed; the sheet now says "Get it back on a new phone or computer with Restore Purchases". The
  desktop group is titled "Purchases". Bring sign-in back only when it exists (2.3.1(a), accurate claims; and a
  button that only says "isn't available" is an unfinished feature in review).
- **"On all your devices" removed** from the sheet and Settings copy; it is not something we can promise across
  platforms yet.
- **"Writing, editing and exporting stay free"** changed to "Editing and exporting your scripts stay free", because
  creating a new script past the limit is now blocked.
- **Sticky buy area.** On a small phone the buy button used to sit below the fold. The plans now scroll, and the buy
  button, Restore Purchases, Not Now and the terms line stay pinned under them (checked on the Android emulator).
- Launch-sheet and save-blocked wording differ on purpose ("…free scripts." vs "…so a new one can't be saved.").

### 6.4a Still to do before release

- **Prices** are placeholder constants (`ProPrices`, including the "SAVE 34%" badge and "From €4.58 a month" on the
  card); they must come from the stores and the badge must be computed from them.
- **Terms and privacy links.** Apple expects subscription offers to show the price, the renewal period and links to the
  Terms of Use and Privacy Policy next to the buy button (check 3.1.2 on the live page). The sheet has the renewal
  text but no links, and the website has no terms or privacy page yet. Publish both pages and link them from the sheet
  and the App Store listing.
- **Purchases and Restore** are not connected; the buy button still says "Buying Pro isn't available in this build
  yet". Do not switch `proEnforced` on for release until they work.
- Read App Review Guidelines 5.6 (not read here) and the Google Play subscription disclosure rules.
- The `kDebugMode` plan preview in Settings is debug-only and must stay out of release builds.

### 6.5 How to test it yourself

```sh
cd app
flutter build apk --debug --dart-define=ENFORCE_FREE_LIMIT=true      # or: flutter run --dart-define=ENFORCE_FREE_LIMIT=true
# save scripts until the card reads "All 5 free scripts used", open the 6th script, tap Start
# relaunch: no sheet inside 24 hours; to see it, age the stored time and relaunch:
adb shell run-as com.echoprompter.app grep -o 'upgradePrompt.v1[^/]*' shared_prefs/FlutterSharedPreferences.xml
# macOS or iOS: edit flutter.EchoPrompter.upgradePrompt.v1 (milliseconds since 1970) to a value older than 24 hours.
```

Without the `--dart-define`, the app behaves as it did before.
