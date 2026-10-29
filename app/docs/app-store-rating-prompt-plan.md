# Rating / review prompt plan

Status: **deferred until we have an Apple Developer account.** Nothing is implemented yet.

Source: reverse-engineered Android VoicePrompter (`app.voiceprompter`), see `voice-tracking-handoff.md` for the decompile locations. The trigger logic below is read from an exact instruction-level dump of `defpackage.io1` (fallback decompile). The star-to-screen mapping is partly **[inferred]** because the decompiled UI code was garbled.

## How the reference app does it

**When it asks.** A check runs on the live words-read and words-spoken counters. It skips everything if `hasSubmittedReviewRequest` is already true. Otherwise:
1. **First nudge**, once only (`hasTriggeredInitialNudge`): at least 300 words read and at least 1 word spoken, so the user has really used the product.
2. **Milestones** at 10k, 20k, 50k, 100k, 200k and 500k words read. `lastPromptedMilestone` records the last one shown, so each fires once. This is the gentle retry for people who dismissed an earlier ask.

**What the user sees.** A dismissible in-app card: "You've read 12,345 words!" / "How are you enjoying VoicePrompter so far?" with 1-5 stars. The tap saves `lastRatingStars` and logs an analytics event (`ratingStarSelected`).
- **5 stars:** "Thank you so much! Would you like to leave a review on Google Play?" The button calls the Play In-App Review API. If that fails it falls back to `market://details?id=<package>`, then the Play web URL. It then sets `hasSubmittedReviewRequest` so the user is never asked again.
- **Lower stars:** "Would you like to share your feedback?" Opens their support page / email, so complaints reach the developer, not the store.

The app-update dialog in `MainActivity` is a different feature (it stores `skippedAppUpdateVersionCode`); don't confuse it with the rating flow.

## What to copy for our app
- Gate on real usage and delight, not launches: words read, plus a finished prompt or recording.
- Ask once at a good moment (never mid-prompt), with a few well-spaced milestones as the retry.
- Pre-screen with stars. Only 4-5 stars goes to the native review prompt; everyone else gets private feedback.
- Persist the "done" flag so nobody who reviewed is asked again.
- Native APIs: iOS / macOS `requestReview` (StoreKit). Android: Play In-App Review with a store-page fallback.
- Both stores throttle the native prompt (Apple: at most 3 times per 365 days per user) and the OS may silently skip it. The "write a review" deep link has no such limit, so use it as the happy-path fallback.

## Accounts and IDs
- **iOS / macOS:** paid Apple Developer account ($99/year).
  - `requestReview` needs no ID. In a debug build it shows the sheet but submits nothing; TestFlight builds never show it, so it is only truly proven in production.
  - The numeric **Apple ID** (exists once the app record is created in App Store Connect) is needed only for the direct link `itms-apps://apps.apple.com/app/id<APPLE_ID>?action=write-review`. Keep it in one config value.
- **Android:** Google Play developer account ($25 one-time). No app ID beyond the package name, but the in-app review flow only works for a build installed from Play (an internal-testing track build is enough). A sideloaded APK always takes the fallback path.

## Plan once the Apple account exists
1. Create the app record in App Store Connect and put the Apple ID in config.
2. Persisted state: `hasSubmittedReviewRequest`, `hasTriggeredInitialNudge`, `lastPromptedMilestone`, `lastRatingStars`.
3. Trigger check on the words-read / words-spoken counters using the thresholds above.
4. Star card UI, then: 4-5 stars to `requestReview` (fallback: write-review link), lower to feedback link.
5. Android Play In-App Review later, when the Google account exists (matches the Apple-only plan in `gifting-and-promo-licenses.md`).
