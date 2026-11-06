import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:echoprompter_camera/echoprompter_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/settings/prompt_settings.dart';
import '../../services/permissions/permissions.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/platform.dart';
import '../../ui/adaptive.dart';
import 'camera_cards.dart';
import '../studio/start_options.dart';
import 'mode_chip.dart';
import 'camera_state.dart';
import '../prompter/section_end.dart';
import 'clip_export_sheet.dart';
import 'recording_session.dart';
import '../../services/providers.dart';
import '../prompter/cue_widgets.dart';
import '../prompter/prompt_view.dart';
import '../prompter/prompter_controller.dart';
import '../read/reading_settings.dart';
import '../read/script_editor_sheet.dart';
import '../../ui/language_pack_prompt.dart';
import '../../ui/voice_unsupported_dialog.dart';

/// R2: in-app camera (front/back) with the prompter overlay docked at the
/// top, in portrait and landscape. The prompter is a UI overlay only and is
/// never part of the recorded file.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});
  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> with WidgetsBindingObserver {
  CameraFacing _facing = CameraFacing.front;
  CameraPreviewInfo? _preview;
  String? _error;
  bool _recording = false;
  bool _paused = false;
  int? _countdown;
  bool _useCountdown = true;
  int _recordings = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _narrationTicks;
  ReferenceRoute _route = ReferenceRoute.silent;
  StreamSubscription<Map<Object?, Object?>>? _events;
  DateTime? _micStart;
  bool _opening = false;
  // Voice mode: the prompter started as the screen opened, so the script shows before the camera.
  bool _promptReady = false;
  // Voice mode: the microphone was listening when the app went to the background.
  // Cached because `ref` can't be read in dispose().
  late final AnalyticsService _analytics;
  late final PrompterController _prompter;
  // Permissions: nothing yet, the explainer before the first system prompt, or refused.
  _Perm _perm = _Perm.checking;
  bool _deniedCam = false;
  bool _deniedMic = false;
  Completer<bool>? _primer;
  // A take that ended: saved by the reader, or stopped by the system (call, full storage).
  RecordingResult? _saved;
  // A take the gallery refused: kept on the device, with the way it ended, so the reader can try again or share it.
  ({RecordingResult result, String reason, bool photosOff})? _unsaved;
  bool _retrying = false;
  ({String title, String body, String? detail, RecordingResult? result})? _stopped;

  // Section by section: each section is its own clip. The session holds every take until it is exported or discarded.
  RecordingSession? _session;
  int _sessionCount = 0;
  // The section being filmed, or null when the take is the whole script.
  int? _takeSection;
  bool _finishingTake = false;
  bool _exporting = false;
  // The export that just ended: files to share, and whether the gallery took them.
  ({String title, String subtitle, List<String> files, bool warning})? _exported;
  // Files made by an export, removed with the screen.
  final _exportFiles = <String>[];
  static const _sectionTail = Duration(milliseconds: 400);

  /// Whether each section is recorded as its own clip (Run: Section by section).
  bool get _sectionClips => _prompter.sectionRun;

  // Overlay height as a fraction of the screen, remembered per orientation.
  double _fractionFor(bool landscape, Size screen, CameraPreviewInfo? preview) =>
      ref.read(prefsProvider).getDouble('EchoPrompter.overlay.${landscape ? 'l' : 'p'}') ??
      _defaultFraction(landscape, screen, preview);

  /// iPhone, iPad and Android in portrait: the prompter covers 60% of the camera picture, which leaves the script more
  /// room. In landscape the panel already runs the full height, so it keeps the usual share of the screen.
  double _defaultFraction(bool landscape, Size screen, CameraPreviewInfo? preview) {
    if (landscape || !(Platform.isAndroid || Platform.isIOS)) return landscape ? 0.4 : 0.3;
    // The picture is upright and as wide as the screen, 16:9 until the camera reports its own shape.
    final aspect = preview == null ? 9 / 16 : (preview.aspectRatio >= 1 ? 1 / preview.aspectRatio : preview.aspectRatio);
    final pictureHeight = math.min(screen.height, screen.width / aspect);
    return 0.6 * pictureHeight / screen.height;
  }
  void _saveFraction(bool landscape, double v) =>
      ref.read(prefsProvider).setDouble('EchoPrompter.overlay.${landscape ? 'l' : 'p'}', v);
  final _dragFractions = <bool, double>{};
  static const _recordButtonSize = 72.0;
  static const _fadeIn = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _analytics = ref.read(analyticsProvider);
    _prompter = ref.read(prompterProvider.notifier);
    _analytics.log('video_mode_enter');
    _init();
  }

  /// Resolves once the push transition has finished, so camera and recognizer
  /// start-up never competes with it for the UI thread.
  Future<void> _transitionDone() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) return;
    final done = Completer<void>();
    void listener(AnimationStatus st) {
      if (st == AnimationStatus.completed && !done.isCompleted) done.complete();
    }
    animation.addStatusListener(listener);
    await done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
    animation.removeStatusListener(listener);
  }

  /// Mobile: Voice mode listens through a connected headset microphone; Audio mode through the built-in one.
  void _routeInput(PromptControlMode mode) {
    if (isMobile) EchoPrompterCamera.setHeadsetInput(mode != PromptControlMode.recordedAudio);
  }

  Future<void> _init() async {
    _routeInput(ref.read(settingsProvider).mode);
    // Voice mode's start-up is light, so its script shows at once, on black, and the camera fades
    // in behind it once open (as in the reference). Audio mode transcribes its file on this thread, so it
    // starts once the preview is up (below).
    if (_scriptFirst) {
      await _beginPrompter();
      if (!mounted) return;
      setState(() => _promptReady = true);
    }
    await _transitionDone();
    if (!mounted) return;
    if (!await _ensurePermissions()) return;
    if (!mounted) return;
    await _continueInit();
  }

  /// What follows the permissions: the reference route, the camera's events, the preview and the prompter.
  Future<void> _continueInit() async {
    // Audio mode's video must contain the audio file, so it plays out loud and
    // the microphone records it; other modes pace silently or into headphones.
    _route = ref.read(settingsProvider).mode == PromptControlMode.recordedAudio
        ? ReferenceRoute.speaker
        : await EchoPrompterCamera.headphonesConnected ? ReferenceRoute.headphones : ReferenceRoute.silent;
    _events = EchoPrompterCamera.events.listen((e) async {
      final type = e['type'];
      if (type == 'interrupted' || type == 'storage_full') {
        // The camera ended the take itself and finished the file; keep it like a take the reader stopped.
        final path = e['path'];
        final r = path is String
            ? RecordingResult(
                path,
                Duration(milliseconds: (e['durationMs'] as int?) ?? 0),
                '$type',
                narrationFailed: (e['narrationFailed'] as bool?) ?? false,
              )
            : null;
        await _onStopped(r, '$type');
        if (r == null && mounted && _saved == null && _stopped == null) {
          setState(() => _stopped = (
            title: type == 'storage_full' ? 'Storage is full' : 'Recording stopped',
            body: type == 'storage_full'
                ? 'There is no space left to keep recording. What you recorded was saved. Free up space to record again.'
                : 'A call or another app interrupted the recording. What you recorded was saved.',
            detail: null,
            result: null,
          ));
        }
      }
    });
    if (_promptReady && mounted) {
      // The script is already showing.
      await _startPreview();
      return;
    }
    await _startPreview();
    // Let the preview paint before the prompter does heavy start-up work
    // (e.g. transcribing the audio file in Audio mode) on the same thread.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _beginPrompter();
  }

  /// The camera and microphone, asked for with an explanation first. False when the reader said no (the screen then
  /// shows how to carry on without them).
  Future<bool> _ensurePermissions() async {
    final needMic = _needsMic(ref.read(settingsProvider).mode);
    var cam = await Permission.camera.status;
    var mic = await Permission.microphone.status;
    if (cam.isGranted && (!needMic || mic.isGranted)) return true;
    final blocked = cam.isPermanentlyDenied || cam.isRestricted || (needMic && (mic.isPermanentlyDenied || mic.isRestricted));
    if (!blocked) {
      _primer = Completer<bool>();
      if (mounted) setState(() => _perm = _Perm.primer);
      if (!await _primer!.future) {
        _leaveForVoiceOnly();
        return false;
      }
      final a = ref.read(analyticsProvider);
      await requestPermission(Permission.camera, 'camera', a);
      if (needMic) await requestPermission(Permission.microphone, 'mic', a);
      cam = await Permission.camera.status;
      mic = await Permission.microphone.status;
      if (cam.isGranted && (!needMic || mic.isGranted)) {
        if (mounted) setState(() => _perm = _Perm.ok);
        return true;
      }
    }
    if (mounted) {
      setState(() {
        _perm = _Perm.denied;
        _deniedCam = !cam.isGranted;
        _deniedMic = needMic && !mic.isGranted;
      });
    }
    return false;
  }

  /// Whether a take in [mode] listens to the microphone. iPhone, iPad and Android Narration takes don't: the video
  /// gets the narration file itself (see `_toggleRecord`), so those takes only need the camera.
  bool _needsMic(PromptControlMode mode) => !((Platform.isIOS || Platform.isAndroid) && mode == PromptControlMode.recordedAudio);

  /// A reader who started in Narration (camera only) and switched to Voice has not been asked for the microphone yet.
  Future<void> _askMicIfNeeded(PromptControlMode mode) async {
    if (!_needsMic(mode) || _perm == _Perm.primer || _perm == _Perm.denied || (await Permission.microphone.status).isGranted) return;
    await _ensurePermissions();
  }

  /// Back to the reader without the camera.
  void _leaveForVoiceOnly() {
    if (!mounted) return;
    ref.read(cameraOnProvider.notifier).set(false);
    Navigator.of(context).pop(true);
  }

  /// Microphone refused: Voice and Audio can't follow anything, so offer Normal mode.
  void _useNormal() {
    ref.read(settingsProvider.notifier).update((c) => c.copyWith(mode: PromptControlMode.normal));
    _leaveForVoiceOnly();
  }

  Future<void> _startPreview() async {
    if (_opening) return;
    _opening = true;
    try {
      final p = await EchoPrompterCamera.startPreview(_facing);
      if (!mounted) {
        // Left the screen while the camera was opening: release it again.
        EchoPrompterCamera.stopPreview();
        return;
      }
      setState(() => _preview = p);
    } on PlatformException catch (e) {
      if (e.code != 'cancelled' && mounted) setState(() => _error = '$e');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      _opening = false;
    }
  }

  /// iPhone, iPad and Android: no cue strips over the small prompter panel. The "Next" heads-up goes into the panel's
  /// status line, and while a cue holds, Continue takes the place of the pause button in the controls (Stop stays where
  /// it is). This screen only exists on these platforms; the Mac's prompter keeps its own strips.
  bool get _quietCues => Platform.isAndroid || Platform.isIOS;

  /// iPhone, iPad and Android: the panel's footer is split into two sides with the text fading out above it.
  bool get _splitFooter => Platform.isAndroid || Platform.isIOS;

  /// Voice mode's start-up is light, so its script can show before the camera is up. Voice only starts listening
  /// when the take does, so the script stays at the start until then.
  bool get _scriptFirst => isMobile && ref.read(settingsProvider).mode == PromptControlMode.voice;

  /// Sets the prompter up on the current script; recording starts it.
  Future<void> _beginPrompter() async {
    final studio = ref.read(studioProvider);
    final s = ref.read(settingsProvider);
    final prompter = ref.read(prompterProvider.notifier);
    await prompter.begin(
      sessionId: studio.sessionId,
      script: studio.script,
      mode: s.mode,
      audioPath: ref.read(audioPathProvider),
      // One mic stream feeds the video file and the speech engine.
      externalSamples: EchoPrompterCamera.audioSamples,
      startSection: ref.read(startSectionProvider),
    );
  }

  Future<void> _edit() async {
    if (await showScriptEditor(context, ref)) {
      // The sections may have changed, so the clips no longer line up with them.
      await _discardSession();
      _beginPrompter();
    }
  }

  Future<void> _flip() async {
    if (_recording) return;
    _facing = _facing == CameraFacing.front ? CameraFacing.back : CameraFacing.front;
    final p = await EchoPrompterCamera.switchCamera(_facing);
    if (!mounted) {
      EchoPrompterCamera.stopPreview();
      return;
    }
    setState(() => _preview = p);
  }

  /// Releases the camera while the app is in the background and reopens it on
  /// return, so the camera is never held (or the privacy indicator lit) off screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_preview == null) return;
      EchoPrompterCamera.stopPreview();
      setState(() => _preview = null);
    } else if (state == AppLifecycleState.resumed) {
      // Android: back from Settings with a permission refused. Look again (without asking) instead of opening the camera.
      if (Platform.isAndroid && _perm == _Perm.denied) {
        _recheckPermissions();
        return;
      }
      if (_preview == null && _error == null && !_opening) _startPreview();
    }
  }

  bool _rechecking = false;

  /// Reads the camera and microphone status again, without asking. Carries on to the preview once both are granted,
  /// and keeps the "access is off" card (naming what is still off) otherwise.
  Future<void> _recheckPermissions() async {
    if (_rechecking) return;
    _rechecking = true;
    try {
      final needMic = _needsMic(ref.read(settingsProvider).mode);
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      if (!mounted || _perm != _Perm.denied) return;
      if (!(cam.isGranted && (!needMic || mic.isGranted))) {
        setState(() {
          _deniedCam = !cam.isGranted;
          _deniedMic = needMic && !mic.isGranted;
        });
        return;
      }
      setState(() {
        _perm = _Perm.ok;
        _error = null;
      });
      // The screen never got past the permissions: start the rest of its set-up. Otherwise only the preview is missing.
      if (_events == null) {
        await _continueInit();
      } else if (_preview == null && !_opening) {
        await _startPreview();
      }
    } finally {
      _rechecking = false;
    }
  }

  void _startTimer() =>
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed += const Duration(seconds: 1)));

  /// Tells the camera where the narration file is while a take runs, so the video gets the parts that played.
  void _startNarrationTicks() {
    _narrationTicks?.cancel();
    _narrationTicks = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (!_recording) {
        t.cancel();
        return;
      }
      EchoPrompterCamera.narrationTick(position: _prompter.audioPosition, playing: _prompter.audioPlaying);
    });
  }

  Future<void> _togglePause() async {
    HapticFeedback.mediumImpact();
    final prompter = ref.read(prompterProvider.notifier);
    if (_paused) {
      await EchoPrompterCamera.resumeRecording();
      _startTimer();
      setState(() => _paused = false);
      await prompter.play();
    } else {
      _timer?.cancel();
      await EchoPrompterCamera.pauseRecording();
      setState(() => _paused = true);
      await prompter.pause();
    }
  }

  void _home() => Navigator.of(context).popUntil((r) => r.isFirst);

  /// "Done" on the saved card. On Android and iOS the take is finished, so it goes to the scripts list rather than back
  /// to the script's editor.
  void _done() => (Platform.isAndroid || Platform.isIOS) ? _home() : _close();

  /// Close while recording: save the take, or discard it and go back to the
  /// scripts. [home] also leaves for the scripts list after saving.
  Future<void> _confirmClose({bool home = false}) async {
    final choice = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Finish this recording?'),
        content: Text('You have recorded ${_fmt(_elapsed)}. Save it to your gallery, or leave without saving.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep recording')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Exit without saving'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (choice == null || !_recording || !mounted) return;
    await ref.read(prompterProvider.notifier).pause();
    final r = await EchoPrompterCamera.stopRecording();
    if (choice == 'save') {
      await _onStopped(r, 'user');
      if (home && mounted) _home();
      return;
    }
    await _onStopped(null, 'discarded');
    try {
      await File(r.path).delete();
    } catch (_) {}
    if (mounted) _home();
  }

  Future<void> _toggleRecord(bool landscape) async {
    final prompter = ref.read(prompterProvider.notifier);
    final analytics = ref.read(analyticsProvider);
    if (_recording) {
      if (_takeSection != null) {
        // Stopping inside a section leaves a half take: it is dropped and the section waits at its start.
        final section = _takeSection!;
        await _abortTake();
        if (!mounted) return;
        await prompter.goToSection(section);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Take discarded. The section is ready to record again.')));
        return;
      }
      await prompter.pause();
      final r = await EchoPrompterCamera.stopRecording();
      await _onStopped(r, 'user');
      return;
    }
    if (_exporting || _finishingTake) return;
    // Section by section: every take starts at the section's first word, whether it is the first take, a retake or a jump.
    final section = _sectionClips ? ref.read(prompterProvider).sectionIndex : null;
    if (section != null) await prompter.goToSection(section);
    // Voice mode listens from the tap, so the recogniser is up for the first words; the other modes start with the take.
    if (ref.read(settingsProvider).mode == PromptControlMode.voice) await prompter.play();
    if (_useCountdown) {
      for (var i = 3; i >= 1; i--) {
        setState(() => _countdown = i);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
    }
    // Orientation is locked while recording so the file has one orientation.
    await SystemChrome.setPreferredOrientations(
      landscape ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] : [DeviceOrientation.portraitUp],
    );
    final mode = ref.read(settingsProvider).mode;
    await EchoPrompterCamera.setReferenceRoute(_route);
    // iPhone, iPad and Android Narration: the video gets the narration file itself, not what the microphone hears of it.
    final narrationFile = (Platform.isIOS || Platform.isAndroid) && mode == PromptControlMode.recordedAudio ? ref.read(audioPathProvider) : null;
    await EchoPrompterCamera.startRecording(landscape: landscape, narrationPath: narrationFile);
    if (section != null) {
      _session ??= RecordingSession(id: ++_sessionCount, mode: mode, camera: _facing);
      _takeSection = section;
    }
    if (narrationFile != null) _startNarrationTicks();
    analytics.log('video_record_start', {
      'orientation': landscape ? 'landscape' : 'portrait',
      'camera': _facing.name,
      'prompter_mode': mode.name,
      'resolution': '1080p',
      'section': ?section,
    });
    setState(() {
      _recording = true;
      _elapsed = Duration.zero;
    });
    _startTimer();
    if (mode == PromptControlMode.voice) _micStart = DateTime.now();
    // Playback / scrolling starts on the first recorded frame (after the
    // countdown); Audio mode's clock starts here too.
    if (mode != PromptControlMode.voice) await prompter.play();
  }

  Future<void> _onStopped(RecordingResult? r, String reason) async {
    if (_takeSection != null) return _onSectionTakeCut(r, reason);
    _timer?.cancel();
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final a = ref.read(analyticsProvider);
    if (_micStart != null) {
      a.log('mic_stop', {'duration_s': DateTime.now().difference(_micStart!).inSeconds, 'reason': reason});
      _micStart = null;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
    });
    if (r == null) return;
    if (r.narrationFailed) {
      // A video without its narration is not what the reader recorded, so it is not kept: they are told, and can retry.
      a.log('video_narration_failed', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
      try {
        await File(r.path).delete();
      } catch (_) {}
      if (mounted) setState(() => _stopped = (title: _narrationFailedTitle, body: _narrationFailedBody, detail: null, result: null));
      return;
    }
    _recordings++;
    a.log('video_record_stop', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
    final saved = await _saveToGallery(r);
    if (!mounted) return;
    setState(() {
      if (saved == _Save.saved) {
        _showSaved(r, reason);
      } else {
        _unsaved = (result: r, reason: reason, photosOff: saved == _Save.photosOff);
      }
    });
  }

  // --- Section clips -------------------------------------------------------------

  /// The section ended while filming: the take stops after a short tail, becomes the section's keeper, and the end card
  /// offers Retake, Next or Finish.
  Future<void> _finishSectionTake() async {
    final section = _takeSection;
    if (section == null || _finishingTake) return;
    _finishingTake = true;
    try {
      await Future<void>.delayed(_sectionTail);
      if (!mounted || !_recording || _takeSection != section) return;
      final r = await EchoPrompterCamera.stopRecording();
      await _endSectionTake(section);
      if (!mounted) return;
      final a = ref.read(analyticsProvider);
      if (r.narrationFailed) {
        a.log('video_narration_failed', {'duration_s': r.duration.inSeconds, 'reason': r.reason, 'section': section});
        await _deleteFile(r.path);
        if (mounted) setState(() => _stopped = (title: _narrationFailedTitle, body: _narrationFailedBody, detail: null, result: null));
        return;
      }
      _recordings++;
      a.log('video_record_stop', {'duration_s': r.duration.inSeconds, 'reason': r.reason, 'section': section});
      setState(() => _session!.add(section: section, path: r.path, duration: r.duration));
    } finally {
      _finishingTake = false;
    }
  }

  /// Common clean-up after a section take stopped, whatever happened to its file.
  Future<void> _endSectionTake(int section) async {
    _timer?.cancel();
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_micStart != null) {
      ref.read(analyticsProvider).log('mic_stop', {'duration_s': DateTime.now().difference(_micStart!).inSeconds, 'reason': 'section_end'});
      _micStart = null;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _takeSection = null;
    });
  }

  /// Stops the take in progress and throws it away. The earlier clips are untouched.
  Future<void> _abortTake() async {
    final section = _takeSection;
    if (section == null) return;
    await _prompter.pause();
    final r = await EchoPrompterCamera.stopRecording();
    await _deleteFile(r.path);
    await _endSectionTake(section);
    if (mounted) setState(() => _elapsed = Duration.zero);
  }

  /// The system ended a section take (a call, full storage) or it was cut short another way. The part that was filmed
  /// is not a take of the whole section, so it is dropped; the other clips stay.
  Future<void> _onSectionTakeCut(RecordingResult? r, String reason) async {
    final section = _takeSection;
    if (section == null) return;
    if (r != null) await _deleteFile(r.path);
    await _endSectionTake(section);
    if (!mounted) return;
    await _prompter.goToSection(section);
    if (!mounted) return;
    setState(() => _stopped = (
      title: reason == 'storage_full' ? 'Storage is full' : 'Recording stopped',
      body: reason == 'storage_full'
          ? 'There is no space left to keep recording, so this section was not kept. Your other clips are safe. Free up space and record the section again.'
          : 'A call or another app interrupted the recording, so this section was not kept. Your other clips are safe. Record the section again.',
      detail: null,
      result: null,
    ));
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  /// Retake or Next on the end card: the prompter goes to the section and the take starts with the countdown.
  Future<void> _takeSectionAt(int index, bool landscape) async {
    if (_recording || _countdown != null || _exporting) return;
    await _prompter.goToSection(index);
    if (mounted) await _toggleRecord(landscape);
  }

  /// Deletes every clip and starts a fresh session.
  Future<void> _discardSession() async {
    final s = _session;
    _session = null;
    if (s == null) return;
    for (final c in s.clips) {
      await _deleteFile(c.path);
    }
  }

  /// Leaving with clips that were not exported asks what to do with them.
  Future<void> _leave() async {
    if (_exporting) return;
    final s = _session;
    if (s == null || s.clips.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Leave without exporting?'),
        content: Text('You have ${s.keepers.length == 1 ? '1 section clip' : '${s.keepers.length} section clips'} that ${s.keepers.length == 1 ? "isn't" : "aren't"} exported yet.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Discard clips'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, 'export'), child: const Text('Export')),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'export') {
      await _finishRun();
      return;
    }
    await _discardSession();
    if (mounted) Navigator.of(context).pop();
  }

  /// Finish on the end card: choose between the finished video and separate clips.
  Future<void> _finishRun() async {
    final s = _session;
    if (s == null || _exporting) return;
    final choice = await showClipExport(context, session: s, sections: _prompter.sections);
    if (!mounted || choice == null) return;
    if (choice == ClipExportChoice.discard) {
      await _discardSession();
      if (!mounted) return;
      await _prompter.goToSection(0);
      if (mounted) setState(() {});
      return;
    }
    await _exportClips(s, joined: choice == ClipExportChoice.video);
  }

  /// Joins the keeper clips (or copies each one under its section's name), saves them to the gallery and offers Share.
  Future<void> _exportClips(RecordingSession s, {required bool joined}) async {
    final keepers = s.keepers;
    if (keepers.isEmpty) return;
    setState(() => _exporting = true);
    final a = ref.read(analyticsProvider);
    final files = <String>[];
    try {
      if (joined) {
        files.add(keepers.length == 1 ? keepers.first.path : await EchoPrompterCamera.joinClips([for (final c in keepers) c.path]));
      } else {
        final dir = await Directory.systemTemp.createTemp('echoprompter_clips_');
        for (final c in keepers) {
          final label = _prompter.sections[c.sectionIndex].label.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
          final name = 'EchoPrompter ${(c.sectionIndex + 1).toString().padLeft(2, '0')}${label.isEmpty ? '' : ' $label'}.mp4';
          files.add((await File(c.path).copy('${dir.path}/$name')).path);
        }
      }
    } catch (e) {
      a.log('video_export_failed', {'joined': joined, 'clips': keepers.length});
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't prepare the video. Your clips are kept; try again.")));
      return;
    }
    var allSaved = true;
    for (final f in files) {
      if (await _saveToGallery(RecordingResult(f, s.keepersDuration, 'user')) != _Save.saved) allSaved = false;
    }
    a.log('video_export', {'joined': joined, 'clips': keepers.length, 'sections': _prompter.sections.length, 'saved': allSaved});
    _exportFiles.addAll(files);
    // The session is over: the clips go (a single clip that is itself the export stays until the screen closes).
    final done = s.clips.map((c) => c.path).where((p) => !files.contains(p)).toList();
    _session = null;
    for (final p in done) {
      await _deleteFile(p);
    }
    if (!mounted) return;
    final what = joined ? 'Finished video' : (files.length == 1 ? '1 clip' : '${files.length} clips');
    setState(() {
      _exporting = false;
      _exported = (
        title: allSaved ? 'Saved to your gallery' : "Couldn't save to your gallery",
        subtitle: allSaved ? '$what · ${_fmt(s.keepersDuration)}' : '$what is kept on this device. Share it to keep it.',
        files: files,
        warning: !allSaved,
      );
    });
  }

  /// Saves the take to the gallery. When the gallery refuses it, the file is kept and the result says why.
  Future<_Save> _saveToGallery(RecordingResult r) async {
    final a = ref.read(analyticsProvider);
    try {
      await EchoPrompterCamera.saveToGallery(r.path);
      a.log('video_saved', {'duration_s': r.duration.inSeconds});
      return _Save.saved;
    } catch (e) {
      a.log('video_save_failed', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
      // iPhone and iPad report a refused Photos permission with the code 'permission'.
      return e is PlatformException && e.code == 'permission' ? _Save.photosOff : _Save.failed;
    }
  }

  /// The card for a take that is in the gallery: the reader's own stop, or one the system ended.
  void _showSaved(RecordingResult r, String reason) {
    _unsaved = null;
    if (reason == 'user') {
      _saved = r;
    } else {
      _stopped = (
        title: reason == 'storage_full' ? 'Storage is full' : 'Recording stopped',
        body: reason == 'storage_full'
            ? 'There is no space left to keep recording. What you recorded was saved. Free up space to record again.'
            : 'A call or another app interrupted the recording. What you recorded was saved.',
        detail: 'Saved ${_fmt(r.duration)} to your gallery',
        result: r,
      );
    }
  }

  /// Try again on the card shown when the gallery refused the take.
  Future<void> _retrySave() async {
    final u = _unsaved;
    if (u == null || _retrying) return;
    setState(() => _retrying = true);
    final saved = await _saveToGallery(u.result);
    if (!mounted) return;
    setState(() {
      _retrying = false;
      if (saved == _Save.saved) _showSaved(u.result, u.reason);
    });
  }

  static const _saveFailedTitle = "Couldn't save to your gallery";
  static const _photosOffTitle = 'Photos access is off';

  /// After a mode change ended the take: the file is kept, so the reader can try again or share it.
  /// Without Photos access trying again can't work, so sharing is the way to keep the video.
  void _showSaveFailedSnack(RecordingResult r, {bool retried = false, bool photosOff = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(photosOff
            ? "EchoPrompter can't add videos to your Photos. Share this video to keep it, then turn on Photos access in Settings."
            : retried
                ? "Still couldn't save to your gallery. Your video is kept on this device."
                : "Couldn't save to your gallery. Your video is kept on this device."),
        action: retried || photosOff
            ? SnackBarAction(label: 'Share', onPressed: () => _share(r))
            : SnackBarAction(label: 'Try again', onPressed: () => _retrySnack(r)),
      ));
  }

  Future<void> _retrySnack(RecordingResult r) async {
    final saved = await _saveToGallery(r);
    if (saved == _Save.saved) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Saved to your gallery'),
          action: SnackBarAction(label: 'Share', onPressed: () => _share(r)),
        ));
    } else {
      _showSaveFailedSnack(r, retried: true, photosOff: saved == _Save.photosOff);
    }
  }

  @override
  void dispose() {
    // First, so nothing below can keep the camera open.
    EchoPrompterCamera.stopPreview();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _events?.cancel();
    _narrationTicks?.cancel();
    // Mobile: the play button alone switches the microphone here, so leaving the screen must switch it off.
    if (isMobile) Future.microtask(_prompter.pause);
    _analytics.log('video_mode_exit', {'recordings_count': _recordings});
    // Clips that were never exported, and the files an export made, only lived for this screen.
    for (final c in _session?.clips ?? const <Clip>[]) {
      File(c.path).delete().ignore();
    }
    for (final f in _exportFiles) {
      File(f).delete().ignore();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  /// Camera options: the countdown, editing the script, and the prompter height. The camera itself is chosen with Flip.
  Future<void> _showOptions() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Camera options', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('3-2-1 countdown'),
                subtitle: const Text('Count down before recording starts.'),
                value: _useCountdown,
                onChanged: (v) {
                  setState(() => _useCountdown = v);
                  (ctx as Element).markNeedsBuild();
                },
              ),
              if (_sectionClips)
                Row(children: [
                  const Expanded(child: Text('Jump to a section')),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      showSectionsSheet(context);
                    },
                    child: const Text('Open'),
                  ),
                ]),
              Row(children: [
                const Expanded(child: Text('Edit script')),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _edit();
                  },
                  child: const Text('Open'),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Expanded(child: Text('Prompter height')),
                TextButton(
                  onPressed: () => setState(() {
                    for (final land in [true, false]) {
                      ref.read(prefsProvider).remove('EchoPrompter.overlay.${land ? 'l' : 'p'}');
                      _dragFractions.remove(land);
                    }
                  }),
                  child: const Text('Reset'),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  void _close() {
    if (_exporting) return;
    if (_recording && _takeSection != null) {
      _confirmDiscardTake();
    } else if (_recording) {
      _confirmClose();
    } else {
      _leave();
    }
  }

  /// Close while filming a section: the unfinished take goes, the other clips are offered for export.
  Future<void> _confirmDiscardTake() async {
    final discard = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Discard this take?'),
        content: const Text('You are recording a section. Leaving now discards this take. Your other section clips are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep recording')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Discard take'),
          ),
        ],
      ),
    );
    if (discard != true || !_recording || !mounted) return;
    await _abortTake();
    if (mounted) await _leave();
  }

  /// Ends the open take: saved to the gallery or thrown away, without leaving the screen.
  Future<void> _endTake({required bool save}) async {
    if (_takeSection != null) {
      await _abortTake();
      return;
    }
    await ref.read(prompterProvider.notifier).pause();
    final r = await EchoPrompterCamera.stopRecording();
    _timer?.cancel();
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final a = ref.read(analyticsProvider);
    if (_micStart != null) {
      a.log('mic_stop', {'duration_s': DateTime.now().difference(_micStart!).inSeconds, 'reason': save ? 'mode_change_saved' : 'mode_change_discarded'});
      _micStart = null;
    }
    final narrationLost = save && r.narrationFailed;
    var saveResult = _Save.saved;
    if (narrationLost) {
      a.log('video_narration_failed', {'duration_s': r.duration.inSeconds, 'reason': 'mode_change_saved'});
      try {
        await File(r.path).delete();
      } catch (_) {}
    } else if (save) {
      _recordings++;
      a.log('video_record_stop', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
      saveResult = await _saveToGallery(r);
    } else {
      try {
        await File(r.path).delete();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = Duration.zero;
    });
    if (narrationLost) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(_narrationFailedBody)));
    } else if (saveResult != _Save.saved) {
      _showSaveFailedSnack(r, photosOff: saveResult == _Save.photosOff);
    } else if (save) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Saved to your gallery'),
          action: SnackBarAction(label: 'Share', onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(r.path)]))),
        ));
    }
  }

  /// Opens "How to read". Changing it during a take ends the take first, and asks how. The camera stays on only if
  /// the reader still wants it; the reader (voice alone) takes over otherwise.
  Future<void> _changeMode() async {
    if (_countdown != null) return;
    if (_recording) {
      final choice = await showAdaptiveDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: const Text('Finish this recording?'),
          content: Text(_takeSection != null
              ? 'To change how you read, this take has to end first, so it will be discarded. Your other section clips are kept.'
              : 'To change how you read, this recording has to end first. You have recorded ${_fmt(_elapsed)}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep recording')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              child: Text(_takeSection != null ? 'Discard take and continue' : 'Discard and continue'),
            ),
            if (_takeSection == null) TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save and continue')),
          ],
        ),
      );
      if (choice == null || !mounted || !_recording) return;
      await _endTake(save: choice == 'save');
      if (!mounted) return;
    }
    var applied = false;
    final beforeRun = ref.read(settingsProvider).runStyle;
    await showStartOptions(context, apply: StartApply.use, onStart: () async => applied = true);
    if (!mounted || !applied) return;
    if (ref.read(settingsProvider).runStyle != beforeRun) ref.read(prompterProvider.notifier).refreshRunStyle();
    if (!ref.read(cameraOnProvider) || ref.read(settingsProvider).mode == PromptControlMode.normal) _leaveForVoiceOnly();
  }

  Future<void> _share(RecordingResult r) => SharePlus.instance.share(ShareParams(files: [XFile(r.path)]));

  static const _narrationFailedTitle = "Narration wasn't added";
  static const _narrationFailedBody =
      "Your video was recorded, but the narration couldn't be added to it, so it wasn't saved. Please record the take again.";

  /// Ready for another take after a saved or stopped one.
  void _recordAgain() {
    if (_exported != null) {
      // A new run: the shared files can go, and the script starts over from its first section.
      for (final f in _exportFiles) {
        _deleteFile(f);
      }
      _exportFiles.clear();
      _exported = null;
      if (_sectionClips) _prompter.goToSection(0);
    } else if (_sectionClips && _stopped != null) {
      _prompter.goToSection(ref.read(prompterProvider).sectionIndex);
    }
    // A narration that played to its end would otherwise stay there, and the next take would film in silence.
    if (ref.read(settingsProvider).mode == PromptControlMode.recordedAudio) _prompter.restart();
    setState(() {
      _saved = null;
      _stopped = null;
      _unsaved = null;
      _elapsed = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.mode), (_, mode) {
      _routeInput(mode);
      _askMicIfNeeded(mode);
      if (_recording) return;
      if (mode == PromptControlMode.recordedAudio) _route = ReferenceRoute.speaker;
      _beginPrompter();
    });
    // Section by section: the end of the section ends its clip.
    ref.listen(prompterProvider.select((p) => p.sectionDone), (_, done) {
      if (done && _recording && _takeSection != null) _finishSectionTake();
    });
    ref.listen(prompterProvider.select((p) => p.voiceNeedsPack), (_, needs) async {
      if (!needs) return;
      final studio = ref.read(studioProvider);
      if (await confirmLanguagePack(context, ref, studio.script) && context.mounted) {
        await ref.read(prompterProvider.notifier).play();
      }
    });
    ref.listen(prompterProvider.select((p) => p.voiceUnsupported), (_, unsupported) {
      if (unsupported) showVoiceUnsupportedDialog(context, onUseNormal: _useNormal);
    });
    final media = MediaQuery.of(context);
    final size = media.size;
    final scheme = Theme.of(context).colorScheme;
    final landscape = media.orientation == Orientation.landscape;
    final tablet = size.shortestSide >= tabletMinWidth;
    final fraction = _dragFractions[landscape] ?? _fractionFor(landscape, size, _preview);
    final p = _preview;
    final cardOnly = _perm == _Perm.primer || _perm == _Perm.denied || (_error != null && p == null);
    final showScript = !cardOnly && (p != null || (_promptReady && _error == null));
    final ended = _saved != null || _stopped != null || _unsaved != null || _exported != null;
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final audio = mode == PromptControlMode.recordedAudio;

    if (cardOnly) return _cardScreen(context, scheme, mode);

    // Layout: a phone or portrait tablet stacks the prompter over the picture; in landscape the prompter is a panel
    // on the left and the controls sit in a rail on the right edge, within reach of the thumb.
    final panelWidth = size.width * (tablet ? 0.4 : 0.44);
    // iPhone in landscape: the screen is full-bleed, so the Dynamic Island / sensor housing sits over whatever is at the
    // left edge and the rounded corners and home bar on the right. The prompter panel and the controls on the right move in.
    final insetL = Platform.isIOS && landscape ? media.padding.left : 0.0;
    final insetR = Platform.isIOS && landscape ? media.padding.right : 0.0;
    final side = tablet && !landscape ? 64.0 : 12.0;
    final overlayTop = media.padding.top + 58;
    final pill = _countdown != null
        ? ('Starting in $_countdown', const Color(0xFFFFB340), const Color(0xCC1C1C1E), Colors.white)
        : _recording && _paused
            ? ('Paused ${_fmt(_elapsed)}', const Color(0xFFFFB340), const Color(0xEB33291A), const Color(0xFFFFD79A))
            : _recording
                ? ('REC ${_fmt(_elapsed)}', Colors.white, const Color(0xFFD70015), Colors.white)
                : p == null
                    ? ('Opening…', const Color(0xFFA1A1A6), const Color(0xCC1C1C1E), Colors.white)
                    : (_facing == CameraFacing.back ? 'Back camera' : 'Camera ready', const Color(0xFF30D158), const Color(0xCC1C1C1E), Colors.white);

    final topBar = Positioned(
      left: landscape ? panelWidth + 24 : 8,
      right: 8 + insetR,
      top: landscape ? 12 : media.padding.top + 4,
      height: 52,
      child: Row(children: [
        ChromeButton(icon: Icons.close, tooltip: 'Close', onPressed: _close),
        const SizedBox(width: 8),
        Expanded(
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: pill.$3, borderRadius: BorderRadius.circular(17)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: pill.$2, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                // Shrinks to the room the buttons leave, so the label can never overflow the bar.
                Flexible(
                  child: Text(
                    pill.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pill.$4, fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ModeChip(mode: mode, camera: true, locked: _recording, onPressed: _changeMode),
        const SizedBox(width: 8),
        ChromeButton(label: 'Aa', tooltip: 'Reading settings', onPressed: () => showReadingSettings(context)),
      ]),
    );

    final flip = ChromeButton(icon: Icons.cameraswitch_outlined, tooltip: 'Flip camera', size: 56, iconSize: 26, onPressed: _recording ? null : _flip);
    final recordButton = Semantics(
      button: true,
      label: _recording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: p == null || _countdown != null ? null : () => _toggleRecord(landscape),
        // Dimmed until the camera is up, since it can't record before then.
        child: AnimatedOpacity(
          opacity: p == null ? 0.38 : 1,
          duration: _fadeIn,
          child: Container(
            width: _recordButtonSize,
            height: _recordButtonSize,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            padding: const EdgeInsets.all(6),
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(_recording ? 6 : 40)),
            ),
          ),
        ),
      ),
    );
    final rightButton = _recording
        ? ChromeButton(
            icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tooltip: _paused ? 'Resume recording' : 'Pause recording',
            size: 56,
            iconSize: 28,
            onPressed: _togglePause,
          )
        : ChromeButton(icon: Icons.more_horiz, tooltip: 'Camera options', size: 56, iconSize: 26, onPressed: _showOptions);

    // Android, a hold cue holding the take: "Holding at cue" where the flip button is (it is off during a take
    // anyway) and Continue where the pause button is. Stop stays in the middle.
    // Voice starts reading at the tap, so a hold cue at the very start already holds during the 3-2-1 countdown.
    final holdingCue = _quietCues && (_recording || _countdown != null) && ref.watch(prompterProvider.select((p) => p.cueHolding >= 0));
    const holdInk = Color(0xFF111214);
    final Widget leftSlot = holdingCue
        ? Semantics(
            liveRegion: true,
            child: Text(
              landscape ? 'Holding\nat cue' : 'Holding at cue',
              textAlign: landscape ? TextAlign.center : TextAlign.start,
              maxLines: 2,
              // White with a soft shadow: the controls row can overlap the bottom edge of the camera picture, and grey
              // text is hard to read over it.
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                decoration: TextDecoration.none,
                shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 6)],
              ),
            ),
          )
        : flip;
    final Widget rightSlot = !holdingCue
        ? rightButton
        : landscape
            ? SizedBox(
                width: 56,
                height: 56,
                child: IconButton.filled(
                  tooltip: 'Continue',
                  onPressed: () => unawaited(_prompter.continueFromHold()),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  style: IconButton.styleFrom(backgroundColor: cueQuietNext, foregroundColor: holdInk),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 56,
                  child: TextButton(
                    onPressed: () => unawaited(_prompter.continueFromHold()),
                    style: TextButton.styleFrom(
                      backgroundColor: cueQuietNext,
                      foregroundColor: holdInk,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(width: 6),
                      Icon(Icons.play_arrow_outlined, size: 20),
                    ]),
                  ),
                ),
              );

    // The main controls sit at the bottom, within reach of the thumb.
    final shutterBottom = media.padding.bottom + 16;
    final controls = landscape
        ? Positioned(
            right: 16 + insetR,
            top: 0,
            bottom: 0,
            width: 72,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [leftSlot, const SizedBox(height: 22), recordButton, const SizedBox(height: 22), rightSlot]),
            ),
          )
        : Positioned(
            left: tablet ? 160 : 32,
            right: tablet ? 160 : 32,
            bottom: shutterBottom,
            height: 80,
            // Equal side slots keep the record button centred.
            child: Row(children: [
              Expanded(child: Align(alignment: Alignment.centerLeft, child: leftSlot)),
              recordButton,
              Expanded(child: Align(alignment: Alignment.centerRight, child: rightSlot)),
            ]),
          );
    final hintBottom = landscape ? 16.0 : shutterBottom + 80 + 14;
    final pausedHint = _paused
        ? Positioned(
            left: landscape ? panelWidth + 24 : 24,
            right: landscape ? 120 + insetR : 24,
            bottom: hintBottom,
            child: const _Hint("The camera can't change during a take. Stop the recording to switch it."),
          )
        : null;
    final audioHint = audio && !_recording && p != null
        ? Positioned(
            left: landscape ? panelWidth + 24 : 24,
            right: landscape ? 120 + insetR : 24,
            bottom: hintBottom,
            child: const _Hint('Your narration is added to the video from its file, however you listen.', icon: Icons.volume_up_outlined),
          )
        : null;

    final overlay = Positioned(
      left: landscape ? 12 + insetL : side,
      right: landscape ? null : side,
      // The panel keeps its right edge: it only loses the width the inset took at its left.
      width: landscape ? panelWidth - insetL : null,
      top: landscape ? 12 : overlayTop,
      bottom: landscape ? 12 : null,
      height: landscape ? null : size.height * fraction,
      // Appears together with the camera, or before it in Voice mode (see _init).
      child: AnimatedOpacity(
        opacity: showScript ? 1 : 0,
        duration: _fadeIn,
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PromptView(
              style: PromptLayoutStyle.compact,
              backgroundOpacity: ref.watch(settingsProvider.select((s) => s.opacity)) * 0.4,
              showControls: false,
              showProgress: true,
              // Portrait's drag handle sits over the panel's bottom 24.
              bottomInset: landscape ? 0 : 24,
              quietCues: _quietCues,
              splitFooter: _splitFooter,
            ),
          ),
          if (!landscape)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => setState(() {
                  _dragFractions[landscape] = ((fraction * size.height + d.delta.dy) / size.height).clamp(0.15, 0.7);
                }),
                onVerticalDragEnd: (_) => _saveFraction(landscape, _dragFractions[landscape] ?? fraction),
                child: const SizedBox(height: 24, child: Center(child: Icon(Icons.drag_handle, color: Colors.white70, size: 18))),
              ),
            ),
        ]),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        if (!showScript && _error == null) const Center(child: CircularProgressIndicator(color: Colors.white54)),
        if (p != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: _fadeIn,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Center(
              child: AspectRatio(
                // The preview is upright, so its shape follows the screen orientation, not the one it started in.
                aspectRatio: landscape == (p.aspectRatio >= 1) ? p.aspectRatio : 1 / p.aspectRatio,
                child: Transform.flip(
                  flipX: p.mirrored,
                  child: RotatedBox(quarterTurns: p.quarterTurns, child: Texture(textureId: p.textureId)),
                ),
              ),
            ),
          ),
        if (ended) Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.55))),
        overlay,
        topBar,
        if (_countdown != null)
          Center(child: Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 120, fontWeight: FontWeight.bold))),
        if (!ended) controls,
        // Section by section: the script has stopped at the end of a section and waits.
        if (!ended && ref.watch(prompterProvider.select((p) => p.sectionDone)) && ref.read(prompterProvider.notifier).sectionRun)
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: const Alignment(0, -0.1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SectionEndCard(
                    compact: MediaQuery.sizeOf(context).height < 500,
                    onSections: () => showSectionsSheet(context),
                    // Each section is a clip: Retake and Next start a take, Finish exports what was recorded.
                    onRetake: () => _takeSectionAt(ref.read(prompterProvider).sectionIndex, landscape),
                    onNext: () => _takeSectionAt(ref.read(prompterProvider).sectionIndex + 1, landscape),
                    onFinish: _session == null ? null : _finishRun,
                  ),
                ),
              ),
            ),
          ),
        ?pausedHint,
        ?audioHint,
        if (_saved != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 + insetR : 12,
            bottom: media.padding.bottom + 12,
            child: CameraResultSheet(
              title: 'Saved to your gallery',
              subtitle: '${_fmt(_saved!.duration)} · 1080p',
              onShare: () => _share(_saved!),
              onRecordAgain: _recordAgain,
              onDone: _done,
            ),
          ),
        if (_exported != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 + insetR : 12,
            bottom: media.padding.bottom + 12,
            child: CameraResultSheet(
              title: _exported!.title,
              subtitle: _exported!.subtitle,
              warning: _exported!.warning,
              onShare: () => SharePlus.instance.share(ShareParams(files: [for (final f in _exported!.files) XFile(f)])),
              onRecordAgain: _recordAgain,
              onDone: _done,
            ),
          ),
        if (_exporting)
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.6),
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Preparing your video…', style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
                  ]),
                ),
              ),
            ),
          ),
        if (_unsaved != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 + insetR : 12,
            bottom: media.padding.bottom + 12,
            child: Material(
              color: scheme.surfaceContainerHigh,
              elevation: 8,
              borderRadius: BorderRadius.circular(isApple ? 20 : 28),
              child: CameraStateCard(
                icon: Icons.warning_amber_rounded,
                tone: CameraCardTone.error,
                title: _unsaved!.photosOff ? _photosOffTitle : _saveFailedTitle,
                body: _unsaved!.photosOff
                    ? "EchoPrompter can't add videos to your Photos. Your video is kept in the app: share it to save it elsewhere. Turning Photos access on in Settings restarts the app, so share it first."
                    : switch (_unsaved!.reason) {
                      'storage_full' => 'There is no space left on this device, so the recording stopped and the video could not go to your gallery. It is kept in the app. Free up space and try again, or share it to save it elsewhere.',
                      'user' => 'Your video is kept in the app. Check that your device has free space and try again, or share it to save it elsewhere.',
                      _ => 'A call or another app interrupted the recording, and the video could not go to your gallery. It is kept in the app. Try again, or share it to save it elsewhere.',
                    },
                detail: '${_fmt(_unsaved!.result.duration)} recorded, not saved yet',
                primaryLabel: _unsaved!.photosOff ? 'Share' : _retrying ? 'Saving…' : 'Try again',
                onPrimary: _unsaved!.photosOff ? () => _share(_unsaved!.result) : _retrying ? () {} : _retrySave,
                secondaryLabel: _unsaved!.photosOff ? 'Open Settings' : 'Share',
                onSecondary: _unsaved!.photosOff ? openAppSettings : () => _share(_unsaved!.result),
              ),
            ),
          ),
        if (_stopped != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 + insetR : 12,
            bottom: media.padding.bottom + 12,
            child: Material(
              color: scheme.surfaceContainerHigh,
              elevation: 8,
              borderRadius: BorderRadius.circular(isApple ? 20 : 28),
              child: CameraStateCard(
                icon: Icons.warning_amber_rounded,
                tone: CameraCardTone.warning,
                title: _stopped!.title,
                body: _stopped!.body,
                detail: _stopped!.detail,
                primaryLabel: _stopped!.result == null ? 'Record again' : 'Share what was saved',
                onPrimary: _stopped!.result == null ? _recordAgain : () => _share(_stopped!.result!),
                secondaryLabel: _stopped!.result == null ? 'Done' : 'Record again',
                onSecondary: _stopped!.result == null ? _close : _recordAgain,
              ),
            ),
          ),
      ]),
    );
  }

  /// The screen when there is nothing to film yet: the explainer, a refused permission, or a camera that won't open.
  Widget _cardScreen(BuildContext context, ColorScheme scheme, PromptControlMode mode) {
    final apple = isApple;
    final Widget card;
    if (_perm == _Perm.primer) {
      card = CameraStateCard(
        icon: Icons.videocam_outlined,
        title: 'Record yourself while you read',
        body: _needsMic(mode)
            ? 'EchoPrompter needs your camera and microphone. Your video stays on this device until you share it.'
            : 'EchoPrompter needs your camera. Your narration is added to the video from its file, so the microphone is not used. Your video stays on this device until you share it.',
        primaryLabel: 'Continue',
        onPrimary: () => _primer?.complete(true),
        secondaryLabel: 'Not now, use voice only',
        onSecondary: () => _primer?.complete(false),
      );
    } else if (_perm == _Perm.denied) {
      final both = _deniedCam && _deniedMic;
      final micOnly = _deniedMic && !_deniedCam;
      card = CameraStateCard(
        icon: micOnly ? Icons.mic_off_outlined : Icons.videocam_off_outlined,
        tone: CameraCardTone.warning,
        title: both ? 'Camera and microphone are off' : micOnly ? 'Microphone access is off' : 'Camera access is off',
        body: both
            ? (apple ? 'Turn both on for EchoPrompter in Settings to record video while you read.' : 'Turn both permissions on in the app settings to record video while you read.')
            : micOnly
                ? (apple ? 'Voice mode follows what you say, so it needs the microphone. Turn it on in Settings.' : 'Voice mode needs the microphone. Turn it on in the app settings.')
                : (apple ? 'Turn on Camera for EchoPrompter in Settings to record video.' : 'Camera permission was denied. Turn it on in the app settings to record video.'),
        primaryLabel: apple ? 'Open Settings' : 'Open app settings',
        onPrimary: openAppSettings,
        secondaryLabel: micOnly ? 'Use Auto-scroll mode' : 'Continue with voice only',
        onSecondary: micOnly ? _useNormal : _leaveForVoiceOnly,
      );
    } else {
      card = CameraStateCard(
        icon: Icons.warning_amber_rounded,
        tone: CameraCardTone.error,
        title: 'Camera unavailable',
        body: 'Another app may be using the camera, or this device has none EchoPrompter can use. Close other camera apps and try again. You can keep reading with voice only.',
        primaryLabel: 'Try again',
        onPrimary: () {
          setState(() => _error = null);
          _startPreview();
        },
        secondaryLabel: 'Continue with voice only',
        onSecondary: _leaveForVoiceOnly,
      );
    }
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ),
          Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: card),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _Perm { checking, primer, denied, ok }

/// How a save to the gallery ended: it worked, Photos access is off (iPhone, iPad), or it failed for another reason.
enum _Save { saved, photosOff, failed }

/// A short explanation floating above the controls.
class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.icon = Icons.info_outline});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xD11C1C1E), borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3))),
        ]),
      ),
    );
  }
}
