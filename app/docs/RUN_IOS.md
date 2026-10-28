# Running EchoPrompter on an iPhone or iPad

Notes from the 2026-10-27 test session on an iPad Pro 11" (iPadOS 27). Run everything from `app/`, not the repo root
(`flutter run` there fails with "No pubspec.yaml file found").

```sh
flutter devices                                  # find the device id
flutter run -d <device-id> --release             # release: no hot reload, press q then run again after a change
```

Voice and the camera need a real device. Debug builds also work but attach through the local network (see below).

## Problems met, and what fixed them

| Message | Cause | Fix |
|---|---|---|
| `Xcode failed to resolve Swift Package Manager dependencies ... No space left on device (errno=28)` | The Mac's disk was 100% full, so Xcode could not write the plugin manifests | Free space. Safe targets: `xcrun simctl delete unavailable`, `flutter clean`, `~/Library/Caches` (Yarn, Google, Homebrew), `~/Library/Developer/Xcode/DerivedData`. Keep `~/.android/avd` unless the emulators are not needed |
| `Flutter could not access the local network ... No route to host, port 5353` | macOS blocks the terminal from the local network, so Flutter cannot find the app over mDNS. Debug runs then end with "Error launching application" | System Settings → Privacy & Security → Local Network → turn on the terminal app (toggle it off and on if it is already listed). The iPad must be on the same Wi-Fi |
| `Could not run build/ios/iphoneos/Runner.app ... Error running application` (build and install succeeded) | The iPad was **locked**. `xcrun devicectl device process launch ...` shows `Unable to launch ... because the device was not, or could not be, unlocked` | Unlock the iPad and keep the screen on, then run again, or open the app by hand. `xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app` installs without Flutter |
| `Target file "<id>" not found` | `-d` was left out of the command | `flutter run -d <id>` |

## Other facts

- The signing team id (`N3MNK6X8NN`) is only in the local, uncommitted `ios/Runner.xcodeproj/project.pbxproj`. Without it
  Flutter cannot sign for the device.
- A release build compiles the Swift plugin too, so a change in `packages/echoprompter_camera/ios` needs a full rebuild.
  Hot reload never applies to native code.
- Findings from the same session (camera orientation, prompter scroll drift, Voice mode, progress line) are in
  `ios-ipad-camera-and-prompter-findings.md`.
