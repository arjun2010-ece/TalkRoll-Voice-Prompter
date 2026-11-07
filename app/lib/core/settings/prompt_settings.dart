import 'dart:ui' show Size;

/// Light or dark. A saved "system" from an older build loads as the default (dark).
enum StudioAppearance { dark, light }

enum PromptControlMode { normal, voice, recordedAudio }

/// How a script is run: straight through, or one section at a time, stopping at the end of each.
enum RunStyle { whole, sections }

/// Largest Narration sync offset either way, in milliseconds.
const maxNarrationOffsetMs = 500;

/// How many seconds ahead the "Next up" heads-up for an action cue appears.
const minCueLeadSeconds = 1;
const maxCueLeadSeconds = 5;

enum PromptPlacement { notch, corner, floating }

/// Space either side of the text. Medium is what the prompter always used.
enum PromptMargins {
  narrow(0.5),
  medium(1),
  wide(1.8);

  const PromptMargins(this.scale);

  /// Multiplies the layout's side padding.
  final double scale;
}

/// Bundled fonts for the prompter text; [family] is null for the system font.
enum PromptFont {
  system(null),
  serif('PTSerif'),
  rounded('VarelaRound'),
  hyperlegible('AtkinsonHyperlegible');

  const PromptFont(this.family);
  final String? family;
}

enum PromptCorner { topLeft, topRight, bottomLeft, bottomRight }

/// macOS: what marks the start of each take in a recording, so retakes are easy to find when editing.
enum RetakeClap { both, sound, flash, off }

/// Valid ranges, shared by every slider and by loading saved settings, so a
/// value saved by an older build can never push the prompter out of range.
class PromptLimits {
  const PromptLimits._();
  static const fontSize = (min: 16.0, max: 110.0);
  static const lineSpacing = (min: 0.9, max: 2.0);
  static const speed = (min: 5.0, max: 100.0);
  static const opacity = (min: 0.25, max: 1.0);
}

double _clamp(num v, ({double min, double max}) r) => v.clamp(r.min, r.max).toDouble();

/// Out-of-range saved values came from an older, wrongly-ranged slider rather
/// than from the user's intent, so they fall back to the default.
double _inRangeOr(num? v, ({double min, double max}) r, double fallback) =>
    v == null || v < r.min || v > r.max ? fallback : v.toDouble();

class PromptSettings {
  const PromptSettings({
    this.fontSize = 25,
    this.lineSpacing = 1.32,
    this.speed = 24,
    this.opacity = 0.92,
    this.studioAppearance = StudioAppearance.dark,
    this.mirror = false,
    this.rotated = false,
    this.mode = PromptControlMode.normal,
    this.runStyle = RunStyle.whole,
    this.placement = PromptPlacement.floating,
    this.corner = PromptCorner.topRight,
    this.hideFromCapture = true,
    this.readingGuide = true,
    this.showProgress = true,
    this.showSections = true,
    this.margins = PromptMargins.medium,
    this.font = PromptFont.system,
    this.speechLanguage = 'auto',
    this.narrationOffsetMs = 0,
    this.cueLeadSeconds = 3,
    this.retakeClap = RetakeClap.both,
    this.retakeFlashCorner = PromptCorner.topLeft,
    this.notchSize = const Size(560, 150),
    this.cornerSize = const Size(420, 240),
  });

  final double fontSize;
  /// Line height as a multiple of the font size (0.9–2.0).
  final double lineSpacing;
  /// Normal-mode scroll speed in points/second (the Swift app's base is 24).
  final double speed;
  final double opacity;
  final StudioAppearance studioAppearance;
  final bool mirror;

  /// Rotate the text 180° (mobile glass rigs only; desktop OSes rotate displays).
  final bool rotated;
  final PromptControlMode mode;
  final RunStyle runStyle;
  final PromptPlacement placement;
  final PromptCorner corner;
  final bool hideFromCapture;

  /// Desktop: small `› ‹` marks at the line the prompter keeps you reading on.
  final bool readingGuide;

