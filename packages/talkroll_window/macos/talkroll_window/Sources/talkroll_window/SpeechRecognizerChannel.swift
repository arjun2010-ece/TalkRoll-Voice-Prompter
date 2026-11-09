import AVFoundation
import CoreAudio
import FlutterMacOS
import NaturalLanguage
import Speech

/// Voice and Audio mode's recogniser on macOS: Apple's `SFSpeechRecognizer`, on-device where the Mac
/// supports the chosen language (otherwise Apple's servers), streaming partial hypotheses to Dart while the event
/// stream is listened to. It is the counterpart of the iOS and Android recognisers, so Dart treats all of
/// them the same: every hypothesis goes to the script tracker, and an empty final marks the start of a
/// session and each segment's end.
///
/// It captures the microphone itself (an `AVCaptureSession`, like iOS). Voice mode listens through a connected USB or Bluetooth headset
/// microphone and otherwise the system's input; Audio mode must hear the speaker, so it uses the built-in
/// microphone. Audio that arrives while a session restarts is kept for about half a second and handed to
/// the next one. Everything but the capture callback runs on the main thread.
final class SpeechRecognizerChannel: NSObject, FlutterStreamHandler, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var recognizer: SFSpeechRecognizer? // for the language of the current listen; set in `onListen`
    private var sink: FlutterEventSink?

    private var bias: [String] = []
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = 0 // bumped whenever a session ends; callbacks of older ones are ignored
    private var running = false
    private var live: Any? // the newer engine's LiveAnalyzer while it is the one listening (iOS 26, macOS 26)
    private var listenToken = 0 // bumped when a listen ends, so a newer engine still starting knows to give up
    private var failures = 0 // consecutive service failures; five give up
    private var onDeviceFailed = false // on-device recognition failed for this language; use Apple's servers instead
    private var dictationErrors = 0 // consecutive Dictation-off errors (201); the second gives up
    private var lastError = ""
    private var restartTimes: [TimeInterval] = []
    private var idleTimer: Timer?
    private var lengthTimer: Timer?
    private var restartTimer: Timer?

    // Audio that arrives while no session is open, kept for the next one.
    private var pending: [AVAudioPCMBuffer] = []
    private var pendingFrames: AVAudioFrameCount = 0

    // Microphone capture.
    private var session: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "talkroll.speech.capture")
    private var converter: AVAudioConverter? // used on the capture queue only
    private var converterSource: AVAudioFormat?
    private var headsetMic = true
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Timer?
    private var buffersSeen = 0 // buffers delivered by the current capture
    private var captureAttempts = 0 // reopenings in a row without audio; reset once audio flows

    private static let segmentSilence: TimeInterval = 1.5 // no new words for this long ends a segment
    private static let maxSession: TimeInterval = 50 // Apple stops a task after about a minute
    private static let keepFrames: AVAudioFrameCount = 8000 // 0.5 s at 16 kHz
    private static let maxBias = 100
    private static let dictationMessage = "Turn on Dictation in System Settings > Keyboard to use Voice mode."

    static func register(with registrar: FlutterPluginRegistrar) {
        let c = SpeechRecognizerChannel()
        let method = FlutterMethodChannel(name: "com.talkroll/speech", binaryMessenger: registrar.messenger)
        method.setMethodCallHandler { call, result in c.handle(call, result: result) }
        FlutterEventChannel(name: "com.talkroll/speech/events", binaryMessenger: registrar.messenger)
            .setStreamHandler(c)
    }

    // MARK: Offline model

    private static var modelRequests = Set<String>() // languages already asked for; main thread only

    /// Asks the system to download the offline model for [locale] (reference `ud.x` -> `triggerModelDownload`). Only
    /// macOS 26 and later have a call for it; earlier versions keep using Apple's servers until the reader turns the
    /// language on under Dictation in Settings. A language already requested is not asked for again.
    private static func requestModel(for locale: Locale) {
        guard #available(macOS 26, *), modelRequests.insert(locale.identifier).inserted else { return }
        Task.detached {
            let module = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
            guard await AssetInventory.status(forModules: [module]) != .installed,
                  let request = try? await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
            try? await request.downloadAndInstall()
        }
    }

    // MARK: Channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable": available(result)
        case "supportedLanguages":
            result(SFSpeechRecognizer.supportedLocales().map { $0.identifier.replacingOccurrences(of: "_", with: "-") }.sorted())
        case "readiness": result(Self.readiness())
        case "detectLanguage":
            let recognizer = NLLanguageRecognizer()
            recognizer.processString((call.arguments as? String) ?? "")
            result(recognizer.dominantLanguage?.rawValue)
        case "setBias":
            bias = Array(((call.arguments as? [String]) ?? []).prefix(Self.maxBias))
            result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }

    /// What the reader still has to allow or turn on, without asking for anything: the speech and microphone
    /// permissions ("authorized", "denied", "restricted", "notDetermined") and whether Dictation, which
    /// Apple's recogniser needs, is "on", "off" or "unknown" (its setting may not be readable from the sandbox).
    private static func readiness() -> [String: String] {
        func name(_ speech: SFSpeechRecognizerAuthorizationStatus) -> String {
            switch speech {
            case .authorized: return "authorized"
            case .denied: return "denied"
            case .restricted: return "restricted"
            default: return "notDetermined"
            }
        }
        let mic: String
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: mic = "authorized"
        case .denied: mic = "denied"
        case .restricted: mic = "restricted"
        default: mic = "notDetermined"
        }
        var dictation = "unknown"
        if let v = CFPreferencesCopyAppValue("Dictation Enabled" as CFString, "com.apple.assistant.support" as CFString) as? NSNumber {
            dictation = v.boolValue ? "on" : "off"
        }
        return ["speech": name(SFSpeechRecognizer.authorizationStatus()), "mic": mic, "dictation": dictation]
    }

    /// True once the reader has allowed speech recognition; asks the first time. Whether the chosen language works is
    /// found out when listening starts.
    private func available(_ result: @escaping FlutterResult) {
        guard Self.hasUsageDescriptions else { return result(false) }
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined && Self.launchedFromTerminal {
            NSLog("TalkRoll: speech permission can't be asked for when the app is started by a terminal or IDE (flutter run): "
                + "macOS checks that program's Info.plist instead of ours and ends the app. Start it with `open TalkRoll.app` once to grant it.")
            return result(false)
        }
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { result(status == .authorized) }
        }
    }

    /// Started by a program other than launchd (`flutter run`, a debugger): macOS then holds that program
    /// responsible for the app's privacy requests and checks its Info.plist, not ours.
    private static var launchedFromTerminal: Bool { getppid() != 1 }

    /// macOS ends the app, instead of failing the request, when a privacy prompt has no usage text in the bundle.
    private static var hasUsageDescriptions: Bool {
        ["NSSpeechRecognitionUsageDescription", "NSMicrophoneUsageDescription"]
            .allSatisfy { Bundle.main.object(forInfoDictionaryKey: $0) != nil }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        guard Self.hasUsageDescriptions else {
            fail("unavailable", "This build is missing its speech recognition permission text. Rebuild the app.")
            return nil
        }
        headsetMic = (arguments as? [String: Any])?["headset"] as? Bool ?? true
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            fail("unavailable", "Speech recognition is unavailable on this Mac")
            return nil
        }
        let tag = (arguments as? [String: Any])?["language"] as? String ?? "en-US"
        if #available(iOS 26, macOS 26, *) {
            listenWithAnalyzer(tag: tag)
        } else {
            listenLegacy(tag: tag)
        }
        return nil
    }

    /// Listens with the older recogniser (`SFSpeechRecognizer`).
    private func listenLegacy(tag: String) {
        let name = Locale(identifier: "en").localizedString(forIdentifier: tag) ?? tag
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: tag)) else {
            fail("language", "This Mac can't recognise \(name). Add it in System Settings > Keyboard > Dictation > Languages, stay online, and wait for the download to finish.")
            return
        }
        guard recognizer.isAvailable else {
            fail("language", "Speech recognition can't recognise \(name) right now. Add it in System Settings > Keyboard > Dictation > Languages, stay online, and wait for the download to finish.")
            return
        }
        self.recognizer = recognizer
        // No offline model for this language yet: use the servers now and ask the system to fetch the model for later.
        if !recognizer.supportsOnDeviceRecognition { Self.requestModel(for: recognizer.locale) }
        running = true
        failures = 0
        dictationErrors = 0
        onDeviceFailed = false
        restartTimes = []
        captureAttempts = 0
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard self.running else { return }
                guard granted, self.startCapture() else {
                    self.stop()
                    self.fail("unavailable", "Microphone access is needed for Voice control")
                    return
                }
                self.startSession()
            }
        }
    }

    /// Voice on Apple's newer engines where they know the language (every language but English, which stays on the
    /// older recogniser): the same models and packs as Narration, no one-minute sessions to restart, and no dependence
    /// on which Dictation languages the system happens to have. The older recogniser is the fallback when the newer
    /// engine does not know the language or cannot start.
    @available(iOS 26, macOS 26, *)
    private func listenWithAnalyzer(tag: String) {
        listenToken += 1
        let token = listenToken
        Task { [weak self] in
            let engine = await LiveAnalyzer.make(language: tag)
            var started = false
            if let engine {
                engine.onHypothesis = { text, final in
                    DispatchQueue.main.async { if let self, token == self.listenToken { self.emit(text, final: final) } }
                }
                engine.onFailure = { _ in
                    DispatchQueue.main.async { if let self, token == self.listenToken { self.analyzerFailed(tag: tag) } }
                }
                do { try await engine.start(); started = true } catch {}
            }
            await MainActor.run {
                guard let self, token == self.listenToken, self.sink != nil else {
                    if started, let engine { Task { await engine.stop() } }
                    return
                }
                if started, let engine {
                    self.live = engine
                    self.beginAnalyzerCapture()
                } else {
                    self.listenLegacy(tag: tag)
                }
            }
        }
    }

    /// The newer engine stopped working while listening: carry on with the older recogniser.
    @available(iOS 26, macOS 26, *)
    private func analyzerFailed(tag: String) {
        stop()
        listenLegacy(tag: tag)
    }

    /// Starts the microphone for the newer engine.
    private func beginAnalyzerCapture() {
        running = true
        captureAttempts = 0
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                guard self.running else { return }
                guard granted, self.startCapture() else {
                    self.stop()
                    self.fail("unavailable", "Microphone access is needed for Voice control")
                    return
                }
                self.emit("", final: true) // an empty final at the start, so the tracker re-anchors
            }
        }
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stop()
        sink = nil
        return nil
    }

    // MARK: Microphone

    /// Opens the microphone; false if it can't be opened.
    ///
    /// It is an `AVCaptureSession` on one chosen device, as on iOS, not an `AVAudioEngine`: the engine ties
    /// the input to the system's output device and kept reconfiguring itself, or stayed silent, whenever a USB
    /// headset was the input. A watchdog opens the microphone again if no audio shows up.
    private func startCapture() -> Bool {
        stopCapture()
        buffersSeen = 0
        guard let device = Self.captureDevice(headset: headsetMic),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        let s = AVCaptureSession()
        let out = AVCaptureAudioDataOutput()
        out.setSampleBufferDelegate(self, queue: captureQueue)
        guard s.canAddInput(input), s.canAddOutput(out) else { return false }
        s.addInput(input)
        s.addOutput(out)
        session = s
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: .AVCaptureSessionRuntimeError, object: s, queue: .main) { [weak self] _ in
                self?.recoverCapture()
            },
            // The device was unplugged.
            center.addObserver(forName: .AVCaptureDeviceWasDisconnected, object: device, queue: .main) { [weak self] _ in
                self?.recoverCapture()
            },
        ]
        captureQueue.async { s.startRunning() }
        watchdog = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self, self.running, self.session === s else { return }
            if self.buffersSeen == 0 { self.recoverCapture() }
        }
        return true
    }

    /// Opens the microphone again after it stopped or stayed silent; gives up after a few tries in a row.
    private func recoverCapture() {
        guard running else { return }
        captureAttempts += 1
        if captureAttempts > 5 {
            stop()
            fail("unavailable", "The microphone isn't delivering audio. Check the input in System Settings > Sound.")
            return
        }
        stopCapture()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, self.running else { return }
            if !self.startCapture() { self.recoverCapture() }
        }
    }

    private func stopCapture() {
        watchdog?.invalidate(); watchdog = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        if let s = session { captureQueue.async { s.stopRunning() } }
        session = nil
    }

    /// Voice mode: a connected USB device, else a Bluetooth one, else the system input, as the Android and iOS capture
    /// does. Audio mode: the built-in microphone, which can hear the speaker.
    private static func captureDevice(headset: Bool) -> AVCaptureDevice? {
        let devices = inputDevices()
        let wanted: AudioDeviceID?
        if headset {
            let order: [UInt32] = [kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE]
            wanted = order.lazy.compactMap { t in devices.first { $0.transport == t }?.id }.first
        } else {
            wanted = devices.first { $0.transport == kAudioDeviceTransportTypeBuiltIn }?.id
        }
        if let id = wanted, let uid = deviceUID(id), let d = AVCaptureDevice(uniqueID: uid) { return d }
        return AVCaptureDevice.default(for: .audio)
    }

    private static func deviceUID(_ id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid) == noErr, let u = uid else { return nil }
        return u.takeRetainedValue() as String
    }

    private static func inputDevices() -> [(id: AudioDeviceID, transport: UInt32)] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard inputChannels(id) > 0 else { return nil }
            var transport: UInt32 = 0
            var tSize = UInt32(MemoryLayout<UInt32>.size)
            var tAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(id, &tAddress, 0, nil, &tSize, &transport) == noErr else { return nil }
            return (id, transport)
        }
    }

    private static func inputChannels(_ id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    /// Microphone audio as 16 kHz mono float (on the capture queue).
    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let desc = CMSampleBufferGetFormatDescription(sb),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return }
        var d = asbd.pointee
        guard let srcFmt = AVAudioFormat(streamDescription: &d),
              let dstFmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false) else { return }
        if converter == nil || converterSource != srcFmt {
            converter = AVAudioConverter(from: srcFmt, to: dstFmt)
            converterSource = srcFmt
        }
        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sb))
        guard frames > 0, let inBuf = AVAudioPCMBuffer(pcmFormat: srcFmt, frameCapacity: frames) else { return }
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
        if err == nil, out.frameLength > 0 { feed(out) }
    }

    // MARK: Sessions

    private func startSession() {
        guard running, let recognizer = recognizer else { return }
        endSession()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        if #available(macOS 13, *) { req.addsPunctuation = false }
        if recognizer.supportsOnDeviceRecognition && !onDeviceFailed { req.requiresOnDeviceRecognition = true }
        if !bias.isEmpty { req.contextualStrings = bias }
        request = req
        let id = generation
        // An empty final at the start of a session, so the tracker re-anchors.
        emit("", final: true)
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            DispatchQueue.main.async { self?.onResult(id, result, error) }
        }
        for b in pending { req.append(b) }
        pending = []
        pendingFrames = 0
        lengthTimer = Timer.scheduledTimer(withTimeInterval: Self.maxSession, repeats: false) { [weak self] _ in
            self?.finishSegment(id)
        }
    }

    /// Stops the current session without reporting anything more from it.
    private func endSession() {
        generation += 1
        idleTimer?.invalidate(); idleTimer = nil
        lengthTimer?.invalidate(); lengthTimer = nil
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
    }

    /// Asks the recogniser to finish what it has heard; its final result then restarts the session.
    private func finishSegment(_ id: Int) {
        guard id == generation else { return }
        idleTimer?.invalidate(); idleTimer = nil
        // Audio from here on waits for the next session.
        request?.endAudio(); request = nil
    }

    private func onResult(_ id: Int, _ result: SFSpeechRecognitionResult?, _ error: Error?) {
        guard id == generation, running else { return }
        if let result = result {
            failures = 0
            dictationErrors = 0
            let text = result.bestTranscription.formattedString
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                emit(text, final: result.isFinal)
                idleTimer?.invalidate()
                if !result.isFinal {
                    idleTimer = Timer.scheduledTimer(withTimeInterval: Self.segmentSilence, repeats: false) { [weak self] _ in
                        self?.finishSegment(id)
                    }
                }
            }
            if result.isFinal { scheduleRestart(after: 0.1) }
            return
        }
        guard let error = error as NSError? else { return }
        // "No speech detected" (1110), "retry" (203) and a cancelled request (301) just mean a quiet stretch.
        let quiet = (error.domain == "kAFAssistantErrorDomain" && (error.code == 1110 || error.code == 203))
            || (error.domain == "kLSRErrorDomain" && error.code == 301)
        // Apple's recogniser refuses to work while Dictation is turned off; retrying can't help.
        let dictationOff = error.localizedDescription.localizedCaseInsensitiveContains("dictation")
            || (error.domain == "kAFAssistantErrorDomain" && error.code == 1101)
        // Error 1700: the system rejected the request although the permissions are allowed; the reference stops at once.
        if error.domain == "kAFAssistantErrorDomain" && error.code == 1700 {
            fail("unavailable", "Microphone and Speech Recognition access are allowed, but macOS rejected the recognition request. Quit and reopen TalkRoll, then try again. If this continues, check TalkRoll's Speech Recognition access in System Settings > Privacy & Security.")
            stop()
            return
        }
        // Error 201 (Dictation or Siri off): the reference retries once and stops on the second in a row.
        if error.domain == "kLSRErrorDomain" && error.code == 201 {
            dictationErrors += 1
            if dictationErrors >= 2 {
                fail("unavailable", Self.dictationMessage)
                stop()
                return
            }
        }
        if dictationOff {
            fail("unavailable", Self.dictationMessage)
            stop()
            return
        }
        if !quiet {
            // The offline model can be missing or broken even when it is reported as supported: try the servers.
            if let r = recognizer, r.supportsOnDeviceRecognition { onDeviceFailed = true; Self.requestModel(for: r.locale) }
            failures += 1
            lastError = "\(error.domain) \(error.code)"
            if failures >= 5 {
                fail("unavailable", "Speech recognition failed repeatedly, so listening has stopped. Check your microphone, then go to System Settings > Keyboard > Dictation > Languages, add the language chosen in TalkRoll and wait for any download to finish before trying again. (\(lastError))")
                stop()
                return
            }
        }
        scheduleRestart(after: quiet ? 0.15 : 0.4)
    }

    /// Restarts after [delay]; six restarts within 1.5 s back off for 2 s.
    private func scheduleRestart(after delay: TimeInterval) {
        endSession()
        let now = Date().timeIntervalSince1970
        restartTimes = restartTimes.filter { now - $0 < 1.5 } + [now]
        let wait = restartTimes.count >= 6 ? 2.0 : delay
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
            self?.startSession()
        }
    }

    private func stop() {
        running = false
        listenToken += 1
        if #available(iOS 26, macOS 26, *), let engine = live as? LiveAnalyzer { Task { await engine.stop() } }
        live = nil
        restartTimer?.invalidate(); restartTimer = nil
        endSession()
        stopCapture()
        pending = []
        pendingFrames = 0
    }

    // MARK: Audio and events

    /// 16 kHz mono float from the microphone capture (called on the audio thread).
    private func feed(_ buffer: AVAudioPCMBuffer) {
        DispatchQueue.main.async {
            guard self.running else { return }
            self.buffersSeen += 1
            self.captureAttempts = 0
            if #available(iOS 26, macOS 26, *), let engine = self.live as? LiveAnalyzer {
                engine.feed(buffer)
                return
            }
            if let req = self.request {
                req.append(buffer)
                return
            }
            self.pending.append(buffer)
            self.pendingFrames += buffer.frameLength
            while self.pendingFrames > Self.keepFrames, let first = self.pending.first {
                self.pendingFrames -= first.frameLength
                self.pending.removeFirst()
            }
        }
    }

    private func emit(_ text: String, final: Bool) {
        sink?(["text": text, "final": final])
    }

    private func fail(_ code: String, _ message: String) {
        sink?(FlutterError(code: code, message: message, details: nil))
    }
}
