import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../core/settings/labels.dart';
import '../../core/settings/prompt_settings.dart';
import '../../main.dart' show crashReportingKey;
import '../../services/external_links.dart';
import '../../services/providers.dart';
import '../../ui/adaptive.dart';
import '../onboarding/onboarding_state.dart';
import '../pro/paywall_dialog.dart';
import '../pro/purchase_actions.dart';
import '../pro/pro_state.dart';

enum _Section { general, pro, help }

extension on _Section {
  String get title => switch (this) {
    _Section.general => 'General',
    _Section.pro => 'Pro',
    _Section.help => 'Help & feedback',
  };
  IconData get icon => switch (this) {
    _Section.general => Icons.tune,
    _Section.pro => Icons.star_rounded,
    _Section.help => Icons.help_outline,
  };
}

/// App settings. A phone pushes a page whose Pro and Help rows open their own pages; a tablet opens a dialog with
/// the three sections beside each other.
Future<void> openMobileSettings(BuildContext context) {
  if (!isTabletWidth(context)) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _PhoneSettings()));
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 640),
        child: const _TabletSettings(),
      ),
    ),
  );
}

class _PhoneSettings extends StatelessWidget {
  const _PhoneSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewPaddingOf(context).bottom), children: [
        const _GeneralContent(),
        const SizedBox(height: 8),
        _Group(children: [
          for (final s in const [_Section.pro, _Section.help])
            ListTile(
              leading: Icon(s.icon, color: s == _Section.pro ? proAccent : Theme.of(context).colorScheme.primary),
              title: Text(s.title),
              subtitle: s == _Section.pro ? const _ProSummary() : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SectionPage(section: s))),
            ),
        ]),
      ]),
    );
  }
}

class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.viewPaddingOf(context).bottom),
        children: [section == _Section.pro ? const _ProContent() : const _HelpContent()],
      ),
    );
  }
}

class _TabletSettings extends StatefulWidget {
  const _TabletSettings();
  @override
  State<_TabletSettings> createState() => _TabletSettingsState();
}

class _TabletSettingsState extends State<_TabletSettings> {
  _Section _section = _Section.general;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
        child: Row(children: [
          Expanded(child: Text('Settings', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600))),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
        ]),
      ),
      const Divider(),
      Expanded(
        child: Row(children: [
          SizedBox(
            width: 220,
            child: ListView(padding: const EdgeInsets.all(12), children: [
              for (final s in _Section.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: s == _section,
                    selectedTileColor: scheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius())),
                    leading: Icon(s.icon),
                    title: Text(s.title),
                    onTap: () => setState(() => _section = s),
                  ),
                ),
            ]),
          ),
          VerticalDivider(width: 1, color: scheme.outlineVariant),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              switch (_section) {
                _Section.general => const _GeneralContent(),
                _Section.pro => const _ProContent(),
                _Section.help => const _HelpContent(),
              },
            ]),
          ),
        ]),
      ),
    ]);
  }
}

// --- Pieces --------------------------------------------------------------------

/// A titled group of rows on a rounded card.
class _Group extends StatelessWidget {
  const _Group({required this.children, this.title});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title!.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 0.8, color: scheme.onSurfaceVariant)),
          ),
        Material(
          color: scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isApple ? 12 : 20)),
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
              children[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    title: Text(title),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    value: value,
    onChanged: onChanged,
  );
}

class _GeneralContent extends ConsumerStatefulWidget {
  const _GeneralContent();
  @override
  ConsumerState<_GeneralContent> createState() => _GeneralContentState();
}

