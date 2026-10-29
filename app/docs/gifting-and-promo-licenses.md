# Gifting Pro for marketing: what the reference app does, what others do, what we should build

Written 2026-10-29. Follows `payments-plan.md` (purchase layer, `in_app_purchase`, per-store switches).

Confidence tags: **[checked]** read in the decompiled reference app (`~/projects/vp-apk/work/jadx-out/sources/`).
**[general]** my knowledge of the stores and of common practice, **not re-checked on the vendors' pages in this session**.
Store limits and App Review wording change; verify every **[general]** line before relying on it (see section 7).

## 1. Short answer

- **The reference app has no gifting mechanism of its own.** No license keys, no redeem-code entry field, no server that
  grants access. Pro is whatever Google Play Billing says the Google account owns. **[checked]**
- Its only "redeem" feature is a row that opens `https://play.google.com/redeem`, Google's own page where a user types a
  Play promo or gift code. So its gifting is entirely Google Play promo codes. **[checked]**
- For us the best plan is layered:
  1. **Store codes first** (Apple offer codes, Google Play promo codes): zero code, compliant, work today with the
     `in_app_purchase` layer we already built. Good for time-limited gifts and one-code-per-person lifetime gifts.
  2. **Our own redeem code with a signed token** only for what the stores cannot do (one shared code for many people,
     lifetime for a group, Windows, press and partner kits), and only where store rules allow it.

## 2. What the reference app does (findings)

| Finding | Where | Meaning |
|---|---|---|
| Products: subscription `pro` (monthly, yearly plans) and in-app products `pro.lifetime`, `pro.lifetime.promo` | `defpackage/kr.java` ~518, ~567 | Plain Play Billing products, queried with `subs` and `inapp` |
| Purchased and acknowledged products set the Pro flag; state 2 (pending) is tracked separately | `defpackage/kr.java` ~495-540 | Entitlement = Play purchase list, nothing else |
| `pro.lifetime.promo` is a **second lifetime SKU at a lower price**, shown while a countdown runs | `kr.java` 544; `defpackage/dv.java` 79 ("Promo: n% Off Lifetime Ends In ..."); `defpackage/f90.java` 145, 281-284 | The "promo" is a **discount campaign**, not a gift. A `promoStartDate` stored locally starts a 24-hour window (1 hour in a debug flag). Anyone can clear app data and see it again |
| A Settings row opens `https://play.google.com/redeem` | `defpackage/p50.java` case 3 | Hand-off to Google's code-redemption page. After redeeming, the purchase appears in the next purchase query |
| Only network endpoints besides Google: TelemetryDeck analytics and a Notion privacy page | `defpackage/fh4.java`, `p50.java` | No licensing backend |
| `com/pairip/licensecheck/*` | whole package | Google's Play app-integrity/licence protection wrapper (checks the installed copy came from Play). It is anti-tamper, **not** a key system |

Conclusion: to give the reference app away, its owner would create Play promo codes in Play Console, or grant
licence-tester accounts. Nothing else exists.

## 3. What popular apps do

Grouped by distribution model. **[general]**

| Model | Typical gifting method | Examples of the pattern |
|---|---|---|
| Subscription app on the App Store / Play | Store offer or promo codes, shared on social, newsletters, creators | Most subscription apps (habit trackers, journals, language apps) hand creators and press an Apple offer-code link |
| Cross-platform app with its own account | Promo code entered in app or on a web page; the account holds the entitlement | Spotify, Duolingo, Notion-style plans: gift cards and promo codes tied to an account |
| Indie Mac app sold outside the Mac App Store | **Licence keys** (Gumroad, Lemon Squeezy, Paddle, Keygen) | Many Mac utilities; keys for press, giveaways and bulk deals |
| Apps using RevenueCat | **Promotional entitlements** granted from the dashboard or REST API to an app user id, for a duration or lifetime; plus store offer codes | Common for support gifts and influencer deals |
| Bundles / marketplaces | Third party hands out unique codes | Setapp, AppSumo-style lifetime deals (a unique code per buyer redeemed in the app) |

Takeaways:
- **Stores' own codes are the default for marketing** because Apple and Google require digital goods to be sold through
  their billing, and codes ride on top of that.
- **Your own key/code system is normal only where the app is not bound to a store** (direct Mac downloads, Windows) or
  when there is an account system (the entitlement lives on a server).
