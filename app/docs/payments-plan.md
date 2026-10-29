# Payments: when to connect them, how to test them, and which SDK

Written 2026-10-29. Sections 1 to 5 are the analysis and plan. **Section 7 records what was built** (purchase layer,
per-store switches, debug fake) and what is still untested against the real stores. It follows
`upgrade-prompts-strategy.md` (the prompts we built) and `paywall-placement-strategy.md` (where else to show them).

Confidence tags: **[general]** common practice or my own knowledge of the stores, not re-checked in this session.
**[checked]** read on the vendor's page on 2026-10-29. **[secondary]** from a write-up, not the vendor.

## 1. Is it the right time? Yes: before the first submission

- **App Review needs a working purchase.** A buy button that says "isn't available in this build yet" is an incomplete
  feature (2.1) and an unlock without in-app purchase (3.1.1) [general]. Reviewers try the purchase flow.
- **The first in-app purchases are reviewed with the app** and attached to that version [general], so adding them
  later costs a resubmission.
- **Everything we built depends on it.** The 5-script limit, the sheet, the card and the blocked New script only make
  sense once a user can pay. Until then `proEnforced` stays off in normal builds.
- **Changing terms later hurts.** Shipping 1.0 free and adding a limit afterwards costs early users and ratings. The
  alternative is to launch 1.0 fully free on purpose, to collect reviews, and add Pro in 1.1; it is faster but you give
  up early revenue and need to tell users the plan.
- **Testing takes time.** Restore, cancel, refund, renewal and a trial each need a real round trip in a sandbox.

## 2. Can we make it work in test mode? Yes, in three levels

| Level | What it needs | What it proves |
|---|---|---|
| 1. **Debug fake** | Nothing | Buy, Pro, limit lifted, Restore, errors, on emulators. A `PurchaseService` interface with a fake implementation compiled only into debug builds. (We already have a debug "Preview Pro plan" switch in Settings; this replaces it with real flows.) It is not a hidden unlock because it is absent from release builds. |
| 2. **Local store simulation** | Apple: an Xcode **StoreKit configuration file** (fake products, trials, renewals, refunds; no account or agreements needed). Android: none | Real StoreKit code paths on the iOS simulator and a Mac build. Google has no local equivalent. |
| 3. **Real stores, test money** | Apple Developer Program, Paid Applications agreement, tax and bank details, products in App Store Connect, **sandbox testers** and **TestFlight**. Google Play Console, products in Play Console, the app on the **Internal testing** track (signed build, same application ID), testers added as **licence testers** | The real thing: prices in local currency, trials, renewals on an accelerated clock, Restore on a second device. Google cannot be tested without uploading a build. |

Windows uses the Microsoft Store, which is a different purchase system and is out of scope here.

## 3. Which SDK? RevenueCat or Flutter's `in_app_purchase`

You asked for the most flexible option, with the most support, that the industry follows, and to ignore the data
question. With that, my recommendation changes from my earlier message (which leaned on keeping data on the device):

**Use RevenueCat (`purchases_flutter`), and put it behind our own `PurchaseService` interface.**

### 3.1 What each one is

- **`in_app_purchase`** is Flutter's official plugin. It wraps StoreKit and Play Billing. It uses StoreKit 2 by default
  on iOS and macOS [secondary: package README and changelog]. It gives you products, buying and a purchase stream; **you**
  build entitlement logic, restore handling, trial eligibility, receipt or token verification and any analytics. Offer
  codes and promotional offers have partial or newer support. It is maintained by the Flutter team, free, and has no
  commercial support.
