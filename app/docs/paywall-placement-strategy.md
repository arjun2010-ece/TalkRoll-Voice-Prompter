# Where to show the paywall: placement strategy

Written 2026-10-29. Analysis and plan only: **nothing in this document is implemented yet.** It builds on
`upgrade-prompts-strategy.md` (what the reference app does, and what was built so far).

Question: apps that convert free users into paying ones show a paywall in more than one place. Where should ours go,
and how do we do it without annoying people or risking App Store rejection?

Confidence tags: **[general]** common industry practice, not measured on our app. **[secondary]** a number taken from a
write-up of someone else's report; check the original before relying on it. **[ours]** read in our code.

## 1. What the industry data says

All figures are from secondary write-ups of RevenueCat's State of Subscription Apps reports (2025 and 2026 editions) and
from Airbridge and Adapty numbers quoted by Airbridge. I did not read the primary reports. Treat them as direction, not
as targets.

- **Hard paywall vs freemium [secondary]:** median day-35 download-to-paid is about 12% for hard paywalls and about 2%
  for freemium (2026 edition: 10.7% and 2.1%). Hard-paywall apps also had more refunds (5.8% vs 3.4% in the 2025 data),
  while one-year retention was almost the same (27% and 28%).
- **When people subscribe [secondary]:** most trials start on install day (82% in the 2025 report, 89% in the 2026
  analysis). Onboarding placements with a trial converted at about 1.78% install-to-paid, against 0.76% for in-app gates
  without a trial.
- **Trials [secondary]:** trials of 17 to 32 days converted at a median 42.5%, against 25.5% for four days or less.
  Trial-to-paid is about 32 to 33% on both iOS and Android.
- **Platform gap [secondary]:** download-to-paid is about 0.9% on Android and 2.6% on iOS; once a trial starts the two
  platforms are the same.

What this means for us: a trial and an early, clear offer matter more than the number of places the paywall appears.
More placements help only if each one meets the user at a moment when the value is obvious.

## 2. Our model and what exists today

- **Model:** metered freemium. Five free scripts, then Pro. Voice, Normal and Audio modes are free, so every user can
  feel the main value before the wall. Keep that.
- **[ours] Already built (2026-10-29):** locked Start for a sixth script, a blocked New script / Import / Duplicate, the
  upgrade sheet on app open (at most once every 24 hours, after the limit), the Studio card ("n of 5", "1 free script
  left", "All 5 free scripts used", with ×), a Pro row in Settings, and `source` on every sheet event (`start`, `card`,
  `settings`, `launch`, `save`).
- **[ours] Not built:** any trial or intro offer, any Pro-only feature, any placement at a moment of success, and
  purchases themselves (the buy button says it is not available yet; `proEnforced` is off in normal builds).

## 3. Placements to add, best first

| # | Placement | Type | Why it should convert | Needs |
|---|---|---|---|---|
| 1 | **Free trial on the yearly plan**, shown on the sheet and the card ("Start 7-day free trial") | Offer, not a new surface | Trials are the largest lever in the data above; trial-to-paid is about a third | A real introductory offer in App Store Connect and Google Play (the store draws the price and terms) |
| 2 | **Progress nudge before the wall:** "2 free scripts left" at 3 of 5 (the card already says "1 free script left" at 4 of 5) | Card text, not a modal | The user sees the limit coming and chooses; the wall is no surprise | Card change only |
| 3 | **Soft note after a success moment:** under the "Saved to your gallery" card after a recording, and after a finished read on the Read screen, for free users within two scripts of the limit: "2 free scripts left · See Pro" | One line, never a modal | Asked when the user has just had a good result | Camera and Read screen change; shares the 24 hour cooldown |
| 4 | **Pro badge on volume or convenience features:** a lock or "Pro" label; tapping opens the sheet and says what it unlocks | Inline gate | Intent is highest at the moment the user reaches for the feature | A decision on which features (section 4) |
| 5 | **Settings and Help:** keep the Pro row; mention Pro next to Restore Purchases | Always-there entry | Catches people who come looking | Already built |
| 6 | **A returning-user reminder:** the launch sheet and the card (built) | Timed | Brings back people who closed it once | Built |

Order of work: 1 (when store offers exist), 2, 3, then 4 after the feature decision. 5 and 6 are done.

## 4. Open decision: which features, if any, to gate beyond scripts

Rule of thumb [general]: gate **volume** (how much), not **capability** (whether it works at all), so every user feels
the product before paying. Candidates, with a recommendation:

| Candidate | Free | Pro | Recommendation |
|---|---|---|---|
| Scripts to save and present | 5 | unlimited | Already done |
| Saved recordings | first 3 takes | unlimited | **Recommended next**: recording is the feature people share and talk about, and a take cap is easy to explain |
| Recording quality | 1080p | higher, if the camera supports it | Possible later |
| Voice, Normal, Audio modes | all | all | Keep free: these are the product |
| Notch and corner placement, mirror, rotate, fonts | all | all | Keep free for now; revisit if conversion is low |
| Sections and notes (desktop) | all | all | Keep free |
| Sync or sign-in across devices | not built | Pro | Only when it exists (do not advertise it before) |

Whatever is gated must be unlocked only through in-app purchase (App Store 3.1.1), labelled with a lock or "Pro" badge
in the app, and named on the store listing (2.3.2).

## 5. What to avoid

- **A hard paywall in the first run.** It converts better on paper, but we decided on no paywall in onboarding, it
  works best with a trial, and it hurts the try-first promise.
  *Update 2026-11-11:* the owner reversed this for the questionnaire onboarding: a closable Pro sheet now ends the full
  tour (Skip still avoids it). See `onboarding-plan.md` §12.
- **Interrupting presenting or recording.** It is the worst moment and costs trust. The sheet never opens during a read
  or a take.
- **Promotional push or local notifications.** They need explicit opt-in (4.5.4).
- **Countdown timers, "% off" or "limited time" wording** unless a real store offer backs it (2.3.1(a), 3.1.2).
- **A paywall with no way out.** Every surface has a visible ✕ or Not Now, and the free scripts keep working.
- **Claims that are not true yet:** sign-in, "all your devices", sync. They were removed on 2026-10-29; do not add them
  back before the feature exists.

## 6. Rules that apply to every placement

1. **Two kinds of prompt.** *Wall prompts* (the user tried to do something Pro) always show. *Proactive prompts* (launch,
   after a success, a card) share one cooldown: at most one per session and one per 24 hours across all surfaces.
   Today `notePromptShown()` is recorded for every sheet, so this already holds for the launch sheet; the new proactive
   notes must check `launchPromptDue()` too.
2. **Same sheet everywhere** (`showPaywall`), with a `source` for the event log, so the numbers are comparable.
3. **Say what the user gets for this action**, in the reason line under the title ("You've used your 5 free scripts" /
   "Unlock unlimited recordings").
4. **Always dismissible,** no confirm-shaming wording on the close button.
5. **Prices and trial terms come from the stores.** The constants in `ProPrices` are placeholders and must go before any
   release with enforcement on.

## 7. Measuring what works

Events already logged: `upgrade_prompt_shown` and `upgrade_prompt_closed`, each with `source`. Add, once purchases exist:
`upgrade_plan_selected`, `purchase_started`, `purchase_completed`, `purchase_restored`, all with the same `source` and
the plan, and no script text. Read them as a funnel per source: shown → plan chosen → purchase started → purchased.
Change one thing at a time (trial on or off, reason wording, which placements) and compare over at least a few hundred
impressions. A paywall experiment tool (RevenueCat Experiments, or a remote-config flag) is worth adding after
purchases are connected, not before.

## 8. Order of work (not started)

1. Connect purchases and Restore (Phase 3 of `plan/cross-platform-plan.md`). Nothing below converts without it.
2. Create the introductory offer on the yearly plan in both stores and show its terms on the sheet and the card.
3. Add the "2 free scripts left" nudge and the soft note after a recording and after a finished read.
4. Decide the gated features (section 4) and add Pro badges that open the sheet with a specific reason.
5. Add the purchase funnel events and review them per source before adding more placements.
6. Read App Review Guidelines 5.6 and Google Play's subscription disclosure rules, publish the Terms and Privacy pages,
   and link them from the sheet (see `upgrade-prompts-strategy.md`, 6.4a).

## 9. Not checked

- The industry numbers are from secondary sources and from other apps; ours may differ a lot.
- I did not test any of these placements; none exist yet.
- I did not review Google Play's policy text on subscription offers and trials.

## Sources

- RevenueCat, subscription app trends and benchmarks 2026: https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026.md
- RevenueCat, the Android paywall gap: https://www.revenuecat.com/blog/engineering/android-paywall-gap
- SaaStr, top 10 learnings from RevenueCat's State of Subscription Apps: https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps/
- Airbridge, hard paywall vs freemium 2026: https://www.airbridge.io/en/blog/hard-paywall-vs-freemium-2026
- Airbridge, paywall conversion structural decisions: https://www.airbridge.io/en/blog/paywall-conversion-structural-decisions