  /// Desktop: the progress, elapsed and remaining line under the controls.
  final bool showProgress;

  /// Desktop: section names between parts of the script (`[Intro]` lines).
  final bool showSections;
  final PromptMargins margins;
  final PromptFont font;

  /// Voice and Audio mode's language: a tag such as `pt-BR`, or `auto` to take it from the script.
  final String speechLanguage;

  /// Narration mode: shifts the script against the audio, in milliseconds, for the delay of a Bluetooth headset.
  /// Positive moves the script later.
  final int narrationOffsetMs;

  /// Action cues: seconds of warning before a cue (1–5).
  final int cueLeadSeconds;

  /// macOS: the beep and/or flash at the start of each section and on every Retake, and where the flash appears.
  final RetakeClap retakeClap;
  final PromptCorner retakeFlashCorner;

  /// Whether every option under "Text" is at its default, so Reset has nothing to do.
  bool get isTextDefault {
    const d = PromptSettings();
    return fontSize == d.fontSize &&
        lineSpacing == d.lineSpacing &&
        opacity == d.opacity &&
        readingGuide == d.readingGuide &&
        showProgress == d.showProgress &&
        showSections == d.showSections &&
        margins == d.margins &&
        font == d.font;
  }

  /// Notch body size; height excludes the hardware notch inset.
  final Size notchSize;
  final Size cornerSize;

  PromptSettings copyWith({
    double? fontSize,
    double? lineSpacing,
    double? speed,
    double? opacity,
    StudioAppearance? studioAppearance,
    bool? mirror,
    bool? rotated,
    PromptControlMode? mode,
    RunStyle? runStyle,
    PromptPlacement? placement,
    PromptCorner? corner,
    bool? hideFromCapture,
    bool? readingGuide,
    bool? showProgress,
    bool? showSections,
    PromptMargins? margins,
    PromptFont? font,
    String? speechLanguage,
    int? narrationOffsetMs,
    int? cueLeadSeconds,
    RetakeClap? retakeClap,
    PromptCorner? retakeFlashCorner,
    Size? notchSize,
    Size? cornerSize,
  }) => PromptSettings(
    fontSize: _clamp(fontSize ?? this.fontSize, PromptLimits.fontSize),
    lineSpacing: _clamp(lineSpacing ?? this.lineSpacing, PromptLimits.lineSpacing),
    speed: _clamp(speed ?? this.speed, PromptLimits.speed),
    opacity: _clamp(opacity ?? this.opacity, PromptLimits.opacity),
    studioAppearance: studioAppearance ?? this.studioAppearance,
    mirror: mirror ?? this.mirror,
    rotated: rotated ?? this.rotated,
    mode: mode ?? this.mode,
    runStyle: runStyle ?? this.runStyle,
    placement: placement ?? this.placement,
    corner: corner ?? this.corner,
    hideFromCapture: hideFromCapture ?? this.hideFromCapture,
    readingGuide: readingGuide ?? this.readingGuide,
    showProgress: showProgress ?? this.showProgress,
    showSections: showSections ?? this.showSections,
    margins: margins ?? this.margins,
    font: font ?? this.font,
    speechLanguage: speechLanguage ?? this.speechLanguage,
    narrationOffsetMs: (narrationOffsetMs ?? this.narrationOffsetMs).clamp(-maxNarrationOffsetMs, maxNarrationOffsetMs),
    cueLeadSeconds: (cueLeadSeconds ?? this.cueLeadSeconds).clamp(minCueLeadSeconds, maxCueLeadSeconds),
    retakeClap: retakeClap ?? this.retakeClap,
    retakeFlashCorner: retakeFlashCorner ?? this.retakeFlashCorner,
    notchSize: notchSize ?? this.notchSize,
    cornerSize: cornerSize ?? this.cornerSize,
  );

