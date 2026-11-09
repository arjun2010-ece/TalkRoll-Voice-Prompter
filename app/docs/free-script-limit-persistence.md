# How the reference app keeps its free-script count across reinstalls, and what we should do

Written 2026-10-28. Analysis only: no app code was changed.

Question: the owner used up the reference app's 3 free scripts, uninstalled it, reinstalled it, and it still showed
3/3 used. How does it remember? Device settings, a database, a server?

Confidence tags: **[read]** read directly in decompiled code. **[inferred]** reasoned from what was read, not run.
**[not verifiable]** the code is not available to us.

## 1. What the Android code does

Decompile location (from `voice-tracking-handoff.md`): `~/projects/vp-apk/work/jadx-out/sources/`; the decoded
manifest and resources were produced separately with `jadx --no-src`.

### 1.1 The counter lives in ordinary app storage [read]

- The count is an integer in the app's private SharedPreferences file `voiceprompter`, under the key
  `customScriptsCreated` (`defpackage/va3.java`, around line 1332). Opened by `context.getSharedPreferences(
  "voiceprompter", 0)` (`defpackage/uy2.java`, line ~650).
- A second flag in the same file, `hasUsedFreeEdit`, records that the one free edit has been used.
- The label is built from that value: `"<n> of 3 free custom scripts used."` (`defpackage/bv.java`, line 50).
  The limit of 3 is a constant in code.
- Other first-run flags live in the same file: `welcomeSeen`, `hasShownOnboardingSurvey`, `discoverySource`,
  `postVoiceSetupPaywallPending`, `pipCompleted`.
- A developer reset exists (`defpackage/kw2.java`, case 12 sets the count back to 0 and clears the flag).

Nothing in the code uses a hardware or account identifier. A search for `ANDROID_ID`, instance IDs, advertising ID,
Play Integrity, `Settings.Secure` and similar found no match.

### 1.2 There is no server-side count [read]

- The only permission that allows network access is `INTERNET`, and the only hosts found in the code are
  `nom.telemetrydeck.com` (analytics), a Notion tutorial page and a YouTube channel. No licence or quota API.
- Pro status comes from Google Play Billing (`com.android.vending.BILLING`, product ids such as `pro.lifetime`
  in `defpackage/ar.java`). That is how a purchase survives a reinstall; it is separate from the free counter.

### 1.3 Why the count survives an uninstall: Android Auto Backup [inferred, strong]

The manifest turns cloud backup on and does not restrict it:

```
android:allowBackup="true"
android:fullBackupContent="@xml/backup_rules"          →  <full-backup-content/>   (empty: default rules)
android:dataExtractionRules="@xml/data_extraction_rules" →  <data-extraction-rules><cloud-backup/></...>  (empty)
```

With empty rule files, Android's Auto Backup includes the app's whole private data, which includes the
`voiceprompter` SharedPreferences file. On reinstall from Google Play with the same Google account, Android restores
that data before the app first starts, so `customScriptsCreated` comes back as 3.

This looks like Android's default behaviour rather than a deliberate anti-abuse mechanism: the rule files are
empty stubs. I did not run it. Caveats that match the owner's experience:

- it needs the phone's Google backup switched on and a backup to have run since the last script was created;
- restore only happens for installs from Google Play with the same account, not for a sideloaded APK;
- the user can switch it off (or clear the backup), so it is not tamper-proof.

## 2. iPhone, iPad and Mac [not verifiable]

The Apple apps are closed source, so none of this can be confirmed from code. These are the mechanisms that make a
counter survive a delete-and-reinstall on Apple platforms. One or more is likely in use:

| Mechanism | Survives delete and reinstall? | Notes |
|---|---|---|
| UserDefaults / app files | iOS: no. Mac (sandboxed): **yes in practice**, see below | A normal iOS counter is wiped. |
| **Keychain** item | iOS: yes. Mac: yes | The usual way apps remember a trial across reinstalls. Apple does not guarantee it forever, but in practice it persists. |
| iCloud key-value store | Yes, same Apple ID | Also syncs across the user's devices. |
| Apple **DeviceCheck** (two bits per device, set via a server) | Yes | Apple's documented way to remember "this device used its trial"; needs a small server. |
| Own server tied to an account | Yes | Needs sign-in. |

The Mac point is already true for us. Deleting a sandboxed Mac app from Applications leaves its data in
`~/Library/Containers/<bundle id>/`, and I saw our own macOS container (`com.talkroll.app`) keep its settings and
script history across rebuilds. A reinstall therefore keeps the count unless the user removes the container.