- **RevenueCat** is a service plus SDK that sits on top of the same store APIs. It keeps the entitlement ("is this
  user Pro?") on its servers, verifies receipts for you, restores purchases, exposes trial eligibility, and adds
  charts, experiments, remotely configured paywalls and integrations.

### 3.2 Side by side

| | `in_app_purchase` | RevenueCat |
|---|---|---|
| Cost | Free | Free up to $2,500 monthly tracked revenue, then 1% of tracked revenue [checked: revenuecat.com/plans]. Paywalls, web funnels and A/B tests are an extra 1% on conversions from those tools [checked] |
| Entitlement logic (Pro yes/no) | You write it | Built in, one "entitlement" across iOS, Mac and Android |
| Receipt and token verification | You write and host it (or trust the device) | Done for you |
| Restore, family sharing, refunds, grace periods | You handle each case | Handled by the SDK and server |
| Trials and intro-offer eligibility | You query the stores yourself | Provided |
| Paywall A/B tests, remote config of offers and prices | Not available; every change is an app update | Built in (the plan in `paywall-placement-strategy.md` needs this to measure placements) |
| Analytics | None; you log events yourself | Revenue, trial, churn and conversion dashboards |
| Support | Flutter issue tracker | Email and technical support forums on the paid plan [checked]; dedicated support and SLAs on Enterprise [checked] |
| Cross-platform entitlement (a Mac purchase also unlocks Android) | No | Yes, if you add accounts later |
| Platforms | iOS, Android, macOS | iOS, Android, macOS and web billing (I believe; check Windows support before relying on it) [general] |
| Vendor risk | None | A service dependency (outages, pricing changes). The SDK caches the entitlement on the device, so a short outage does not lock out a paying user [general] |

### 3.3 Is RevenueCat the industry standard?

For subscription apps built by small and mid-size teams, it is the most widely used third-party purchase layer I know
of [general] (but see 3.3a: the reference app does not use it). The industry reports quoted in `paywall-placement-strategy.md` are RevenueCat's own, built from about
115,000 apps on its platform [secondary: SaaStr summary], which shows its reach but is also a vendor's own data.
Alternatives exist: **Adapty** (strong on paywall experiments), **Qonversion** (positioned as a lower-cost option), **Superwall** (paywall-focused),
**Apphud** [secondary: comparison blogs, which are vendor-adjacent]. Large teams often build their own server-side
layer on Apple's and Google's server APIs.

### 3.3a What the reference app actually uses (checked 2026-10-29)

It does **not** use RevenueCat. It talks to the stores directly.

- **Android [read in the decompile]:** Google's Play Billing Library (`com.android.billingclient`, with the `billing` and
  `billing-ktx` libraries in its resources; no RevenueCat, Adapty, Qonversion or Superwall classes anywhere in the
  decompiled sources). Products seen: `pro.lifetime`, `pro.lifetime.promo` and a subscription product `pro`
  (`defpackage/ar.java`). The Pro state is cached on the device in SharedPreferences (`isProCached`,
  `proEntitlementIsLifetime`, `proEntitlementVerifiedAt`) and re-checked against Play (`defpackage/kr.java`). There is no
  licence server: the only network hosts in the code are TelemetryDeck (analytics), a Notion page and YouTube.
- **macOS [privacy notice]:** "Payments are handled exclusively by Apple via In-App Purchases ... Apple provides us only
  with anonymous transaction identifiers", "local receipt verification", and "We use no third-party analytics or
  tracking SDKs". That is native StoreKit, not RevenueCat. iPhone and iPad are not covered by the notice.
- **Android analytics:** purchase events (product, plan, amount, currency, country) go to TelemetryDeck, not to a
  billing vendor.

So a solo developer with a working paid app does it directly, with a device-side cache and no backend. That makes
`in_app_purchase` a proven path, not a risky one. It also means "industry standard" is too strong for RevenueCat:
it is the most common choice for teams that want experiments, dashboards and less billing code, not a requirement.
The choice is between **less code and built-in experiments (RevenueCat, 1% above $2,500 a month)** and **no vendor,
no fee, more code to write and maintain (`in_app_purchase`, as the reference app does)**. My recommendation stays
RevenueCat behind `PurchaseService` because you asked for flexibility and support, but the direct route is a
reasonable choice, and the interface makes starting direct and adding RevenueCat later cheap.

