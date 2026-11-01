import AVFoundation
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
        method.setMethodCallHandler { call, result in c.handle(call, result: result) }
        instances.append(c)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(true)
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
                self.start(path: path, language: language, run: run, result: result)
            }
        }
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
        var last: [SFTranscriptionSegment] = []
        task = recognizer.recognitionTask(with: request) { [weak self] r, error in
            DispatchQueue.main.async {
                guard let self, run == self.generation, self.pending != nil else { return }
                if let r {
                    last = r.bestTranscription.segments
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
