import 'package:flutter/material.dart';

import '../../core/settings/labels.dart';
import '../../core/settings/prompt_settings.dart';

/// Shows how this session reads (`Normal`, `Voice`, `Audio · Camera`…) and opens "How to read" to change it. The
/// same chip sits in the top bar of the reader and of the camera screen. While a take is open it carries a lock,
/// because changing the mode ends the take first.
class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.mode, required this.camera, required this.onPressed, this.locked = false});

  final PromptControlMode mode;

  /// True on the camera screen.
  final bool camera;
  final VoidCallback onPressed;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final text = '${mode.label}${camera ? ' · Camera' : ''}';
    return Semantics(
      button: true,
      label: 'Mode: $text. ${locked ? 'Ends the recording first.' : 'Change how to read.'}',
      excludeSemantics: true,
      child: Material(
        color: const Color(0xCC1C1C1E),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(text, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Icon(locked ? Icons.lock_outline : Icons.keyboard_arrow_down, color: Colors.white, size: locked ? 15 : 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round button on the dark chrome of the reader and the camera: translucent charcoal with a white icon (or [label]).
class ChromeButton extends StatelessWidget {
  const ChromeButton({super.key, required this.tooltip, required this.onPressed, this.icon, this.label, this.size = 44, this.iconSize = 22});

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? label;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.38 : 1,
        child: Material(
          color: const Color(0xCC1C1C1E),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: iconSize)
                    : Text(label ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
