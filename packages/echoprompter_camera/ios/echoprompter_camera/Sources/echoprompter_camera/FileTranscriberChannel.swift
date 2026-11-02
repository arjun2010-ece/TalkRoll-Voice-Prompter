import AVFoundation
import CoreMedia
import Speech
#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif

/// Narration mode's transcriber: reads a recording with Apple's speech recogniser, on this device only, and returns
/// every word with its start and end in seconds. A device that cannot recognise the language without the network is
/// refused (`unavailable`) rather than sending the recording anywhere. Progress goes back to Dart as `progress`
/// calls. One recording at a time; starting another cancels the first. All of it runs on the main thread.
final class FileTranscriberChannel: NSObject {
    private let channel: FlutterMethodChannel
    private var task: SFSpeechRecognitionTask?
    private var pending: FlutterResult?
    private var generation = 0
    // Apple's newer engines (iOS 26, macOS 26): the running analysis and its analyzer, so a cancel can stop them.
    private var analysis: Task<Void, Never>?
    private var activeAnalyzer: Any?
    private static var instances: [FileTranscriberChannel] = []

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        #if os(macOS)
        let messenger = registrar.messenger
        #else
        let messenger = registrar.messenger()
        #endif
        let method = FlutterMethodChannel(name: "com.echoprompter/transcribe", binaryMessenger: messenger)
        let c = FileTranscriberChannel(channel: method)
        if #available(iOS 26, macOS 26, *) {
            LanguagePack.onProgress = { language, fraction in
                DispatchQueue.main.async { method.invokeMethod("packProgress", arguments: ["language": language, "fraction": fraction]) }
            }
        }
        method.setMethodCallHandler { call, result in c.handle(call, result: result) }
        instances.append(c)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(true)
        case "languagePack":
            let args = call.arguments as? [String: Any] ?? [:]
            let language = args["language"] as? String ?? "en-US"
            if #available(iOS 26, macOS 26, *) {
                languagePack(language: language, download: args["download"] as? Bool ?? false, result: result)
            } else {
                result("legacy") // the older recogniser has no packs of its own to manage
            }
        case "cancel":
            cancel()
            result(nil)
        case "transcribe":
            let args = call.arguments as? [String: Any] ?? [:]
            guard let path = args["path"] as? String else {
                return result(FlutterError(code: "failed", message: "No recording was given.", details: nil))
            }
            transcribe(path: path, language: args["language"] as? String ?? "en-US", result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Ends the running transcription, answering Dart's waiting call with `cancelled`.
    private func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        analysis?.cancel()
        analysis = nil
        if #available(iOS 26, macOS 26, *), let analyzer = activeAnalyzer as? SpeechAnalyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        activeAnalyzer = nil
        pending?(FlutterError(code: "cancelled", message: "Cancelled.", details: nil))
        pending = nil
    }

    private func transcribe(path: String, language: String, result: @escaping FlutterResult) {
        cancel()
        let run = generation
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self, run == self.generation else { return result(FlutterError(code: "cancelled", message: "Cancelled.", details: nil)) }
                guard status == .authorized else {
                    return result(FlutterError(code: "denied", message: "Speech recognition is turned off for EchoPrompter.", details: nil))
                }
                self.begin(path: path, language: language, run: run, result: result)
            }
        }
    }

    /// Starts the transcription with the best engine this system has: Apple's newer speech analyzer where it exists
    /// (it understands more languages well and times every word), and the older recogniser otherwise or when the
    /// newer one cannot do the job.
    private func begin(path: String, language: String, run: Int, result: @escaping FlutterResult) {
        if #available(iOS 26, macOS 26, *) {
            pending = result
            analysis = Task { [weak self] in
                guard let self else { return }
                var words: [[String: Any]] = []
                do { words = try await self.analyze(path: path, language: language, run: run) } catch {}
                await MainActor.run {
                    guard run == self.generation, self.pending != nil else { return } // cancelled or replaced meanwhile
                    self.analysis = nil
                    self.activeAnalyzer = nil
                    if words.isEmpty {
                        self.pending = nil
                        self.start(path: path, language: language, run: run, result: result)
                    } else {
                        self.finishWords(words)
                    }
                }
            }
        } else {
            start(path: path, language: language, run: run, result: result)
        }
    }

    @available(iOS 26, macOS 26, *)
    private func analyze(path: String, language: String, run: Int) async throws -> [[String: Any]] {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let duration = Double(file.length) / file.processingFormat.sampleRate
        // The system keeps at most five language packs reserved for an app, and a reservation outlives a run: let go of
        // any left behind before taking one.
        for stale in await AssetInventory.reservedLocales { await AssetInventory.release(reservedLocale: stale) }
        // The newer model first (about ten languages); the dictation model covers the rest (about thirty).
        switch await LanguagePack.resolve(language) {
        case .speech(let locale):
            let module = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [], attributeOptions: [.audioTimeRange])
            return try await drive(module, locale: locale, language: language, results: module.results, file: file, duration: duration, run: run) { ($0.text, $0.range) }
        case .dictation(let locale):
            let module = DictationTranscriber(locale: locale, preset: .timeIndexedLongDictation)
            return try await drive(module, locale: locale, language: language, results: module.results, file: file, duration: duration, run: run) { ($0.text, $0.range) }
        case nil:
            return []
        }
    }

    /// Installs the language pack if it is missing (the system downloads it once; the recording is never sent), reads
    /// the file through [module], and returns every word with its time. The locale is released afterwards.
    @available(iOS 26, macOS 26, *)
    private func drive<M: SpeechModule, S: AsyncSequence>(
        _ module: M, locale: Locale, language: String, results: S, file: AVAudioFile, duration: Double, run: Int,
        text: @escaping (S.Element) -> (AttributedString, CMTimeRange)
    ) async throws -> [[String: Any]] {
        // A request for a pack that is already there finishes at once, so always ask.
        try await LanguagePack.install(module, language: language, key: "\(module is SpeechTranscriber ? "s" : "d"):\(locale.identifier)")
        let analyzer = SpeechAnalyzer(modules: [module])
        await MainActor.run { if run == self.generation { self.activeAnalyzer = analyzer } }
        let cantonese = Locale(identifier: language.replacingOccurrences(of: "_", with: "-")).language.languageCode?.identifier == "yue"
        let collector = Task { () -> [[String: Any]] in
            var words: [[String: Any]] = []
            for try await r in results {
                let (attributed, range) = text(r)
                for piece in attributed.runs {
                    guard let time = piece[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] else { continue }
                    var word = String(attributed[piece.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    // The Cantonese model writes Simplified characters, and Cantonese scripts are in Traditional ones.
                    if cantonese { word = word.applyingTransform(StringTransform("Hans-Hant"), reverse: false) ?? word }
                    if !word.isEmpty { words.append(["w": word, "s": time.start.seconds, "e": time.end.seconds]) }
                }
                if duration > 0 {
                    let done = min(1.0, range.end.seconds / duration)
                    await MainActor.run { if run == self.generation { self.channel.invokeMethod("progress", arguments: done) } }
                }
            }
            return words
        }
        do {
            try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
            let words = try await collector.value
            await AssetInventory.release(reservedLocale: locale)
            return words
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            await AssetInventory.release(reservedLocale: locale)
            throw error
        }
    }

    /// Whether the language pack for [language] is on this device: "ready", "needsDownload", or "unsupported" (neither
    /// engine has the language). With [download] it installs a missing pack first, reporting `packProgress` to Dart,
    /// and fails with `download` when it cannot (no connection, for one).
    @available(iOS 26, macOS 26, *)
    private func languagePack(language: String, download: Bool, result: @escaping FlutterResult) {
        Task {
            var answer: Any = "unsupported"
            if let pack = await LanguagePack.resolve(language) {
                let module = pack.module
                if await LanguagePack.isInstalled(module) {
                    answer = "ready"
                } else if !download {
                    answer = "needsDownload"
                } else {
                    do {
                        try await LanguagePack.install(module, language: language, key: pack.key)
                        answer = "ready"
                    } catch {
                        answer = FlutterError(code: "download", message: "\(error.localizedDescription)", details: nil)
                    }
                }
            }
            await MainActor.run { result(answer) }
        }
    }

    private func finishWords(_ words: [[String: Any]]) {
        let done = pending
        pending = nil
        done?(words)
    }

    private func start(path: String, language: String, run: Int, result: @escaping FlutterResult) {
        let locale = Locale(identifier: language.replacingOccurrences(of: "_", with: "-"))
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            return result(FlutterError(code: "unavailable", message: "This device can't recognise \(language) speech.", details: nil))
        }
        // The recording never leaves the device: without an offline model for the language, stop here.
        guard recognizer.supportsOnDeviceRecognition else {
            #if os(macOS)
            let fix = "Add the language under System Settings > Keyboard > Dictation, then try again."
            #else
            let fix = "Download the language under Settings > General > Keyboard > Dictation, then try again."
            #endif
            return result(FlutterError(code: "unavailable", message: "Narration needs the \(language) offline speech model. \(fix)", details: nil))
        }
        let url = URL(fileURLWithPath: path)
        var duration = 0.0
        if let file = try? AVAudioFile(forReading: url) {
            duration = Double(file.length) / file.processingFormat.sampleRate
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        pending = result
        // A long recording is recognised in stretches of about a minute, and each stretch's result covers only its own
        // time, so the words of earlier stretches are kept: a result replaces whatever overlaps it in time. Partial
        // results carry no timing at all (every time is 0), so only results with real times are merged.
        var last: [SFTranscriptionSegment] = []
        task = recognizer.recognitionTask(with: request) { [weak self] r, error in
            DispatchQueue.main.async {
                guard let self, run == self.generation, self.pending != nil else { return }
                if let r {
                    let now = r.bestTranscription.segments
                    if let start = now.first?.timestamp, let tail = now.last, tail.timestamp + tail.duration > 0 {
                        last = last.filter { $0.timestamp + $0.duration <= start + 0.001 } + now
                    }
                    if duration > 0, let tail = last.last {
                        self.channel.invokeMethod("progress", arguments: min(1.0, (tail.timestamp + tail.duration) / duration))
                    }
                    if r.isFinal { return self.finish(last) }
                }
                if error != nil {
                    // A recording can end with an error after its words are all in (silence at the end, for one).
                    if !last.isEmpty { return self.finish(last) }
                    self.fail(code: "failed", message: "Couldn't transcribe this recording. Choose another one.")
                }
            }
        }
    }

    private func finish(_ segments: [SFTranscriptionSegment]) {
        let words = segments.map { ["w": $0.substring, "s": $0.timestamp, "e": $0.timestamp + $0.duration] as [String: Any] }
        let done = pending
        pending = nil
        task = nil
        done?(words)
    }

    private func fail(code: String, message: String) {
        let done = pending
        pending = nil
        task = nil
        done?(FlutterError(code: code, message: message, details: nil))
    }
}