class _GeneralContentState extends ConsumerState<_GeneralContent> {
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final set = ref.read(settingsProvider.notifier).update;
    final prefs = ref.read(prefsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Group(title: 'Appearance', children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<StudioAppearance>(
            showSelectedIcon: false,
            segments: [for (final a in StudioAppearance.values) ButtonSegment(value: a, label: Text(a.label))],
            selected: {s.studioAppearance},
            onSelectionChanged: (v) => set((c) => c.copyWith(studioAppearance: v.first)),
          ),
        ),
      ]),
      _Group(title: 'Prompter', children: [
        _SwitchRow(
          title: 'Mirror text',
          subtitle: 'For a teleprompter glass rig. Flips the text left to right.',
          value: s.mirror,
          onChanged: (v) => set((c) => c.copyWith(mirror: v)),
        ),
        _SwitchRow(
          title: 'Rotate 180°',
          subtitle: 'For a device mounted upside down.',
          value: s.rotated,
          onChanged: (v) => set((c) => c.copyWith(rotated: v)),
        ),
      ]),
      _Group(title: 'Diagnostics', children: [
        _SwitchRow(
          title: 'Send crash reports',
          subtitle: 'Never includes your scripts. Applies on next launch.',
          value: prefs.getBool(crashReportingKey) ?? false,
          onChanged: (v) async {
            await prefs.setBool(crashReportingKey, v);
            setState(() {});
          },
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          'Everything runs on your device. Your scripts are never uploaded.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}

/// The plan in one line, under the Pro row.
class _ProSummary extends ConsumerWidget {
  const _ProSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proProvider);
    return Text(switch (pro.plan) {
      ProPlan.free => 'Free · ${pro.used.clamp(0, freeScriptLimit)} of $freeScriptLimit scripts used',
      ProPlan.monthly => 'Pro · Monthly',
      ProPlan.yearly => 'Pro · Yearly',
      ProPlan.lifetime => 'Pro · Lifetime',
    });
  }
}

/// Plan and purchases: Restore and Manage go to the store (or the debug fake, or say they are not available).
class _ProContent extends ConsumerWidget {
  const _ProContent();


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final used = pro.used.clamp(0, freeScriptLimit);
    final title = switch (pro.plan) {
      ProPlan.free => 'Free plan',
      ProPlan.monthly => 'Pro · Monthly',
      ProPlan.yearly => 'Pro · Yearly',
      ProPlan.lifetime => 'Pro · Lifetime',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: pro.isPro ? (theme.brightness == Brightness.dark ? const Color(0xFF33291A) : const Color(0xFFFFF4DF)) : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: pro.isPro ? proAccent : scheme.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.star_rounded, color: proAccent, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 10),
          if (!pro.isPro) ...[
            Text('$used of $freeScriptLimit free scripts used. Pro lets you save and present as many as you like. Editing and exporting your scripts is always free.', style: muted),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: used / freeScriptLimit, minHeight: 4, color: proAccent, backgroundColor: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => showPaywall(context, source: 'settings'),
              style: FilledButton.styleFrom(backgroundColor: proAccent, foregroundColor: const Color(0xFF1A1A1A)),
              child: const Text('Upgrade to Pro', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ] else ...[
            Text(pro.plan == ProPlan.lifetime ? 'One purchase, yours for good. Thank you.' : 'Present as many scripts as you like.', style: muted),
            if (pro.plan != ProPlan.lifetime) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: () => manageSubscription(context, ref), child: const Text('Manage subscription')),
            ],
          ],
        ]),
      ),
      _Group(children: [
        ListTile(
          title: Text(pro.isPro ? 'Purchase not showing?' : 'Already bought Pro?'),
          subtitle: const Text('Restore it from your store.'),
          trailing: TextButton(onPressed: () => restorePurchases(context, ref), child: const Text('Restore purchases')),
        ),
      ]),
      // Debug builds only: lets the Pro screens be checked in each state before purchases exist.
      if (kDebugMode)
        _Group(title: 'Preview (debug builds only)', children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<ProPlan>(
              showSelectedIcon: false,
              segments: [for (final p in ProPlan.values) ButtonSegment(value: p, label: Text(p.name))],
              selected: {pro.plan},
              onSelectionChanged: (v) => ref.read(proProvider.notifier).previewPlan(v.first),
            ),
          ),
          const FakeOutcomeControls(),
        ]),
    ]);
  }
}

/// The feedback address as text with a Copy button, so nothing opens a mail app: people write to us from the
/// mail app they already use.
class _HelpContent extends StatelessWidget {
  const _HelpContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Group(title: 'Email us', children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            Expanded(child: SelectableText(supportEmail, style: theme.textTheme.bodyLarge)),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: supportEmail));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email address copied')));
                }
              },
            ),
          ]),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
        child: Text(
          'Questions, bugs and ideas are all welcome. Open your mail app and write to this address. Please mention your device and its system version. Never send your scripts unless you want to.',
          style: muted,
        ),
      ),
      _Group(title: 'Welcome tour', children: [
        ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: const Text('Show the tour again'),
          subtitle: const Text('Microphone and camera setup, and how to choose a mode.'),
          onTap: () => replayOnboarding(context),
        ),
      ]),
      _Group(title: 'Website & FAQ', children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(websiteUrl.replaceFirst('https://', ''), style: theme.textTheme.bodyLarge),
        ),
      ]),
    ]);
  }
}
