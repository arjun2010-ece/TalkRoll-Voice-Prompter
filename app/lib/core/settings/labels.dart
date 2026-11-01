import 'prompt_settings.dart';

/// User-facing names, so the UI never shows raw enum names.
extension StudioAppearanceLabel on StudioAppearance {
  String get label => switch (this) {
    StudioAppearance.dark => 'Dark',
    StudioAppearance.light => 'Light'
  };
}

extension PromptMarginsLabel on PromptMargins {
  String get label => switch (this) {
    PromptMargins.narrow => 'Narrow',
    PromptMargins.medium => 'Medium',
    PromptMargins.wide => 'Wide',
  };
}

extension PromptFontLabel on PromptFont {
  String get label => switch (this) {
    PromptFont.system => 'Default',
    PromptFont.serif => 'Serif',
    PromptFont.rounded => 'Rounded',
    PromptFont.hyperlegible => 'Hyperlegible',
  };
}

/// The only place the user-facing mode names are written. The enum values
/// (`normal`, `recordedAudio`) are stored in settings, so they never change.
const String autoScrollModeName = 'Auto-scroll';
const String voiceModeName = 'Voice';
const String narrationModeName = 'Narration';

extension PromptControlModeLabel on PromptControlMode {
  String get label => switch (this) {
    PromptControlMode.normal => autoScrollModeName,
    PromptControlMode.voice => voiceModeName,
    PromptControlMode.recordedAudio => narrationModeName,
  };

  /// One line under the mode picker.
  String get explanation => switch (this) {
    PromptControlMode.normal => 'Scrolls smoothly at a steady pace. Never uses the microphone.',
    PromptControlMode.voice => 'Follows your voice, word by word. Listens only while the prompter is open.',
    PromptControlMode.recordedAudio => 'Plays your recorded narration and keeps the script in step. You don\'t speak.',
  };

  /// Upper-case name in the prompter header.
  String get headerName => switch (this) {
    PromptControlMode.normal => 'AUTO-SCROLL',
    PromptControlMode.voice => 'VOICE CONTROL',
    PromptControlMode.recordedAudio => 'NARRATION',
  };
}

extension PromptCornerLabel on PromptCorner {
  String get label => switch (this) {
    PromptCorner.topLeft => 'Top left',
    PromptCorner.topRight => 'Top right',
    PromptCorner.bottomLeft => 'Bottom left',
    PromptCorner.bottomRight => 'Bottom right',
  };
}

extension PromptPlacementLabel on PromptPlacement {
  /// [hasNotch] is true on a Mac whose display has a camera notch; everywhere
  /// else the top-centre position is called "Top center".
  String label({required bool hasNotch}) => switch (this) {
    PromptPlacement.notch => hasNotch ? 'Notch' : 'Top center',
    PromptPlacement.corner => 'Corner',
    PromptPlacement.floating => 'Floating',
  };

  String description({required bool hasNotch, required bool mac}) => switch (this) {
    PromptPlacement.notch => hasNotch
        ? 'Sits right under the camera notch, so you keep eye contact.'
        : mac
            ? 'Docks at the top center of the screen, near your camera.'
            : 'Docks at the top center, under your webcam.',
    PromptPlacement.corner => 'Snaps to a screen corner. Drag it to another corner to move it.',
    PromptPlacement.floating => 'Move and resize it anywhere. The position is remembered.',
  };
}
