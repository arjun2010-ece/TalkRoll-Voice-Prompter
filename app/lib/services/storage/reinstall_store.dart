import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// A small text value that outlives deleting the app, for the free-script count.
///
/// - iOS and iPadOS: a Keychain item (see `AppDelegate.swift`), kept on this device only.
/// - Android: nothing here; Auto Backup restores the preferences file (see `res/xml/backup_rules.xml`).
/// - macOS and Windows: nothing needed; the app's data folder stays when the app is deleted.
///
/// Where there is no store, [read] returns null and [write] does nothing.
class ReinstallStore {
  const ReinstallStore();

  static const _channel = MethodChannel('echoprompter/reinstall_store');

  Future<String?> read() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('read');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> write(String value) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('write', value);
    } on PlatformException {
      // The count is still kept in the preferences.
    } on MissingPluginException {
      // Same.
    }
  }
}