  Map<String, Object> toJson() => {
    'fontSize': fontSize,
    'lineSpacing': lineSpacing,
    'lineSpacingV': 2,
    'speed': speed,
    'opacity': opacity,
    'studioAppearance': studioAppearance.name,
    'mirror': mirror,
    'rotated': rotated,
    'mode': mode.name,
    'runStyle': runStyle.name,
    'placement': placement.name,
    'corner': corner.name,
    'hideFromCapture': hideFromCapture,
    'readingGuide': readingGuide,
    'showProgress': showProgress,
    'showSections': showSections,
    'margins': margins.name,
    'font': font.name,
    'speechLanguage': speechLanguage,
    'narrationOffsetMs': narrationOffsetMs,
    'cueLeadSeconds': cueLeadSeconds,
    'retakeClap': retakeClap.name,
    'retakeFlashCorner': retakeFlashCorner.name,
    'notchW': notchSize.width,
    'notchH': notchSize.height,
    'cornerW': cornerSize.width,
    'cornerH': cornerSize.height,
  };

  factory PromptSettings.fromJson(Map<String, Object?> j) {
    T e<T extends Enum>(List<T> v, Object? n, T d) =>
        v.firstWhere((x) => x.name == n, orElse: () => d);
    const d = PromptSettings();
    return PromptSettings(
      fontSize: _clamp((j['fontSize'] as num?) ?? d.fontSize, PromptLimits.fontSize),
      // Settings saved before line spacing defaulted to 1.32 hold the old 1.0 default; they move to the new one once.
      lineSpacing: j['lineSpacingV'] == null && (j['lineSpacing'] as num?) == 1.0
          ? d.lineSpacing
          : _inRangeOr(j['lineSpacing'] as num?, PromptLimits.lineSpacing, d.lineSpacing),
      speed: _inRangeOr(j['speed'] as num?, PromptLimits.speed, d.speed),
      opacity: _clamp((j['opacity'] as num?) ?? d.opacity, PromptLimits.opacity),
      studioAppearance: e(StudioAppearance.values, j['studioAppearance'], d.studioAppearance),
      mirror: j['mirror'] as bool? ?? d.mirror,
      rotated: j['rotated'] as bool? ?? d.rotated,
      mode: e(PromptControlMode.values, j['mode'], d.mode),
      runStyle: e(RunStyle.values, j['runStyle'], d.runStyle),
      placement: e(PromptPlacement.values, j['placement'], d.placement),
      corner: e(PromptCorner.values, j['corner'], d.corner),
      hideFromCapture: j['hideFromCapture'] as bool? ?? d.hideFromCapture,
      readingGuide: j['readingGuide'] as bool? ?? d.readingGuide,
      showProgress: j['showProgress'] as bool? ?? d.showProgress,
      showSections: j['showSections'] as bool? ?? d.showSections,
      margins: e(PromptMargins.values, j['margins'], d.margins),
      font: e(PromptFont.values, j['font'], d.font),
      speechLanguage: j['speechLanguage'] as String? ?? d.speechLanguage,
      narrationOffsetMs: ((j['narrationOffsetMs'] as num?)?.round() ?? d.narrationOffsetMs).clamp(-maxNarrationOffsetMs, maxNarrationOffsetMs),
      cueLeadSeconds: ((j['cueLeadSeconds'] as num?)?.round() ?? d.cueLeadSeconds).clamp(minCueLeadSeconds, maxCueLeadSeconds),
      retakeClap: e(RetakeClap.values, j['retakeClap'], d.retakeClap),
      retakeFlashCorner: e(PromptCorner.values, j['retakeFlashCorner'], d.retakeFlashCorner),
      notchSize: Size(
        (j['notchW'] as num?)?.toDouble() ?? d.notchSize.width,
        (j['notchH'] as num?)?.toDouble() ?? d.notchSize.height,
      ),
      cornerSize: Size(
        (j['cornerW'] as num?)?.toDouble() ?? d.cornerSize.width,
        (j['cornerH'] as num?)?.toDouble() ?? d.cornerSize.height,
      ),
    );
  }
}
