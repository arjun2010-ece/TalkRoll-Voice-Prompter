import 'package:flutter/material.dart';

import '../../ui/adaptive.dart';

/// A centred card for a camera screen that has nothing to film: the permission explainer, a refused permission,
/// or a camera that can't open. It says what happened, and offers one main way on and one way back to reading.
class CameraStateCard extends StatelessWidget {
  const CameraStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.detail,
    this.tone = CameraCardTone.info,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? detail;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final CameraCardTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final (bg, fg) = switch (tone) {
      CameraCardTone.info => (dark ? const Color(0xFF1F3550) : const Color(0xFFE3EEFD), scheme.primary),
      CameraCardTone.warning => (dark ? const Color(0xFF33291A) : const Color(0xFFFFF4DF), dark ? const Color(0xFFFFB340) : const Color(0xFF8A5A00)),
      CameraCardTone.error => (dark ? const Color(0xFF3A1F1D) : const Color(0xFFFDE7E5), scheme.error),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 28),
            ),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
          if (secondaryLabel != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
          ],
        ]),
      ),
    );
  }
}

enum CameraCardTone { info, warning, error }

/// What follows a take: the saved video with Share, Record again and Done. It floats over the dimmed preview.
class CameraResultSheet extends StatelessWidget {
  const CameraResultSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onShare,
    required this.onRecordAgain,
    required this.onDone,
    this.warning = false,
  });

  final String title;
  final String subtitle;
  final bool warning;
  final VoidCallback? onShare;
  final VoidCallback onRecordAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      borderRadius: BorderRadius.circular(isApple ? 20 : 28),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: warning ? scheme.tertiaryContainer : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(warning ? Icons.warning_amber_rounded : Icons.play_arrow_rounded, color: warning ? scheme.onTertiaryContainer : scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: onShare, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero), child: const Text('Share'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: onRecordAgain, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero), child: const Text('Record again'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: onDone, style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero), child: const Text('Done'))),
          ]),
        ]),
      ),
    );
  }
}
