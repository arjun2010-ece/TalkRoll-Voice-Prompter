import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/prompter/voice_permissions.dart';

/// The checklist of what Voice mode needs here (microphone, speech recognition on Apple, Dictation on a Mac), one row
/// each: a button that asks for that one alone, a tick once it is allowed, or Open Settings once only Settings can
/// change it. Reads again when the app comes back to the front, so a switch turned on in Settings shows at once.
class VoicePermissionList extends ConsumerStatefulWidget {
  const VoicePermissionList({super.key, this.card = false});

  /// Draws its own rounded card (onboarding). Settings puts the rows in its own group instead.
  final bool card;

  @override
  ConsumerState<VoicePermissionList> createState() => _VoicePermissionListState();
}

class _VoicePermissionListState extends ConsumerState<VoicePermissionList> with WidgetsBindingObserver {
  /// The permission whose system prompt is open.
  VoicePermission? _asking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.read(voicePermissionsProvider.notifier).refresh();
  }

  Future<void> _ask(VoicePermission p) async {
    if (_asking != null) return;
    setState(() => _asking = p);
    await ref.read(voicePermissionsProvider.notifier).request(p);
    if (mounted) setState(() => _asking = null);
  }

  @override
  Widget build(BuildContext context) {
    final states = ref.watch(voicePermissionsProvider).value;
    final kinds = states?.keys.toList() ?? voicePermissionKinds();
    if (kinds.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, p) in kinds.indexed) ...[
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
          _row(context, p, states?[p]),
        ],
      ],
    );
    if (!widget.card) return rows;
    return Material(
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: rows,
    );
  }

  Widget _row(BuildContext context, VoicePermission p, AccessState? s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, title, purpose) = switch (p) {
      VoicePermission.microphone => (Icons.mic_none_rounded, 'Microphone', 'Hears you as you read aloud'),
      VoicePermission.speech => (
        Icons.record_voice_over_outlined,
        'Speech recognition',
        'Turns your words into text to keep your place',
      ),
      VoicePermission.dictation => (Icons.keyboard_alt_outlined, 'Dictation', "Your Mac's speech recognition needs it"),
    };
    final subtitle = switch (s) {
      AccessState.settings when p == VoicePermission.dictation => 'Off. Turn it on in System Settings → Keyboard.',
      AccessState.settings when Platform.isMacOS => 'Off. Turn it on in System Settings → Privacy & Security.',
      AccessState.settings => 'Off. Turn it on in Settings.',
      AccessState.restricted => 'Blocked by Screen Time or device management.',
      _ => purpose,
    };
    final Widget? trailing = _asking == p
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : switch (s) {
            AccessState.ask => FilledButton.tonal(
              onPressed: () => _ask(p),
              child: Text(Platform.isAndroid ? 'Turn on' : 'Continue'),
            ),
            AccessState.granted => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 22, color: scheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  p == VoicePermission.dictation ? 'On' : 'Allowed',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.tertiary),
                ),
              ],
            ),
            AccessState.settings => TextButton(
              onPressed: () => ref.read(voicePermissionsProvider.notifier).openSettings(p),
              child: const Text('Open Settings'),
            ),
            AccessState.restricted || null => null,
          };
    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      trailing: trailing,
    );
  }
}
