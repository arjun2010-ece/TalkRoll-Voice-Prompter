import 'package:echoprompter_camera/echoprompter_camera.dart';

import '../../core/settings/prompt_settings.dart';

/// One recorded take of one section.
class Clip {
  Clip({
    required this.id,
    required this.sessionId,
    required this.sectionIndex,
    required this.path,
    required this.duration,
    required this.attempt,
    required this.createdAt,
    this.isKeeper = true,
  });

  final int id;
  final int sessionId;

  /// Position in the script's section list, from 0.
  final int sectionIndex;
  final String path;
  final Duration duration;

  /// 1 for the first take of the section, 2 for its first retake, and so on.
  final int attempt;
  final DateTime createdAt;

  /// The take that goes into the export. The last complete take of a section is the keeper.
  bool isKeeper;
}

/// The clips of one section-by-section run on the camera. Earlier attempts stay until the session ends, so a retake
/// only moves the keeper. Whole-script runs are one file and need no session.
class RecordingSession {
  RecordingSession({
    required this.id,
    required this.mode,
    required this.camera,
    this.runStyle = RunStyle.sections,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final int id;
  final PromptControlMode mode;
  final CameraFacing camera;
  final RunStyle runStyle;
  final DateTime createdAt;
  final List<Clip> clips = [];
  int _nextId = 1;

  /// Adds a finished take of [section]. It becomes the section's keeper and the earlier ones stop being it.
  Clip add({required int section, required String path, required Duration duration}) {
    final attempt = clips.where((c) => c.sectionIndex == section).length + 1;
    for (final c in clips) {
      if (c.sectionIndex == section) c.isKeeper = false;
    }
    final clip = Clip(
      id: _nextId++,
      sessionId: id,
      sectionIndex: section,
      path: path,
      duration: duration,
      attempt: attempt,
      createdAt: DateTime.now(),
    );
    clips.add(clip);
    return clip;
  }

  /// The keeper clips, in section order (whatever order they were recorded in).
  List<Clip> get keepers => (clips.where((c) => c.isKeeper).toList()..sort((a, b) => a.sectionIndex.compareTo(b.sectionIndex)));

  Clip? keeperFor(int section) {
    for (final c in clips) {
      if (c.sectionIndex == section && c.isKeeper) return c;
    }
    return null;
  }

  int attemptsFor(int section) => clips.where((c) => c.sectionIndex == section).length;

  /// Sections (from 0) among the first [sectionCount] that have no keeper clip.
  List<int> missingSections(int sectionCount) => [for (var i = 0; i < sectionCount; i++) if (keeperFor(i) == null) i];

  Duration get keepersDuration => keepers.fold(Duration.zero, (sum, c) => sum + c.duration);
}

/// "Section 2 has no take" or "Sections 2 and 4 have no take" for the sections (counted from 0) in [missing].
String missingSectionsMessage(List<int> missing) {
  final n = [for (final i in missing) i + 1];
  if (n.isEmpty) return '';
  if (n.length == 1) return 'Section ${n.first} has no take';
  final list = n.length == 2 ? '${n[0]} and ${n[1]}' : '${n.sublist(0, n.length - 1).join(', ')} and ${n.last}';
  return 'Sections $list have no take';
}
