import 'dart:async';
import 'dart:io';

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
import '../../services/providers.dart';
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
  ({String title, String body, String? detail, RecordingResult? result})? _stopped;

  // Overlay height as a fraction of the screen, remembered per orientation.
  double _fractionFor(bool landscape) =>
      ref.read(prefsProvider).getDouble('EchoPrompter.overlay.${landscape ? 'l' : 'p'}') ?? (landscape ? 0.4 : 0.3);
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
    // Audio mode's video must contain the audio file, so it plays out loud and
    // the microphone records it; other modes pace silently or into headphones.
    _route = ref.read(settingsProvider).mode == PromptControlMode.recordedAudio
        ? ReferenceRoute.speaker
        : await EchoPrompterCamera.headphonesConnected ? ReferenceRoute.headphones : ReferenceRoute.silent;
    _events = EchoPrompterCamera.events.listen((e) {
      final type = e['type'];
      if (type == 'interrupted' || type == 'storage_full') {
        _onStopped(null, '$type');
        if (mounted && _saved == null && _stopped == null) {
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

  /// Whether a take in [mode] listens to the microphone. iPhone and iPad Narration takes don't: the video gets the
  /// narration file itself (see `_toggleRecord`), so those takes only need the camera.
  bool _needsMic(PromptControlMode mode) => !(Platform.isIOS && mode == PromptControlMode.recordedAudio);

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
    if (await showScriptEditor(context, ref)) _beginPrompter();
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
      if (_preview == null && _error == null && !_opening) _startPreview();
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
      await prompter.pause();
      final r = await EchoPrompterCamera.stopRecording();
      await _onStopped(r, 'user');
      return;
    }
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
    // iPhone/iPad Narration: the video gets the narration file itself, not what the microphone hears of it.
    final narrationFile = Platform.isIOS && mode == PromptControlMode.recordedAudio ? ref.read(audioPathProvider) : null;
    await EchoPrompterCamera.startRecording(landscape: landscape, narrationPath: narrationFile);
    if (narrationFile != null) _startNarrationTicks();
    analytics.log('video_record_start', {
      'orientation': landscape ? 'landscape' : 'portrait',
      'camera': _facing.name,
      'prompter_mode': mode.name,
      'resolution': '1080p',
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
    _recordings++;
    a.log('video_record_stop', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
    try {
      await EchoPrompterCamera.saveToGallery(r.path);
      a.log('video_saved', {'duration_s': r.duration.inSeconds});
    } catch (_) {}
    if (!mounted) return;
    setState(() {
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
    });
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

  void _close() => _recording ? _confirmClose() : Navigator.of(context).pop();

  /// Ends the open take: saved to the gallery or thrown away, without leaving the screen.
  Future<void> _endTake({required bool save}) async {
    await ref.read(prompterProvider.notifier).pause();
    final r = await EchoPrompterCamera.stopRecording();
    _timer?.cancel();
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    final a = ref.read(analyticsProvider);
    if (_micStart != null) {
      a.log('mic_stop', {'duration_s': DateTime.now().difference(_micStart!).inSeconds, 'reason': save ? 'mode_change_saved' : 'mode_change_discarded'});
      _micStart = null;
    }
    if (save) {
      _recordings++;
      a.log('video_record_stop', {'duration_s': r.duration.inSeconds, 'reason': r.reason});
      try {
        await EchoPrompterCamera.saveToGallery(r.path);
        a.log('video_saved', {'duration_s': r.duration.inSeconds});
      } catch (_) {}
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
    if (save) {
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
          content: Text('To change how you read, this recording has to end first. You have recorded ${_fmt(_elapsed)}.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep recording')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Discard and continue'),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save and continue')),
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

  /// Ready for another take after a saved or stopped one.
  void _recordAgain() => setState(() {
    _saved = null;
    _stopped = null;
    _elapsed = Duration.zero;
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.mode), (_, mode) {
      _routeInput(mode);
      _askMicIfNeeded(mode);
      if (_recording) return;
      if (mode == PromptControlMode.recordedAudio) _route = ReferenceRoute.speaker;
      _beginPrompter();
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
    final fraction = _dragFractions[landscape] ?? _fractionFor(landscape);
    final p = _preview;
    final cardOnly = _perm == _Perm.primer || _perm == _Perm.denied || (_error != null && p == null);
    final showScript = !cardOnly && (p != null || (_promptReady && _error == null));
    final ended = _saved != null || _stopped != null;
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    final audio = mode == PromptControlMode.recordedAudio;

    if (cardOnly) return _cardScreen(context, scheme, mode);

    // Layout: a phone or portrait tablet stacks the prompter over the picture; in landscape the prompter is a panel
    // on the left and the controls sit in a rail on the right edge, within reach of the thumb.
    final panelWidth = size.width * (tablet ? 0.4 : 0.44);
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
      right: 8,
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

    // The main controls sit at the bottom, within reach of the thumb.
    final shutterBottom = media.padding.bottom + 16;
    final controls = landscape
        ? Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            width: 72,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [flip, const SizedBox(height: 22), recordButton, const SizedBox(height: 22), rightButton]),
            ),
          )
        : Positioned(
            left: tablet ? 160 : 32,
            right: tablet ? 160 : 32,
            bottom: shutterBottom,
            height: 80,
            // Equal side slots keep the record button centred.
            child: Row(children: [
              Expanded(child: Align(alignment: Alignment.centerLeft, child: flip)),
              recordButton,
              Expanded(child: Align(alignment: Alignment.centerRight, child: rightButton)),
            ]),
          );
    final hintBottom = landscape ? 16.0 : shutterBottom + 80 + 14;
    final pausedHint = _paused
        ? Positioned(
            left: landscape ? panelWidth + 24 : 24,
            right: landscape ? 120 : 24,
            bottom: hintBottom,
            child: const _Hint("The camera can't change during a take. Stop the recording to switch it."),
          )
        : null;
    final audioHint = audio && !_recording && p != null
        ? Positioned(
            left: landscape ? panelWidth + 24 : 24,
            right: landscape ? 120 : 24,
            bottom: hintBottom,
            child: _Hint(
              Platform.isIOS
                  ? 'Your narration is added to the video from its file, however you listen.'
                  : 'Your narration plays on the speaker so the video records it.',
              icon: Icons.volume_up_outlined,
            ),
          )
        : null;

    final overlay = Positioned(
      left: landscape ? 12 : side,
      right: landscape ? null : side,
      width: landscape ? panelWidth : null,
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
                  child: SectionEndCard(compact: MediaQuery.sizeOf(context).height < 500, onSections: () => showSectionsSheet(context)),
                ),
              ),
            ),
          ),
        ?pausedHint,
        ?audioHint,
        if (_saved != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 : 12,
            bottom: media.padding.bottom + 12,
            child: CameraResultSheet(
              title: 'Saved to your gallery',
              subtitle: '${_fmt(_saved!.duration)} · 1080p',
              onShare: () => _share(_saved!),
              onRecordAgain: _recordAgain,
              onDone: _close,
            ),
          ),
        if (_stopped != null)
          Positioned(
            left: landscape ? panelWidth + 28 : 12,
            right: landscape ? 24 : 12,
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