### 3.4 Cost, in plain numbers

Fees are on top of the store's own cut (15 to 30%). At $2,500 of monthly tracked revenue or less, RevenueCat is free. At
$10,000 a month it is about $100 a month (1%). The extra 1% for paywall experiments applies only to the revenue those
tools convert. For a first app this is small next to the time it saves; check the plans page again before launch
because pricing moves.

### 3.5 What stays true either way

- Apple and Google still take their cut, and the stores still own billing, refunds and receipts.
- You still create the products in App Store Connect and Play Console, and still need the accounts and agreements.
- **Privacy forms still change.** RevenueCat receives an anonymous app user id and purchase information, so the App
  Store privacy label, Play Data safety form and our privacy text must say so. You decided data sharing is not a
  concern here, but the disclosures are still required.
- Keep the SDK behind `PurchaseService` so a later switch to `in_app_purchase` or another vendor touches one file.

## 4. Plan

1. **Decide products and IDs** (same in both stores): monthly, yearly with an introductory free trial, lifetime
   (non-consumable). Set prices in the stores.
2. **Accounts:** Apple Developer Program and agreements; Google Play Console. (Needs you.)
3. **`PurchaseService` interface** (current plan, offerings with price and trial, buy, restore, manage subscription,
   a stream of changes) with a **debug fake**. Wire `ProState.plan` and the sheet's buy and Restore buttons to it. This
   unblocks emulator testing and replaces the debug "Preview Pro plan" switch.
4. **RevenueCat implementation** of the interface; configure the project, entitlement, offerings and API keys per
   platform (public SDK keys; keep them out of source control if you add secrets later).
5. **Apple:** add the In-App Purchase capability in Xcode (iOS and macOS); create the StoreKit configuration file;
   test on the simulator and a Mac build, then sandbox and TestFlight. Use **Universal Purchase** (one app record for
   iPhone, iPad and Mac) if you want one purchase to cover all three.
6. **Android:** upload a signed build to Internal testing, add licence testers, test on a Play Store emulator image.
7. **Replace placeholders:** `ProPrices`, the "SAVE 34%" badge and "From €4.58 a month" must come from the store;
   add trial wording from the real intro offer; publish Terms and Privacy pages and link them on the sheet.
8. **Handle the edge cases:** cancel, pending, refund, renewal, grace period, offline entitlement cache, the "check at
   least every 30 days" alert that already exists in `paywall_dialog.dart`.
9. **Turn `proEnforced` on** for release builds only after steps 3 to 8 pass on both stores, and keep the debug fake out
   of release builds.
10. **Add the purchase events** (`plan_selected`, `purchase_started`, `purchase_completed`, `purchase_restored`, each with
    the surface) and read them per placement (see `paywall-placement-strategy.md`, section 7).

## 4a. What can be done before the Apple Developer account (about a week away)

Most of it. Only the Apple store side is blocked.

| Work | Needs an Apple account? |
|---|---|
| `PurchaseService` interface, debug fake, wiring the sheet, card, Restore and Manage buttons, entitlement cache, edge-case handling, the purchase events | No |
| Apple StoreKit configuration file and testing on the iOS simulator and a Mac build | No, I believe (a local file in Xcode); real devices and signing the capability may need a team [general, check] |
| Android: Play Billing code, products, Internal testing, licence testers | No Apple account, but it needs a **Google Play Console** account (a one-time fee). Start it now. |
| RevenueCat project, entitlement, offerings, Android app | No Apple account (Apple needs one more key later) |
| Creating the in-app purchases and the trial in App Store Connect, sandbox testers, TestFlight, the Paid Applications agreement, tax and bank details, Universal Purchase | **Yes** |
| Submitting the app with the purchases attached | **Yes** |