- Almost nobody ships a **single static key that unlocks everyone forever**: it leaks and cannot be revoked.

## 4. What the stores give us today

### 4.1 Apple (iPhone, iPad, Mac App Store) **[general, verify limits]**

- **Offer codes for auto-renewing subscriptions**: a free period (for example 1 or 3 months, or 1 year) or a
  discounted price. Two kinds:
  - **One-time-use codes**: unique, generated in bulk, each works for one person once.
  - **Custom codes**: a human-readable word chosen by us (for example `ECHOLAUNCH`), **reusable by many people** until a
    redemption cap or expiry date we set. This is the "one code for multiple users for a limited time" case.
- **Offer codes for in-app purchases such as our lifetime non-consumable**: Apple extended offer codes beyond
  subscriptions in 2025, so a code can grant the lifetime product for free (or discounted). Check in App Store Connect
  whether it allows reusable custom codes for this product type or only one-time-use codes. **Unverified.**
- Redeem by link (`https://apps.apple.com/redeem?ctx=offercodes&id=<appId>&code=<CODE>`), by typing it in the App Store
  redeem screen, or **in our app** with the StoreKit redeem sheet. A "Redeem code" row in Settings is allowed and
  encouraged. The `in_app_purchase` plugin may not expose the sheet directly; it can be a small platform channel or the
  redeem URL via `url_launcher`.
- Needs the Apple Developer account and products set up (see `payments-plan.md` section 8).
- Apple also lets a developer give TestFlight access and reviewer access; those are separate from marketing gifts.

### 4.2 Google Play (Android) **[general, verify limits]**

- **Promo codes for in-app products** (our lifetime item): unique one-time codes generated in Play Console, with a
  per-quarter cap per app. Redeemed at `play.google.com/redeem` or in the Play Store app. This is what the reference app
  relies on.
- **Subscriptions**: offers with **developer-determined eligibility** and **custom codes** (reusable, with a redemption
  limit and an expiry), plus free trials.
- **Licence testers** (Play Console): accounts that get purchases free; for internal testing and trusted reviewers, not
  public marketing.
- Needs the Play Console account and published products.

### 4.3 What the stores cannot do for us

| Wish | Stores |
|---|---|
| Time-limited gift to many people with one code | **Yes**, subscription custom codes (Apple and Google) |
| Lifetime gift, one code per person | **Yes**, one-time codes (Apple if offer codes cover non-consumables, Google promo codes) |
| **Lifetime gift, one shared code for many people** | **Not natively** (shared custom codes are for subscriptions). Workaround: model "lifetime" as a free-forever subscription offer is not allowed, so needs our own mechanism |
| Code that works on **all platforms** (iOS, Android, Windows) | **No**, each store has its own codes; Windows has no store integration yet |
| Revoke or expire a lifetime gift later | **No**, once granted it is a normal purchase |
| Know who redeemed (for marketing attribution) | Only aggregate counts per code |

## 5. Our own redeem code system (for the gaps)

### 5.1 Rules to respect first **[general, read the current guidelines]**

- **Apple App Review 3.1.1** says apps may not use their own mechanisms (licence keys, QR codes, and similar) to unlock
  features. In practice, apps that **only accept codes tied to a login/account, or that unlock nothing a paid user would
  not get elsewhere**, are judged case by case, and rejection is a real risk. Safest approach on Apple: **use Apple offer
  codes inside the iOS, iPadOS and macOS builds, and keep our own codes out of those builds** (or ship them only after a
  clear answer from App Review).
- Apple 3.1.3(b) lets an app grant access to something a user bought elsewhere if the app also offers it as IAP;
  so a code purchased on our web shop is the more defensible shape than a free code, but still needs checking.
- **Google Play** policy requires Play Billing for digital goods sold in the app. Free promotional grants from our own
  codes are generally less sensitive, but anything involving payment outside Play needs the user-choice-billing rules.
- **Windows** and any **direct-download Mac build** have no such restriction.
- Whichever we choose, record the decision here.

### 5.2 Recommended design: signed grant tokens, validated by a tiny server

Goal: one code, many users, limited time or lifetime, revocable, no per-user accounts.