## 3. Where our app stands today

- The counter is `ProState.presented`, a set of script ids stored as JSON under `TalkRoll.proState.v1` in
  `SharedPreferences` (`lib/features/pro/pro_state.dart`). The limit is `freeScriptLimit = 5` and is **not enforced
  yet** (`proEnforced = false` in `lib/core/entitlements/entitlements.dart`); purchases are not connected.
- **Android:** our manifest does not mention backup, so the default applies: `allowBackup` is on and Auto Backup
  will restore our SharedPreferences exactly as it does for the reference app, on the same terms and with the same
  caveats. We get this behaviour without having chosen it.
- **iOS and iPadOS:** `SharedPreferences` is `UserDefaults`, which is deleted with the app. A reinstall resets the
  counter. There is no iCloud or Keychain use.
- **macOS:** the container survives a reinstall, so the count persists by default.

## 4. Recommendation

Goal: a free user cannot get fresh scripts by uninstalling, while a paying user and an honest user are never hurt.
Keep it simple and honest, and do not collect identity data we do not need.

1. **Keep the purchase as the source of truth for Pro.** Use the stores' own restore (Google Play Billing, StoreKit
   "Restore purchases"). A reinstall or a new phone then never costs a paying user anything.
2. **Store the free-script counter somewhere that outlives the app, per platform.** Store only a small number (the
   count, or a hash of the ids already presented), never script text.
   - **iOS / iPadOS / macOS: Keychain** (for example `flutter_secure_storage`, accessible after first unlock, not
     synced). It survives deletion and needs no server and no sign-in. Optionally also mirror to the iCloud
     key-value store so it follows the Apple ID to a new device.
   - **Android: Google's Block Store API** (Play services). It stores a small amount of app data that survives an
     uninstall and moves to a new device with the user's Google account, with end-to-end encryption. It is more
     reliable than relying on Auto Backup, and it does not need our own backend.
3. **Make the Android default deliberate.** Either keep Auto Backup but state it in a `backup_rules.xml` and a
   `data_extraction_rules.xml` that include the preferences file (so a future Flutter or Gradle change cannot
   silently drop it), or exclude the counter from Auto Backup and rely on Block Store only. Do not leave it to
   defaults.
4. **On startup, read the persistent copy and take the larger value** of it and the local one, so the two stay in
   step and a restore can only raise the count, never lower it.
5. **Optional, later, if abuse shows up:** Apple DeviceCheck (two persistent bits per device) and Google's Play
   Integrity API, both checked by a small server. These raise the cost of resetting a device but need backend work
   and must be declared in the privacy disclosures. Do not build them before there is evidence of abuse.
6. **Do not use hardware identifiers** (IMEI, serial, advertising ID) to recognise a device. They are restricted by
   both stores and are not needed with the options above.

### Policy and privacy notes

- Apple (App Review 5.1.1, 5.1.2) and Google Play (Data safety) both allow a trial counter, but the privacy label and
  Data safety form must describe anything stored off the device (iCloud key-value, Block Store, DeviceCheck,
  Integrity). A count stored locally and in the Keychain is not "collected" data in the sense of those forms; a server
  call would be.
- Tell users plainly, in the paywall copy, that the free scripts are per device or account and are kept if the app is
  reinstalled. The reference app shows the count ("n of 3 free custom scripts used") so it never looks like a bug.
- The wording on the Pro screens should not promise a "fresh start" after reinstalling.
- Provide the restore path and a support email for people who hit the limit by accident (a new phone, a restored
  backup). The existing Help screen already shows the support address.

### Suggested order of work (not started)

1. Decide the storage per platform (Keychain on Apple, Block Store on Android) and write the small abstraction
   behind `ProNotifier`.
2. Add the explicit backup rules for Android.
3. Connect store purchases and restore (Phase 3 in `plan/cross-platform-plan.md`), then switch `proEnforced` on.
4. Test: use all free scripts, uninstall, reinstall (Play install on Android; delete and reinstall on iOS), and check
   the count; repeat with Google backup off and with a signed-out Apple ID.

## 5. Not checked

- I did not run the reference app, so the Auto Backup explanation for its Android behaviour is a reading of its
  manifest, not an observed restore.
- I could not inspect the iOS, iPadOS or Mac builds.
- I did not test Block Store, Keychain or DeviceCheck in our app.