Advice:
- **Enrol in the Apple Developer Program now, not in a week.** Approval can take days, and the Paid Applications agreement,
  tax and bank checks take more. They gate the sandbox, so waiting just moves the delay to later.
- **Check Google's rules for a new personal developer account** before planning the Android launch date. I recall that new
  personal accounts must run a closed test with a minimum number of testers for about two weeks before production
  access [general; verify on Play Console help]. Start that clock early.
- Build and test everything in the first group in this week so that only product creation and sandbox runs remain when
  the Apple account arrives.

## 5. Open questions for you

1. Do you have Apple Developer and Google Play Console accounts yet? Step 2 blocks steps 4 to 6.
2. Is the product set right (monthly, yearly with trial, lifetime)? Prices are placeholders today (monthly €6.99, yearly
   €55, lifetime €109.99).
3. One app record for iPhone, iPad and Mac (Universal Purchase), or separate? The bundle ID is already shared
   (`com.echoprompter.app`).
4. Do you want Windows covered in this round? It would need the Microsoft Store's own purchase API.

## 6. Not checked

- Store rules are from my own knowledge and the guidelines page read earlier; re-read them when submitting.
- I did not check RevenueCat's current Flutter and macOS support in its docs, or whether it has a local "test store" that
  avoids store setup; check the docs before step 4.
- RevenueCat's pricing is from its plans page on 2026-10-29. Third-party listings showed different free-tier numbers
  (for example $1,000 and $10,000), so use the vendor's page.
- No purchase code was written or run for this document.

## 7. Built (2026-10-29): purchase layer, per-store switches, debug fake

Decision taken: **Flutter's `in_app_purchase`** (as the reference app does with the native billing APIs), no RevenueCat. The
code sits behind `PurchaseService`, so RevenueCat could be added later by writing one more implementation.

### 7.1 The two switches

Apple and Android go live independently. Both default to **off**.

| Build flag | Effect |
|---|---|
| `--dart-define=PAYMENTS_APPLE=true` | iPhone, iPad and Mac use StoreKit; the free-script limit is enforced there |
| `--dart-define=PAYMENTS_ANDROID=true` | Android uses Google Play Billing; the limit is enforced there |
| `--dart-define=ENFORCE_FREE_LIMIT=true` | Developer only: enforce the limit and use the debug fake store, no store account needed |
| none | Everything stays free, no limit, no prompts (fail-open: nobody is locked out when no store can sell Pro) |

The switch is per platform: `PAYMENTS_APPLE=true` does nothing on Android and `PAYMENTS_ANDROID=true` does nothing on
Apple (tested). Windows never turns payments on. Your sequence works as written: build the Apple releases with
`PAYMENTS_APPLE=true`, ship them, and keep Android builds without a flag until its Play Console account and products
exist; then add `PAYMENTS_ANDROID=true`.

**Release checklist item:** a release build made without its flag is free with no limit. Always pass the flag for the
store you are shipping to, and check the Upgrade card appears on a fresh install.

### 7.2 Where the code is

| File | What it does |
|---|---|
| `lib/core/entitlements/entitlements.dart` | the switches, `storePaymentsLive`, `proEnforced` |
| `lib/services/purchases/purchase_service.dart` | `PurchaseService` interface, product ids, `ProOffer`, `UnavailablePurchaseService`, `purchaseServiceProvider`, `proOffersProvider` |
| `lib/services/purchases/store_purchase_service.dart` | the real store through `in_app_purchase` (StoreKit and Play Billing) |
| `lib/services/purchases/fake_purchase_service.dart` | debug-only fake store (buy, cancel, pending, fail, restore, survives restart) |
| `lib/features/pro/pro_state.dart` | `ProNotifier` listens to the service, sets and caches the plan |
| `lib/features/pro/paywall_dialog.dart` | store prices, buy, restore, busy and error states, "SAVE n%" computed from the store amounts |
| `lib/features/pro/purchase_actions.dart` | Restore and Manage from Settings; the debug "next test purchase" control |
| Settings (mobile and desktop) | Restore Purchases and Manage subscription now call the service |

