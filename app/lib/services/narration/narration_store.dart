import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/narration/alignment.dart';

/// Narration recordings and their transcripts, kept in app storage. A recording is copied in under its content hash,
/// so the same file is never stored or transcribed twice, and a transcript is cached by (recording, language).
class NarrationStore {
  const NarrationStore();

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'narration'));
    await dir.create(recursive: true);
    return dir;
  }

  /// FNV-1a over the file's bytes plus its length: enough to tell recordings apart without a hashing package.
  Future<String> hashOf(String path) async {
    var h = 0xcbf29ce484222325;
    var length = 0;
    await for (final chunk in File(path).openRead()) {
      for (final b in chunk) {
        h = ((h ^ b) * 0x100000001b3) & 0x7fffffffffffffff;
      }
      length += chunk.length;
    }
    return '${h.toRadixString(16).padLeft(16, '0')}${length.toRadixString(16)}';
  }

  /// Copies [source] into app storage and returns the copy's path (the existing one when already imported).
  Future<String> import(String source) async {
    final dir = await _dir();
    if (p.isWithin(dir.path, source)) return source;
    final target = File(p.join(dir.path, '${await hashOf(source)}${p.extension(source).toLowerCase()}'));
    if (!target.existsSync()) await File(source).copy(target.path);
    return target.path;
  }

  Future<File> _transcriptFile(String audioPath, String language) async {
    final hash = await hashOf(audioPath);
    // v2: transcripts made by the older Apple recogniser were cut short or missing words, so they are not reused.
    return File(p.join((await _dir()).path, '$hash.${language.toLowerCase()}.v2.json'));
  }

  Future<List<TimedWord>?> cachedTranscript(String audioPath, String language) async {
    try {
      final f = await _transcriptFile(audioPath, language);
      if (!f.existsSync()) return null;
      final json = jsonDecode(await f.readAsString()) as List<dynamic>;
      return [for (final w in json) TimedWord.fromJson(w as Map<String, dynamic>)];
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTranscript(String audioPath, String language, List<TimedWord> words) async {
    final f = await _transcriptFile(audioPath, language);
    await f.writeAsString(jsonEncode([for (final w in words) w.toJson()]));
  }

  static String _linkKey(String scriptId) => 'narration.audio.$scriptId';

  /// The recording linked to a script, if it is still there.
  String? linkedAudio(SharedPreferences prefs, String scriptId) {
    final path = prefs.getString(_linkKey(scriptId));
    return path != null && File(path).existsSync() ? path : null;
  }

  Future<void> linkAudio(SharedPreferences prefs, String scriptId, String? path) async {
    if (path == null) {
      await prefs.remove(_linkKey(scriptId));
    } else {
      await prefs.setString(_linkKey(scriptId), path);
    }
  }
}
