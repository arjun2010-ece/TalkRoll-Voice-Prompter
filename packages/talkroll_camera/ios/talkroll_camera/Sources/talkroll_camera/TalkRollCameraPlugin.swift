import AVFoundation
import Flutter
import Photos
import UIKit

/// AVCaptureSession preview into a Flutter texture, plus an AVAssetWriter
/// recorder. The same audio sample buffers feed the file and the speech
/// engine (16 kHz mono float), so Voice mode works while recording.
public class TalkRollCameraPlugin: NSObject, FlutterPlugin, FlutterTexture, FlutterStreamHandler,
    AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
{
    private let textures: FlutterTextureRegistry
    private var textureId: Int64 = -1
    private let queue = DispatchQueue(label: "talkroll.camera")
    private var session: AVCaptureSession?
    private var videoOut: AVCaptureVideoDataOutput?
    private var audioOut: AVCaptureAudioDataOutput?
    private var latest: CVPixelBuffer?
    private let latestLock = NSLock()
    private var front = true
    private var orientationLocked = false
    private var lockedAngle: CGFloat = 90
    private var interfaceAngle: CGFloat?  // guarded by latestLock
    private var rotationCoordinator: Any?  // AVCaptureDevice.RotationCoordinator (iOS 17+)
    private var rotationObserver: NSKeyValueObservation?

    private var audioSink: FlutterEventSink?
    private var eventSink: FlutterEventSink?
    private var audioListening = false
    // The native speech recogniser reads this capture too (see SpeechRecognizerChannel).
    var speech: SpeechRecognizerChannel?
    private var speechActive = false
    // Voice mode may listen through a connected headset microphone; Audio mode must hear the speaker, so it
    // uses the built-in one.
    private var preferHeadsetMic = true

    // Writer state (touched on `queue` only).
    private var writer: AVAssetWriter?
    private var vInput: AVAssetWriterInput?
    private var aInput: AVAssetWriterInput?
    private var writerStarted = false
    private var startTime: CMTime = .invalid
    private var lastTime: CMTime = .zero
    // Pause support: samples are dropped while paused and later ones are
    // shifted back by `pausedOffset` so the file has no gap.
    private var paused = false
    private var resuming = false
    private var pausedOffset: CMTime = .zero
    private var lastRawVideo: CMTime = .zero
    private var outputURL: URL?
    private var landscapeRecording = false
    private var recordingHeight = 1080
    private var useHEVC = false
    // Narration mode: the take has no microphone. `narrationPath` is the file that plays while filming; the
    // stretches of it that were heard are noted from the position Dart reports, and put into the video at the end.
    private var narrationPath: String?
    private var narrationSegments: [NarrationSegment] = []
    private var narrationOpen = false

    private var converter: AVAudioConverter?
    private var converterSource: AVAudioFormat?

    init(textures: FlutterTextureRegistry) { self.textures = textures }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let p = TalkRollCameraPlugin(textures: registrar.textures())
        let ch = FlutterMethodChannel(name: "com.talkroll/camera", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(p, channel: ch)
        FlutterEventChannel(name: "com.talkroll/camera/audio", binaryMessenger: registrar.messenger())
            .setStreamHandler(AudioHandler(p))
        FlutterEventChannel(name: "com.talkroll/camera/events", binaryMessenger: registrar.messenger())
            .setStreamHandler(p)
        SpeechRecognizerChannel.register(with: registrar, camera: p)
        FileTranscriberChannel.register(with: registrar)
        NotificationCenter.default.addObserver(p, selector: #selector(interrupted), name: .AVCaptureSessionWasInterrupted, object: nil)
        NotificationCenter.default.addObserver(p, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(p, selector: #selector(deviceRotated), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(p, selector: #selector(interfaceRotated), name: UIApplication.didChangeStatusBarOrientationNotification, object: nil)
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    // Events stream
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { eventSink = events; return nil }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? { eventSink = nil; return nil }

    // Audio stream: starts the mic only while a Dart listener exists.
    private final class AudioHandler: NSObject, FlutterStreamHandler {
        let p: TalkRollCameraPlugin
        init(_ p: TalkRollCameraPlugin) { self.p = p }
        func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
            self.p.audioSink = events; self.p.audioListening = true; self.p.queue.async { self.p.updateAudioInput() }; return nil
        }
        func onCancel(withArguments arguments: Any?) -> FlutterError? {
            self.p.audioSink = nil; self.p.audioListening = false; self.p.queue.async { self.p.updateAudioInput() }; return nil
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startPreview": startPreview(front: (a["facing"] as? String) == "front", result: result)
        case "stopPreview": stopPreview(); result(nil)
        case "startRecording":
            landscapeRecording = a["landscape"] as? Bool ?? false
            recordingHeight = a["height"] as? Int ?? 1080
            useHEVC = a["hevc"] as? Bool ?? false
            narrationPath = a["narrationPath"] as? String
            queue.async { do { try self.beginWriter(); DispatchQueue.main.async { result(nil) } }
                catch { DispatchQueue.main.async { result(FlutterError(code: "record", message: "\(error)", details: nil)) } } }
        case "pauseRecording": queue.async { if self.writer != nil { self.paused = true; self.resuming = false }; DispatchQueue.main.async { result(nil) } }
        case "resumeRecording": queue.async { if self.paused { self.paused = false; self.resuming = true }; DispatchQueue.main.async { result(nil) } }
        case "narrationTick":
            let ms = a["positionMs"] as? Int ?? 0, playing = a["playing"] as? Bool ?? false
            queue.async { self.narrationTick(positionMs: ms, playing: playing); DispatchQueue.main.async { result(nil) } }
        case "stopRecording": finishRecording(reason: a["reason"] as? String ?? "user", result: result)
        case "joinClips":
            let urls = (a["paths"] as? [String] ?? []).map { URL(fileURLWithPath: $0) }
            let output = FileManager.default.temporaryDirectory.appendingPathComponent("talkroll_joined_\(Int(Date().timeIntervalSince1970 * 1000)).mp4")
            Task {
                do {
                    try await ClipJoin.join(urls, to: output)
                    DispatchQueue.main.async { result(output.path) }
                } catch {
                    DispatchQueue.main.async { result(FlutterError(code: "join", message: "\(error)", details: nil)) }
                }
            }
        case "saveToGallery": saveToGallery(a["path"] as? String ?? "", result: result)
        case "headphonesConnected":
            let outs = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portType)
            result(outs.contains { [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio].contains($0) })
        case "setReferenceRoute": result(nil) // reference audio always plays on the speaker
        case "setInputPreference":
            let headset = a["headset"] as? Bool ?? true
            queue.async { self.preferHeadsetMic = headset; self.applyPreferredInput(); DispatchQueue.main.async { result(nil) } }
        default: result(FlutterMethodNotImplemented)
        }
    }

    // MARK: Preview

    private func startPreview(front: Bool, result: @escaping FlutterResult) {
        stopPreview()
        self.front = front
        updateInterfaceAngle()
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { DispatchQueue.main.async { result(FlutterError(code: "permission", message: "Camera access denied", details: nil)) }; return }
            self.queue.async {
                let s = AVCaptureSession()
                s.beginConfiguration()
                s.sessionPreset = .hd1920x1080
                guard let dev = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
                      let input = try? AVCaptureDeviceInput(device: dev), s.canAddInput(input) else {
                    DispatchQueue.main.async { result(FlutterError(code: "camera", message: "No camera", details: nil)) }
                    return
                }
                s.addInput(input)
                if #available(iOS 17.0, *) {
                    let rc = AVCaptureDevice.RotationCoordinator(device: dev, previewLayer: nil)
                    self.rotationCoordinator = rc
                    self.rotationObserver = rc.observe(\.videoRotationAngleForHorizonLevelCapture) { [weak self] _, _ in
                        self?.queue.async { self?.updateVideoRotation() }
                    }
                }
                let v = AVCaptureVideoDataOutput()
                v.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                v.alwaysDiscardsLateVideoFrames = true
                v.setSampleBufferDelegate(self, queue: self.queue)
                if s.canAddOutput(v) { s.addOutput(v) }
                self.videoOut = v
                s.commitConfiguration()
                self.session = s
                self.updateVideoRotation()
                s.startRunning()
                DispatchQueue.main.async {
                    self.textureId = self.textures.register(self)
                    let landscape = self.currentAngle() == 0 || self.currentAngle() == 180
                    result(["textureId": self.textureId, "width": landscape ? 1920 : 1080,
                            "height": landscape ? 1080 : 1920, "mirrored": front, "quarterTurns": 0])
                }
            }
        }
    }

    private func stopPreview() {
        if writer != nil { finishRecording(reason: "user", result: { _ in }) }
        queue.sync {
            session?.stopRunning(); session = nil; videoOut = nil; audioOut = nil
            rotationObserver = nil; rotationCoordinator = nil
            latestLock.lock(); latest = nil; latestLock.unlock()
        }
        if textureId >= 0 { textures.unregisterTexture(textureId); textureId = -1 }
    }

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        latestLock.lock(); defer { latestLock.unlock() }
        guard let b = latest else { return nil }
        return Unmanaged.passRetained(b)
    }

    // MARK: Orientation (locked while recording so the file has one orientation)

    /// The orientation the app's screen is actually in. The device orientation can disagree with it (iPad
    /// rotation lock, face up/down), which would show the preview upside down, so it is preferred.
    private func updateInterfaceAngle() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var angle: CGFloat?
        switch scene?.interfaceOrientation {
        case .landscapeRight: angle = 0
        case .landscapeLeft: angle = 180
        case .portraitUpsideDown: angle = 270
        case .portrait: angle = 90
        default: angle = nil
        }
        latestLock.lock(); interfaceAngle = angle; latestLock.unlock()
    }

    @objc private func interfaceRotated() {
        updateInterfaceAngle()
        queue.async { self.updateVideoRotation() }
    }

    private func currentAngle() -> CGFloat {
        if orientationLocked { return lockedAngle }
        // The coordinator knows how the sensor is mounted on this device (the iPad front camera sits on the
        // long edge, so fixed angles come out upside down there).
        if #available(iOS 17.0, *), let rc = rotationCoordinator as? AVCaptureDevice.RotationCoordinator {
            return rc.videoRotationAngleForHorizonLevelCapture
        }
        latestLock.lock(); let screen = interfaceAngle; latestLock.unlock()
        if let screen { return screen }
        switch UIDevice.current.orientation {
        case .landscapeLeft: return 0     // home button on the right
        case .landscapeRight: return 180
        case .portraitUpsideDown: return 270
        default: return 90
        }
    }

    @objc private func deviceRotated() { queue.async { self.updateVideoRotation() } }

    private func updateVideoRotation() {
        guard let c = videoOut?.connection(with: .video) else { return }
        let angle = currentAngle()
        if #available(iOS 17.0, *) {
            if c.isVideoRotationAngleSupported(angle) { c.videoRotationAngle = angle }
        } else if c.isVideoOrientationSupported {
            switch angle {
            case 0: c.videoOrientation = .landscapeRight
            case 180: c.videoOrientation = .landscapeLeft
            case 270: c.videoOrientation = .portraitUpsideDown
            default: c.videoOrientation = .portrait
            }
        }
    }

    // MARK: Audio capture (one stream → file + speech)

    /// Called by the speech recogniser when it starts or stops needing the microphone.
    func setSpeechActive(_ active: Bool) {
        queue.async { self.speechActive = active; self.updateAudioInput() }
    }

    // The microphone alone, for Voice mode on the reading screen, where there is no camera preview (so no `session`).
    private var micSession: AVCaptureSession?

    /// Opens or closes a microphone-only capture. Without a camera session nothing else delivers audio, and the
    /// recogniser (like Android's own audio source and the Mac's own capture) would listen to silence.
    private func updateMicOnlyCapture(need: Bool) {
        if !need {
            if let s = micSession {
                s.stopRunning()
                micSession = nil
                if audioOut != nil { audioOut = nil }
            }
            return
        }
        guard micSession == nil else { return }
        configureAudioSession()
        let s = AVCaptureSession()
        guard let mic = AVCaptureDevice.default(for: .audio), let input = try? AVCaptureDeviceInput(device: mic), s.canAddInput(input) else { return }
        s.addInput(input)
        let o = AVCaptureAudioDataOutput()
        o.setSampleBufferDelegate(self, queue: queue)
        guard s.canAddOutput(o) else { return }
        s.addOutput(o)
        audioOut = o
        micSession = s
        s.startRunning()
    }

    private func updateAudioInput() {
        guard let s = session else {
            updateMicOnlyCapture(need: audioListening || speechActive)
            return
        }
        // A camera session now carries the audio; drop the microphone-only capture.
        if micSession != nil { updateMicOnlyCapture(need: false) }
        let need = audioListening || speechActive || aInput != nil
        if need && audioOut == nil {
            configureAudioSession()
            s.beginConfiguration()
            if let mic = AVCaptureDevice.default(for: .audio), let input = try? AVCaptureDeviceInput(device: mic), s.canAddInput(input) {
                s.addInput(input)
                let o = AVCaptureAudioDataOutput()
                o.setSampleBufferDelegate(self, queue: queue)
                if s.canAddOutput(o) { s.addOutput(o); audioOut = o }
            }
            s.commitConfiguration()
        } else if !need, let o = audioOut {
            s.beginConfiguration()
            s.removeOutput(o)
            s.inputs.filter { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }.forEach(s.removeInput)
            s.commitConfiguration()
            audioOut = nil
        }
    }

    private func configureAudioSession() {
        let a = AVAudioSession.sharedInstance()
        // Bluetooth headsets are allowed as microphones; with none connected the built-in one is used.
        try? a.setCategory(.playAndRecord, mode: .videoRecording, options: [.allowBluetoothA2DP, .allowBluetooth, .defaultToSpeaker])
        try? a.setActive(true)
        applyPreferredInput()
    }

    /// The reference's order: a USB headset or device, a wired headset, a Bluetooth headset microphone, else the built-in one.
    private func applyPreferredInput() {
        let a = AVAudioSession.sharedInstance()
        let inputs = a.availableInputs ?? []
        let headset = preferHeadsetMic
            ? [AVAudioSession.Port.usbAudio, .headsetMic, .bluetoothHFP].lazy.compactMap { t in inputs.first { $0.portType == t } }.first
            : nil
        if let pick = headset ?? inputs.first(where: { $0.portType == .builtInMic }) { try? a.setPreferredInput(pick) }
    }

    // MARK: Sample buffers

    public func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === videoOut {
            guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
            latestLock.lock(); latest = pb; latestLock.unlock()
            if textureId >= 0 { DispatchQueue.main.async { self.textures.textureFrameAvailable(self.textureId) } }
            write(sb, video: true)
        } else if output === audioOut {
            write(sb, video: false)
            sendSpeech(sb)
        }
    }

    private func sendSpeech(_ sb: CMSampleBuffer) {
        let sink = audioListening ? audioSink : nil
        guard sink != nil || speechActive,
              let desc = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return }
        var d = asbd.pointee
        guard let srcFmt = AVAudioFormat(streamDescription: &d),
              let dstFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else { return }
        if converter == nil || converterSource != srcFmt {
            converter = AVAudioConverter(from: srcFmt, to: dstFmt); converterSource = srcFmt
        }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: srcFmt, frameCapacity: frames) else { return }
        inBuf.frameLength = frames
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sb, at: 0, frameCount: Int32(frames), into: inBuf.mutableAudioBufferList) == noErr else { return }
        let outCap = AVAudioFrameCount(Double(frames) * 16000 / srcFmt.sampleRate) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: dstFmt, frameCapacity: outCap) else { return }
        var supplied = false
        var err: NSError?
        converter?.convert(to: out, error: &err) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true; status.pointee = .haveData; return inBuf
        }
        guard err == nil, out.frameLength > 0, let ch = out.floatChannelData?[0] else { return }
        if speechActive { speech?.feed(out) }
        if let sink = sink {
            let data = Data(bytes: ch, count: Int(out.frameLength) * 4)
            DispatchQueue.main.async { sink(FlutterStandardTypedData(bytes: data)) }
        }
    }

    // MARK: Writer

    private func beginWriter() throws {
        guard writer == nil, session != nil else { throw NSError(domain: "talkroll", code: 1, userInfo: [NSLocalizedDescriptionKey: "No preview"]) }
        lockedAngle = currentAngle()  // read before locking, or it just returns the stale locked value
        orientationLocked = true
        updateVideoRotation()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("talkroll_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)
        let w = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let portrait = !landscapeRecording
        let h = recordingHeight, wd = h * 16 / 9
        let v = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: useHEVC ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
            AVVideoWidthKey: portrait ? h : wd, AVVideoHeightKey: portrait ? wd : h,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000],
        ])
        v.expectsMediaDataInRealTime = true
        let a = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000,
        ])
        a.expectsMediaDataInRealTime = true
        w.add(v)
        // Narration mode adds the narration file afterwards, so there is no microphone track.
        let narration = narrationPath != nil
        if !narration { w.add(a) }
        writer = w; vInput = v; aInput = narration ? nil : a; outputURL = url
        narrationSegments = []; narrationOpen = false
        if narration { playNarrationSession() }
        writerStarted = false; startTime = .invalid; lastTime = .zero
        paused = false; resuming = false; pausedOffset = .zero; lastRawVideo = .zero
        w.startWriting()
        // After `writer` is set: updateAudioInput() keeps the microphone on while a take with a microphone track is
        // being written, and releases it for a Narration take.
        updateAudioInput()
    }

    /// Narration plays back only: the silent switch, headphones and the volume decide what the reader hears, and
    /// none of it reaches the file.
    private func playNarrationSession() {
        let a = AVAudioSession.sharedInstance()
        try? a.setCategory(.playback, mode: .default, options: [])
        try? a.setActive(true)
    }

    /// Where the narration file is now, and whether it is playing. Plays that carry on from the last tick extend
    /// the open stretch; a pause, a jump or a restart starts a new one.
    private func narrationTick(positionMs: Int, playing: Bool) {
        guard narrationPath != nil, writer != nil else { return }
        guard writerStarted, !paused, !resuming, playing else { narrationOpen = false; return }
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        let at = max(0, CMTimeGetSeconds(CMTimeSubtract(CMTimeSubtract(now, startTime), pausedOffset)))
        let position = Double(positionMs) / 1000
        if narrationOpen, let last = narrationSegments.last, abs(last.audioStart + (at - last.videoStart) - position) < 0.15 {
            narrationSegments[narrationSegments.count - 1].length = at - last.videoStart
        } else {
            narrationSegments.append(NarrationSegment(videoStart: at, audioStart: position, length: 0))
            narrationOpen = true
        }
    }

    private func write(_ sb: CMSampleBuffer, video: Bool) {
        guard let w = writer, w.status == .writing, !paused else { return }
        var pts = CMSampleBufferGetPresentationTimeStamp(sb)
        if !writerStarted {
            // Start the file on the first video frame so audio and video align.
            guard video else { return }
            w.startSession(atSourceTime: pts); startTime = pts; writerStarted = true
        }
        if resuming {
            // Resync on the first video frame after a pause; audio waits for it.
            guard video else { return }
            let gap = CMTimeSubtract(pts, lastRawVideo)
            pausedOffset = CMTimeAdd(pausedOffset, CMTimeSubtract(gap, CMTime(value: 1, timescale: 30)))
            resuming = false
        }
        let input = video ? vInput : aInput
        if input?.isReadyForMoreMediaData == true {
            var out = sb
            if pausedOffset != .zero {
                var timing = CMSampleTimingInfo(
                    duration: CMSampleBufferGetDuration(sb),
                    presentationTimeStamp: CMTimeSubtract(pts, pausedOffset),
                    decodeTimeStamp: .invalid)
                var copy: CMSampleBuffer?
                guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sb, sampleTimingEntryCount: 1,
                                                            sampleTimingArray: &timing, sampleBufferOut: &copy) == noErr,
                      let c = copy else { return }
                out = c
            }
            input?.append(out)
            if video { lastRawVideo = pts; pts = CMTimeSubtract(pts, pausedOffset); lastTime = pts }
        }
    }

    private func finishRecording(reason: String, result: @escaping FlutterResult) {
        queue.async {
            guard let w = self.writer, let url = self.outputURL else {
                DispatchQueue.main.async { result(FlutterError(code: "record", message: "Not recording", details: nil)) }; return
            }
            let duration = self.writerStarted ? CMTimeGetSeconds(CMTimeSubtract(self.lastTime, self.startTime)) : 0
            self.vInput?.markAsFinished(); self.aInput?.markAsFinished()
            let narration = self.narrationPath
            let segments = self.narrationSegments.filter { $0.length > 0.05 }
            self.narrationPath = nil; self.narrationSegments = []; self.narrationOpen = false
            self.writer = nil; self.vInput = nil; self.aInput = nil
            self.orientationLocked = false
            self.updateVideoRotation()
            self.updateAudioInput()
            w.finishWriting {
                Task {
                    // Narration mode: put the narration file into the video. If that fails the file is still the take as
                    // filmed, and `narrationFailed` tells the app so it can say the narration is missing.
                    var path = url.path
                    var narrationFailed = false
                    if let narration {
                        if segments.isEmpty {
                            narrationFailed = true  // the narration never played during the take
                        } else {
                            let output = FileManager.default.temporaryDirectory.appendingPathComponent("talkroll_\(Int(Date().timeIntervalSince1970))_n.mp4")
                            do {
                                try await NarrationMux.mux(video: url, narration: URL(fileURLWithPath: narration), segments: segments, to: output)
                                try? FileManager.default.removeItem(at: url)
                                path = output.path
                            } catch {
                                NSLog("TalkRoll: could not add the narration to the video: \(error)")
                                narrationFailed = true
                            }
                        }
                    }
                    if reason != "user" { DispatchQueue.main.async { self.eventSink?(["type": reason, "path": path, "durationMs": Int(duration * 1000), "narrationFailed": narrationFailed]) } }
                    DispatchQueue.main.async {
                        result(["path": path, "durationMs": Int(duration * 1000), "reason": reason, "narrationFailed": narrationFailed])
                    }
                }
            }
        }
    }

    @objc private func interrupted() {
        if writer != nil { finishRecording(reason: "interrupted", result: { _ in }) }
    }

    private func saveToGallery(_ path: String, result: @escaping FlutterResult) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { result(FlutterError(code: "permission", message: "Photos access denied", details: nil)) }; return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
            }) { ok, err in
                DispatchQueue.main.async { ok ? result(nil) : result(FlutterError(code: "save", message: err?.localizedDescription, details: nil)) }
            }
        }
    }
}