Which service a build uses: the real store when its switch is on; the **debug fake** in debug builds with the switch off;
nothing (buying says it is not available) in release builds with the switch off. The fake is compiled in only for
debug builds, so it cannot unlock Pro in a release.

Product ids (same in App Store Connect and Play Console): `echoprompter.pro.monthly`, `echoprompter.pro.yearly`
(auto-renewing subscriptions), `echoprompter.pro.lifetime` (non-consumable). They are constants in `ProProductIds`.

Two extra dependencies were added: `in_app_purchase` and `url_launcher` (the Manage subscription link on phones).

### 7.3 Tested

Android emulator, debug builds:
- Fake store: the sheet shows the placeholder prices and a computed "SAVE 34%"; Subscribe shows a spinner, then "Pro is on.
  Thank you!", closes the sheet and removes the upgrade card; New script works again; Pro survives a restart with no
  card and no launch sheet.
- `PAYMENTS_APPLE=true` on Android: nothing changes ("Free plan · 5 of 5", no lock, no sheet).
- `PAYMENTS_ANDROID=true` on Android with no Play products: the limit is enforced, New script opens the sheet, and the
  sheet says "The store did not answer, so prices are not available right now." with Try again; the buy button is
  disabled; no crash.
- iOS simulator with `PAYMENTS_APPLE=true`: the same graceful state on the real StoreKit path (no products configured).
- Compile: `flutter build ios --simulator` and `flutter build macos` with `PAYMENTS_APPLE=true`; `flutter analyze` clean.

### 7.4 Not tested, and must be before release

- **`StorePurchaseService` has never talked to a real store.** It follows the package API but needs products in App Store
  Connect or Play Console (or an Xcode StoreKit configuration file) to run end to end.
- **Expiry and refunds are not handled.** The service never downgrades a plan by itself, so a lapsed subscription would
  stay Pro on the device. Real-store testing is needed to decide how to detect it (for example re-checking at least every
  30 days, with the existing `showSubscriptionCheckAlert`). Lifetime is not affected.
- **Apple Restore** prompts for the Apple ID; the service does not call it at launch on Apple, only when the user presses
  Restore. Check that purchases made on another device arrive without it.
- **Introductory free trial** is not wired (the sheet shows no trial). It needs the real offer and
  `GooglePlayPurchaseParam` offer tokens on Android.
- **"About X a month"** shows only with placeholder prices; real store prices show "billed every year" until locale-correct
  formatting is added.
- **In-App Purchase capability** must be added in Xcode (iOS and macOS) when the Apple account exists, and the macOS
  app is already sandboxed with network access.
- **Terms of Use and Privacy Policy links** on the sheet (no pages exist yet).
- A StoreKit configuration file for local Apple testing (created in Xcode) is still to do; it does not need an account.

## 8. Full integrated check once the accounts exist (Apple first, Google later)

Order agreed: ship Apple first with `PAYMENTS_APPLE=true`, and only then apply for Google Play Console and add
`PAYMENTS_ANDROID=true` (see 7.1). Each store is checked on its own; the other flag stays off.

### 8.1 Apple: macOS, iOS and iPadOS

What can be done **before** the Apple Developer account (no account needed, I believe; confirm in Xcode):
- Create an Xcode **StoreKit configuration file** with the three products (monthly, yearly with an introductory free trial,
  lifetime) and run the simulator or a Mac build against it. This exercises `StorePurchaseService` for real: prices from
  the file, buy, cancel, renewal, refund, trial, Restore.
- Fix what that shows (section 7.4: expiry and refund handling, the trial, "about X a month" formatting, Apple Restore).

