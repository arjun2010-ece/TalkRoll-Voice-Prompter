import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Where feedback goes; the one place the address is written down.
const supportEmail = 'arjun@echoprompter.app';
/// `--dart-define=WEBSITE_URL=http://10.0.2.2:3000` points the app at a local `web/` dev server (10.0.2.2 is the host
/// machine seen from the Android emulator).
const websiteUrl = String.fromEnvironment('WEBSITE_URL', defaultValue: 'https://echoprompter.app');
const termsUrl = '$websiteUrl/terms';
const privacyUrl = '$websiteUrl/privacy';

/// `mailto:` link for "Email us": the versions help diagnose a problem, and no script text is ever added.
Uri feedbackMailto() => Uri(
  scheme: 'mailto',
  path: supportEmail,
  query: [
    'subject=${Uri.encodeComponent('EchoPrompter feedback')}',
    'body=${Uri.encodeComponent('\n\n\n---\nEchoPrompter on ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')}',
  ].join('&'),
);

/// Opens [url] in the default app (mail, browser) with the system opener, so no plugin is needed.
/// False if nothing could open it, for example a Mac with no mail app set up.
Future<bool> openExternal(Uri url) async {
  try {
    if (Platform.isAndroid) return await launchUrl(url, mode: LaunchMode.externalApplication);
    final result = Platform.isMacOS
        ? await Process.run('open', [url.toString()])
        : Platform.isWindows
            ? await Process.run('cmd', ['/c', 'start', '', url.toString()])
            : null;
    return result != null && result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
