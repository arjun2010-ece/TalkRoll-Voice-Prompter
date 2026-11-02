import AVFoundation
import CoreMedia
import Foundation
import Speech

/// Voice mode's live recogniser on Apple's newer engines (iOS 26, macOS 26): the same models as Narration. Audio goes in
/// as 16 kHz mono float buffers; every result goes out as a hypothesis (text and whether it is final), the way the
/// older recogniser's results do, so the script tracker is unchanged. A running result covers the stretch not yet
/// finalised, and a final one ends that stretch, which is what the tracker expects of an utterance. There are no
/// one-minute sessions to restart.
///
/// It listens to every language the older recogniser (`SFSpeechRecognizer`) has no model for on this device. Without
/// one, the older recogniser reaches Apple's servers (latency, a connection, and the speech sent away); the newer
/// engines run every language they list on the device. The older recogniser's Portuguese model is on the device but
/// returned 22% of a test passage, so Portuguese always comes here. Where the older recogniser has an on-device model it
/// stays: it streams steadily, and the newer engines update in bursts about once a second.
@available(iOS 26, macOS 26, *)
final class LiveAnalyzer {
    private let pack: LanguagePack
    private let language: String
    private var analyzer: SpeechAnalyzer?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var format: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var resultsTask: Task<Void, Never>?

    var onHypothesis: ((String, Bool) -> Void)?
    var onFailure: ((Error) -> Void)?

    private init(pack: LanguagePack, language: String) {
        self.pack = pack
        self.language = language
    }

    /// Language codes the older recogniser is known to get wrong even though it runs on the device.
    private static let olderIsWrong: Set<String> = ["pt"]

    /// Whether Voice mode listens to [language] with the newer engines.
    static func handles(_ language: String) -> Bool {
        let locale = Locale(identifier: language.replacingOccurrences(of: "_", with: "-"))
        if olderIsWrong.contains(locale.language.languageCode?.identifier ?? "") { return true }
        return SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition != true
    }

    static func make(language: String) async -> LiveAnalyzer? {
        guard handles(language), let pack = await LanguagePack.resolve(language) else { return nil }
        return LiveAnalyzer(pack: pack, language: language)
    }

    /// Installs the language pack if needed, then starts listening. Throws when it cannot.
    func start() async throws {
        // A pack is never downloaded here: Dart downloads a missing one first, after the reader has agreed.
        guard await LanguagePack.isInstalled(pack.module) else {
            throw NSError(domain: "EchoPrompter", code: 2, userInfo: [NSLocalizedDescriptionKey: "The language pack is not on this device."])
        }
        await LanguagePack.reserve(pack)
        switch pack {
        case .speech(let locale):
            let module = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
            try await run(module, results: module.results) { (String($0.text.characters), $0.isFinal) }
        case .dictation(let locale):
            let module = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
            try await run(module, results: module.results) { (String($0.text.characters), $0.isFinal) }
        }
    }

    private func run<M: SpeechModule, S: AsyncSequence>(_ module: M, results: S, text: @escaping (S.Element) -> (String, Bool)) async throws {
        guard let target = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
            throw NSError(domain: "EchoPrompter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio format for the speech analyzer."])
        }
        let analyzer = SpeechAnalyzer(modules: [module])
        let (stream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.analyzer = analyzer
        self.format = target
        self.continuation = continuation
        resultsTask = Task { [weak self] in
            do {
                for try await r in results {
                    let (t, final) = text(r)
                    self?.onHypothesis?(t, final)
                }
            } catch {
                if !Task.isCancelled { self?.onFailure?(error) }
            }
        }
        try await analyzer.start(inputSequence: stream)
    }

    /// 16 kHz mono float, as the microphone capture delivers it.
    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let continuation, let target = format else { return }
        if converter == nil || converter?.inputFormat != buffer.format { converter = AVAudioConverter(from: buffer.format, to: target) }
        guard let converter else { return }
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, out.frameLength > 0 { continuation.yield(AnalyzerInput(buffer: out)) }
    }

    func stop() async {
        continuation?.finish()
        continuation = nil
        resultsTask?.cancel()
        resultsTask = nil
        await analyzer?.cancelAndFinishNow()
        analyzer = nil
    }
}