1. **Code table** (a few rows, in a small database or even a JSON file behind a serverless function; the `web/` site is on
   Netlify, so a Netlify Function works):

   | field | example |
   |---|---|
   | `code` | `ECHOLAUNCH`, or random `EP-7K2Q-9XMD` for one-time codes |
   | `grant` | `lifetime` or `pro_for_days: 90` |
   | `max_redemptions` | 500 (null for unlimited) |
   | `redeem_by` | 2027-03-31 (last day the code can be entered) |
   | `campaign` | `youtube-creator-x` (for attribution) |
   | `revoked` | false |

2. **App flow**: Settings → "Redeem code" → user types it → app sends `{code, installId}` (a random id stored on the
   device, not personal data) to the function.
3. **Server** checks the table, counts the redemption against `max_redemptions` per distinct `installId`, and returns a
   **signed token** (Ed25519 JWT-style): `{plan, grantedAt, expiresAt|null, installId, campaign}`.
4. **App verifies the token offline** with a public key embedded in the build, stores it in the preferences next to the
   cached plan, and `ProNotifier` treats it as another source of Pro. Nothing needs a network call after redemption, so
   it works offline, which matches the app's privacy stance.
5. **Expiry**: the token's `expiresAt` is checked on launch; when it passes the plan returns to free. For a lifetime gift
   `expiresAt` is null.
6. **Revocation** (leaked code): set `revoked`, so no new redemptions. Already-issued tokens stay valid (acceptable for
   marketing). If revocation of issued tokens is ever needed, add an optional re-check on launch with a grace period.
7. **Clock tampering**: a device clock set back extends a time-limited gift. For marketing that is acceptable; stricter
   protection would store the last seen server time.

Where it touches our code (`app/lib`):
- `services/purchases/purchase_service.dart`: add a `GrantService` (or a second `PurchaseService` source) that exposes the
  granted plan. `entitlement` merges "highest of store plan and granted plan".
- `features/pro/pro_state.dart`: `ProNotifier.setPlan` currently stores one plan from the store; add a separate
  `grantedPlan` and `grantExpiry` so a store restore does not erase the grant and the grant does not hide a real
  purchase. Per CLAUDE.md, trace every reader of `plan`: the paywall, the upgrade card, the free-script limit, Settings
  and the launch prompt.
- Settings screens (`mobile_settings.dart`, `preferences_screen.dart`): a "Redeem code" row; on Apple builds it opens
  the Apple redemption flow instead, per section 5.1.
- Per-store switch: add a `GRANTS_ENABLED` define beside `PAYMENTS_APPLE` / `PAYMENTS_ANDROID` so Apple builds can leave
  our own codes off.

### 5.3 Alternatives to building the server

| Option | Pros | Cons |
|---|---|---|
| **RevenueCat promotional entitlements** | Grant a duration or lifetime from the dashboard or API, per user; works across stores; revocable. Also supports redeeming store offer codes | A vendor and a fee at scale; needs an app user id per user; we chose `in_app_purchase` over it in `payments-plan.md` section 7. Adding it later is one more `PurchaseService` implementation |
| **Licence-key vendor** (Lemon Squeezy, Paddle, Keygen, Gumroad) | Ready-made key generation, activation limits, expiry, revocation. Good for Windows and a direct Mac build | Another vendor; not for store builds under 5.1 |
| **Static key list shipped in the app** | No server | Leaks on first decompile (we just decompiled an app in minutes); cannot revoke; **do not do this** |
| **Hash-checked offline codes** (code encodes plan and expiry, checked with a secret/public key, no server) | No server, no network | Cannot cap redemptions or revoke; a leaked code works forever on unlimited devices. Only for tiny private batches |

## 6. Recommendation

Do these in order; each is independent.

1. **Now, no code**: when the accounts exist, create the marketing offers in the stores:
   - Apple: a custom (reusable) code on the subscription for "N free months", one-time-use batches for the lifetime
     product if allowed.
   - Google: promo codes for the lifetime product, custom codes for subscription offers.
   Add a "Redeem code" row to Settings that opens the store redemption (Apple redeem URL or sheet, Google
   `https://play.google.com/redeem`, as the reference app does). This is a small change.
2. **Windows (and any direct Mac build)**: build the signed-token redemption in 5.2, since there is no store to carry codes.
3. **Shared lifetime code for a group** (partners, a conference, reviewers): either issue many one-time store codes
   (simplest), or accept the 5.2 token system on non-Apple builds.
4. **Do not ship Apple builds with our own unlock codes** until the 3.1.1 question is answered in writing by App
   Review or the current guidelines clearly allow it.