## 6. What the reference app's privacy policy says (checked 2026-10-28)

- **Android:** "Scripts and settings are stored on your device. Android backup and device-transfer services may
  include app data according to your system settings." This matches the Auto Backup explanation in section 1.3.
  It also lists the analytics the app sends to TelemetryDeck: app events, Pro status, app and device information, and
  "SDK-generated hashed identifiers". Those are analytics; nothing says they hold the script count, and the decompiled
  code showed no server-side quota.
- **Android purchases:** Google Play handles purchases, and the app "uses purchase information to check and restore
  paid access".
- **macOS:** no data leaves the Mac ("we do not collect, store, or transmit your voice data or scripts to any external
  servers"), no third-party analytics or trackers, and Apple handles payments through In-App Purchase with local
  receipt verification. So on the Mac the count cannot be on a server. It is almost certainly in local app data,
  which a sandboxed Mac app keeps after the app is deleted (section 2).
- **iOS and iPadOS:** not covered by the page. The macOS wording suggests the same local-only design, but it says
  nothing about the Keychain or iCloud, and a policy would not usually mention either. Still [not verifiable].

Conclusion: the policy gives no evidence of a server, an account, or a device identifier being used for the free
count. It is consistent with local storage that survives a reinstall (Android backup, the Mac container), and it
leaves the iPhone and iPad mechanism undetermined.

## 7. Implemented (2026-10-28) and how to test it

The simplest option that needs no server, no account and no new dependency, and keeps everything on the user's device.
Only the ids of scripts already presented are remembered (random numbers, no text). That is the same data we already
keep in `SharedPreferences`; it is just kept where a reinstall does not erase it.

| Platform | What keeps the count | Code |
|---|---|---|
| **Android** | Android Auto Backup restores the preferences file and the scripts folder after a reinstall (same Google account, Google backup on). The rules are now written out instead of left to defaults, and they back up only `FlutterSharedPreferences.xml` and `app_flutter/TalkRoll Scripts`. | `android/app/src/main/res/xml/backup_rules.xml` (Android 6 to 11), `data_extraction_rules.xml` (Android 12 and later), three attributes on `<application>` in `AndroidManifest.xml` |
| **iPhone, iPad** | A Keychain item (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: stays on this device, never syncs to iCloud). iOS keeps Keychain items when an app is deleted. | `ios/Runner/AppDelegate.swift` (method channel `talkroll/reinstall_store`), `lib/services/storage/reinstall_store.dart` |
| **macOS, Windows** | Nothing new. The app's data folder is left behind when the app is deleted (macOS: `~/Library/Containers/com.talkroll.app/`), so the count is already there after a reinstall. | none |

`ProNotifier` (`lib/features/pro/pro_state.dart`) loads the preferences as before, then once the Keychain answers it
merges the two with a union, so a restore can only raise the count, and writes the merged value back to both. On every
platform other than iOS the store does nothing, so those code paths are unchanged.

### How each was tested here

- **iOS (simulator, iPhone 17e):** seeded `{"presented":["111","222","333"]}` into the app's preferences, launched the
  app (this writes the Keychain), then `xcrun simctl uninstall` and `install`. The uninstall removed the whole data
  container and the fresh container had no preferences file. After launching, the preferences contained all three ids
  again, restored from the Keychain.
- **Android (emulator, API 37):** with the local backup transport, `bmgr backupnow` reported Success, then
  uninstall, install and restore brought `FlutterSharedPreferences.xml` back with the three ids. See the commands
  below. This proves the backup rules include the right files. It does not prove Google's cloud backup on a real
  phone.
- **macOS:** only observed (section 2): the container survives rebuilds. Not re-run for this change because no macOS
  code changed.
- Not tested: a real iPhone or iPad, a real Android phone with Google backup, Windows.

### Test it yourself

**iOS or iPadOS, simulator:**

```sh
cd app && flutter build ios --simulator --debug
SIM=<simulator id from: xcrun simctl list devices available>
APP=build/ios/iphonesimulator/Runner.app; BID=com.talkroll.app
xcrun simctl install $SIM $APP && xcrun simctl launch $SIM $BID && sleep 5 && xcrun simctl terminate $SIM $BID
D=$(xcrun simctl get_app_container $SIM $BID data)
defaults write "$D/Library/Preferences/com.talkroll.app" 'flutter.TalkRoll.proState.v1' -string '{"presented":["111","222","333"]}'
xcrun simctl launch $SIM $BID && sleep 6 && xcrun simctl terminate $SIM $BID   # writes the Keychain
xcrun simctl uninstall $SIM $BID && xcrun simctl install $SIM $APP
D=$(xcrun simctl get_app_container $SIM $BID data)
xcrun simctl launch $SIM $BID && sleep 6 && xcrun simctl terminate $SIM $BID
defaults read "$D/Library/Preferences/com.talkroll.app" 'flutter.TalkRoll.proState.v1'
# expected: {"presented":["111","222","333"]}
```

With the real count: present five saved scripts (the built-in demo never counts), delete the app, reinstall, and the
Pro screen should still show 5 of 5. To start clean again, erase the simulator (`xcrun simctl erase <id>`), which also
clears its Keychain. On a real device, uninstall and reinstall from Xcode; a Keychain item is removed only by erasing
the device.

**Android, emulator (local backup transport):**

```sh
cd app && flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
adb shell bmgr enable true
adb shell bmgr transport com.android.localtransport/.LocalTransport
adb shell am start -n com.talkroll.app/.MainActivity     # leave it running, then press Home
# present some saved scripts in the app (or edit shared_prefs with run-as), then:
adb shell bmgr backupnow com.talkroll.app                # expect "Success"
adb uninstall com.talkroll.app && adb install build/app/outputs/flutter-apk/app-debug.apk
adb shell bmgr restore 1 com.talkroll.app                # token from: adb shell bmgr list sets
adb shell run-as com.talkroll.app grep -o 'proState.v1[^/]*' shared_prefs/FlutterSharedPreferences.xml
```

Gotchas: a force-stopped app is skipped ("Backup is not allowed"), so open the app and press Home instead of using
`force-stop`; and back up only the scripts folder, because the whole `app_flutter` folder holds the debug assets and
exceeds the local transport's quota.

**Android, real phone:** turn on Settings, Google, Backup; run the app so it creates scripts; run
`adb shell bmgr backupnow com.talkroll.app` (or wait for the nightly backup on Wi-Fi and charger); uninstall, then
install from Google Play (internal testing) with the same Google account. Sideloaded installs are not restored.

**macOS:** quit the app, delete `TalkRoll.app`, install it again, and the count is unchanged. To start clean, delete
`~/Library/Containers/com.talkroll.app`.

### Limits to know about

- Android depends on the user's Google backup being on; turning it off, or a sideloaded install, gives a fresh count.
  Google's Block Store would be stronger and is the next step if this proves too easy to get around.
- A Keychain item is erased by a full device reset, and not by deleting the app.
- A new phone gets the count back through the device transfer on Android and an encrypted backup restore on iPhone;
  a new Mac installs without the old container. All three are acceptable for a free-tier limit.
- Nothing here leaves the device except through the operating system's own backup, which the privacy text should
  describe as "your scripts and settings may be included in your device backup".

### 7.1 Change: a script uses its slot when it is saved, not only when it is played (2026-10-28)

Found while testing on macOS: the counter ("3 of 5 scripts used") only moved when Start was pressed, so someone could
write any number of scripts and never use up a slot. The reference app counts scripts as they are created.

- `StudioNotifier._persist` (`lib/services/providers.dart`) now counts a script the first time it is saved
  (`existing == null`), through `ProNotifier.recordStart`. Presenting still counts too, and counting is idempotent per
  script id, so saving then starting uses one slot. This covers the Save button, autosave, import and Start on all
  platforms, because they all go through that one method. The built-in demo is never saved, so it never counts.
- `ProState.canPresent` (`lib/core/entitlements/entitlements.dart`) now treats the first `freeScriptLimit` counted
  scripts as the free ones, in the order they were counted. Once enforcement is on, the sixth script saved needs Pro
  to be presented, even though it can still be written and exported. Deleting a script does not give its slot back.
- The Pro and settings copy now says a script uses a slot as soon as it is saved.
- Scripts that were saved before this change are not counted retroactively; they count when first presented or
  re-saved as new.

Product consequence to confirm before switching `proEnforced` on: a user who writes five drafts and then wants to
present a different sixth script will be asked to upgrade. That is how the reference app behaves ("n of 3 free custom
scripts used"), and it is what stops an edit-the-same-script workaround.

Tested on the Android emulator: the counter went from 3 to 4 of 5 after saving a new script without pressing Start.
macOS and iOS use the same save path and were not re-driven by hand.
