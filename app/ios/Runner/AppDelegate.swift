import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerReinstallStore(engineBridge.applicationRegistrar.messenger())
  }

  /// A small text value in the Keychain, which iOS keeps when the app is deleted. The free-script count uses it so
  /// reinstalling does not hand back the free scripts. It stays on this device (never synced to iCloud).
  private func registerReinstallStore(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "echoprompter/reinstall_store", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.echoprompter.freeScripts",
        kSecAttrAccount as String: "presented",
      ]
      switch call.method {
      case "read":
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
          result(String(data: data, encoding: .utf8))
        } else {
          result(nil)
        }
      case "write":
        guard let text = call.arguments as? String, let data = text.data(using: .utf8) else {
          result(FlutterError(code: "bad_args", message: "Expected a string", details: nil))
          return
        }
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
          query[kSecValueData as String] = data
          query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
          status = SecItemAdd(query as CFDictionary, nil)
        }
        result(status == errSecSuccess ? nil : FlutterError(code: "keychain", message: "Status \(status)", details: nil))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