5. Keep **reviewer access** separate: give App Review and Play reviewers an offer code or licence-tester account.

Two requested shapes, mapped:

| Need | Best fit |
|---|---|
| One code, many users, **limited time** | Custom code on the subscription (Apple, Google); on Windows, a 5.2 code with `pro_for_days` and `max_redemptions` |
| One code, many users, **lifetime** | Not available from the stores. 5.2 code with `lifetime` on non-Apple builds, or batches of one-time store codes |
| One code per person, lifetime | One-time Apple and Google codes |

## 7. Not checked (verify before building)

- Current Apple offer-code limits, code expiry rules, and whether offer codes can be reusable for **non-consumables**.
- Current Google Play promo-code quotas and custom-code redemption caps.
- Exact current wording of App Review 3.1.1 and 3.1.3 and Play's payments policy for free promotional unlocks.
- Whether the `in_app_purchase` plugin exposes the Apple redeem sheet (otherwise a platform channel or the redeem URL).
- Whether you want this to also support sending a gift to a specific person from the paywall (a consumer "gift Pro"
  purchase). That is a different feature: neither store has a native gift-an-in-app-purchase flow for this, so it would
  need a web checkout.
- Reference-app findings are from static decompiled code only; I did not run it or test Play promo codes against it.

## 8. Basic plan for now (Apple only, before the Developer account)

Decision 2026-10-29: Android is ignored for now. Build only the small seam below; the rest waits for the Apple
Developer Program account. Once we have apple developer account then we do this section 8 completely for apple. We will check for android later when we are publishing for them.

### 8.1 Does Apple need the paid account? **[general, verify price]**

Yes, for everything real. The Apple Developer Program costs **99 USD per year** (an individual or an organisation). Without
it you cannot:
- create in-app purchase products in App Store Connect (monthly, yearly, lifetime) or offer codes for them;
- use sandbox testers or TestFlight with real store purchases;
- publish to the App Store or Mac App Store.

What works **without** the account (already covered in `payments-plan.md` section 2):
- the debug fake store (`ENFORCE_FREE_LIMIT`), which exercises the whole paywall, limit and Restore flow;
- an Xcode **StoreKit configuration file** on the simulator or a Mac build, which simulates products, trials, renewals
  and refunds locally. It can also test the code-redemption sheet in Xcode's transaction manager, but not real offer
  codes, because those exist only in App Store Connect.

So payments and Apple offer codes cannot be finished or tested for real until the account exists. Everything else can be
prepared now.

### 8.2 Build now (no account, no server)

1. **`grantedPlan` and `grantExpiry` in `ProNotifier`** (`lib/features/pro/pro_state.dart`). Both empty for now. The
   effective plan is the higher of the store plan and the granted plan, and a store restore must not erase the grant.
   Trace every reader of `plan` (paywall, upgrade card, free-script limit, Settings, launch prompt) so none shows a stale
   value. This is the seam a future redeem-code system plugs into.
2. **A random `installId`** saved once in preferences. Not personal data. A future server needs it to count redemptions.
3. **A "Redeem code" row in Settings** (`mobile_settings.dart`, `preferences_screen.dart`), shown only on iOS, iPadOS and
   macOS, and only when `PAYMENTS_APPLE` is on. It stays hidden until the account exists because its target (the redeem
   URL or StoreKit sheet) needs the App Store app id. Following `CLAUDE.md`, do not offer it where it has nothing to do.

Not now: the signed-token server, RevenueCat, license-key vendors, a gift-to-a-friend purchase. See sections 5 and 6;
section 5.1 also says Apple builds should not ship our own unlock codes.

### 8.3 Do once the Apple Developer account exists

1. Finish the Paid Applications agreement, tax and bank details; create the three products with the ids in
   `ProProductIds` (`payments-plan.md` section 8 has the full check).
2. Create offer codes in App Store Connect: a reusable custom code on the subscription for "N free months"; one-time
   codes for the lifetime product if Apple allows offer codes for non-consumables (section 4.1, unverified).
3. Wire the "Redeem code" row to the Apple redemption flow: the redeem URL with the app id through `url_launcher`, or the
   StoreKit redeem sheet through a small platform channel. After redemption, the app must refresh through the existing
   `restore()` path so the new entitlement appears.
4. Test with a sandbox tester and TestFlight, and give App Review an offer code or demo access.