What **needs** the account:
1. Enrol in the Apple Developer Program (do this early; approval takes time) and accept the Paid Applications agreement,
   with tax and banking details. These gate sandbox purchases.
2. Create the three in-app purchases in App Store Connect with the ids in `ProProductIds`, prices, the free trial as an
   introductory offer, and the review screenshot and notes.
3. Add the In-App Purchase capability in Xcode for iOS and macOS. Use one app record for iPhone, iPad and Mac if you want
   **Universal Purchase** (one purchase covers all three).
4. Test with **sandbox testers** and **TestFlight** on a real iPhone or iPad and a Mac: real prices and currency, trial,
   renewal on the accelerated sandbox clock, cancel, refund, Restore on a second device, buying again as an existing
   subscriber, family sharing if enabled.
5. Check the whole path with `--dart-define=PAYMENTS_APPLE=true`: fresh install shows no limit until five scripts are
   used; the sixth is blocked with the sheet; buying turns Pro on everywhere; reinstalling and pressing Restore brings it
   back; the Keychain count survives deletion (`free-script-limit-persistence.md`).
6. Publish Terms of Use and Privacy Policy pages and link them from the sheet and the store listing; update the privacy
   label (the free-script count in the Keychain is on-device; purchases go through Apple).
7. Submit the app with the in-app purchases attached, review notes explaining how to reach the sheet (save five scripts, then
   create a sixth) and the sandbox account. Read App Review Guidelines 5.6 first.

### 8.2 Google Play (Android), after Apple is live

There is no local equivalent of the StoreKit file, so real Android testing needs the Play Console account.
1. Create a Google Play Console developer account (one-time fee, identity checks). I recall that **new personal accounts
   must run a closed test with a minimum number of testers for about two weeks before production access**; I did not
   verify this, so read Play Console help before planning the Android launch date.
2. Create the app, then the in-app products with the **same ids** (subscriptions with base plans and the free-trial offer;
   lifetime as a one-time product).
3. Upload a **signed** build (same application ID, `com.echoprompter.app`) to the **Internal testing** track and add
   **licence testers**, who buy for free.
4. Test on a device or an emulator image with the Play Store, signed in as a tester, using
   `--dart-define=PAYMENTS_ANDROID=true`: prices, buy, cancel, pending, refund, Restore after reinstall, subscription
   renewal and lapse. Android restores owned purchases silently at launch (see `StorePurchaseService`); confirm that on a
   fresh install.
5. Check how Android backup interacts: the free-script count restores with Auto Backup (`free-script-limit-persistence.md`),
   so test a reinstall from the Internal testing track with and without Google backup.
6. Fill in the Play **Data safety** form (purchases through Google Play) and the store listing's in-app purchase
   disclosure, then promote the build to production.

### 8.3 Checks that apply to both

- `ProState.plan` must come back correctly after a restart while **offline** (the last answer is cached under
  `EchoPrompter.proPlan.store.v1`).
- A lapsed or refunded subscription must stop being Pro (not implemented yet, section 7.4).
- Every upgrade surface keeps its close button and the free scripts keep working after it is closed.
- The debug fake is not in the release build: in a release without a switch, buying says it is not available; with a
  switch, only the real store can grant Pro.

## Sources

- RevenueCat plans and pricing (checked 2026-10-29): https://www.revenuecat.com/plans/
- Flutter `in_app_purchase` README: https://flutter.googlesource.com/mirrors/packages/+/HEAD/packages/in_app_purchase/in_app_purchase/README.md
- `in_app_purchase_storekit` changelog: https://pub-web-s2.flutter-io.cn/packages/in_app_purchase_storekit/changelog
- SaaStr, top 10 learnings from RevenueCat's State of Subscription Apps: https://www.saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps/
- RevenueCat alternatives (comparison blogs): https://dodopayments.com/blogs/revenuecat-alternatives/ and https://theapplaunchpad.com/blog/revenuecat-alternatives/
