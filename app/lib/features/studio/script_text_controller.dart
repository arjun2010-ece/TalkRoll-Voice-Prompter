import 'package:flutter/material.dart';

import '../../core/script/sections.dart';
import '../prompter/cue_widgets.dart';

/// The script editor's controller: section marker lines (`[Intro]`) show in a dimmer, bolder style
/// so the structure of a long script is easy to see while typing. Action cue lines (`{{ Click Submit }}`) are purple, as on the prompter.
class ScriptTextController extends TextEditingController {
  ScriptTextController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final markers = sectionMarkers(text);
    final cues = actionCues(text);
    // While an input method is composing, leave the text to the default so its underline stays right.
    if ((markers.isEmpty && cues.isEmpty) || (withComposing && value.composing.isValid && !value.composing.isCollapsed)) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final marker = (style ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final children = <InlineSpan>[];
    var at = 0;
    final cue = (style ?? const TextStyle()).copyWith(fontWeight: FontWeight.w600, color: cueLabelColor, backgroundColor: cueFill);
    final lines = <(int, int, TextStyle)>[
      for (final m in markers) (m.start, m.end, marker),
      for (final c in cues) (c.start, c.end, cue),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (start, end, lineStyle) in lines) {
      if (start > at) children.add(TextSpan(text: text.substring(at, start)));
      children.add(TextSpan(text: text.substring(start, end), style: lineStyle));
      at = end;
    }
    if (at < text.length) children.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: children);
  }
}
