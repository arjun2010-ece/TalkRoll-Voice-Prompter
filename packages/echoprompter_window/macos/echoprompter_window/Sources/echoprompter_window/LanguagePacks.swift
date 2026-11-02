import AVFoundation
import Foundation
import Speech

/// Which of Apple's newer on-device speech engines (iOS 26, macOS 26) handles a language, and the language pack it
/// needs. The newer model (`SpeechTranscriber`) covers about ten languages; the dictation model
/// (`DictationTranscriber`) covers about thirty more. Narration and Voice mode both use this, so one language means
/// the same engine and the same one-time download everywhere.
@available(iOS 26, macOS 26, *)
enum LanguagePack {
    case speech(Locale)
    case dictation(Locale)

    var locale: Locale {
        switch self {
        case .speech(let l), .dictation(let l): return l
        }
    }

    /// A module of this kind and language, used to ask whether the pack is installed and to install it.
    var module: any SpeechModule {
        switch self {
        case .speech(let l): return SpeechTranscriber(locale: l, transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        case .dictation(let l): return DictationTranscriber(locale: l, contentHints: [], transcriptionOptions: [], reportingOptions: [], attributeOptions: [])
        }
    }

    /// The pack for [language] (`pt-BR`, `de-DE`, ...), or nil when neither engine has it.
    ///
    /// The lists are matched here instead of with `supportedLocale(equivalentTo:)`: asking that about a language the
    /// newer model lacks makes the system report the dictation pack for that language as unsupported.
    static func resolve(_ language: String) async -> LanguagePack? {
        let requested = Locale(identifier: language.replacingOccurrences(of: "_", with: "-"))
        if let l = match(requested, in: await SpeechTranscriber.supportedLocales) { return .speech(l) }
        if let l = match(requested, in: await DictationTranscriber.supportedLocales) { return .dictation(l) }
        return nil
    }

    private static func match(_ requested: Locale, in list: [Locale]) -> Locale? {
        if let exact = list.first(where: { $0.identifier(.bcp47) == requested.identifier(.bcp47) }) { return exact }
        let code = requested.language.languageCode
        if let sameRegion = list.first(where: { $0.language.languageCode == code && $0.region == requested.region }) { return sameRegion }
        // Simplified and Traditional Chinese are not interchangeable; any other language falls back to its first region.
        return code == "zh" ? nil : list.first(where: { $0.language.languageCode == code })
    }

    var key: String { "\(self.isSpeech ? "s" : "d"):\(locale.identifier)" }
    private var isSpeech: Bool { if case .speech = self { return true } else { return false } }

    /// Called with (language tag, 0...1) while a pack downloads; set by the channel that talks to Dart.
    nonisolated(unsafe) static var onProgress: ((String, Double) -> Void)?

    static func isInstalled(_ module: any SpeechModule) async -> Bool {
        await AssetInventory.status(forModules: [module]) == .installed
    }

    /// Installs the pack for [module] if it is missing (the system downloads it once, and the recording or speech is
    /// never sent). One download per pack at a time: a second caller waits for the first.
    static func install(_ module: any SpeechModule, language: String, key: String) async throws {
        try await PackInstaller.shared.ensure(key: key) {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else { return }
            let observation = request.progress.observe(\.fractionCompleted, options: [.new]) { p, _ in
                onProgress?(language, p.fractionCompleted)
            }
            defer { observation.invalidate() }
            try await request.downloadAndInstall()
        }
    }
}

@available(iOS 26, macOS 26, *)
actor PackInstaller {
    static let shared = PackInstaller()
    private var running: [String: Task<Void, Error>] = [:]

    func ensure(key: String, _ work: @escaping @Sendable () async throws -> Void) async throws {
        if let task = running[key] { return try await task.value }
        let task = Task { try await work() }
        running[key] = task
        defer { running[key] = nil }
        try await task.value
    }
}
