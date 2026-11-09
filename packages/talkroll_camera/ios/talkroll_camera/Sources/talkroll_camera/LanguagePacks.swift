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

    /// Keeps [pack] reserved for this app, which is what keeps it on the device: the system removes a pack as soon as
    /// its reservation is released (measured: a Finnish pack released after use had to be downloaded again, 10 s). It
    /// allows five reservations at a time (`AssetInventory.maximumReservedLocales`), and they outlive the app. When a
    /// sixth language needs room, the one used least recently is released, and that language asks before it downloads
    /// again. That is the only time a pack is let go.
    static func reserve(_ pack: LanguagePack) async {
        let defaults = UserDefaults.standard
        func usedKey(_ l: Locale) -> String { "TalkRoll.packUsed.\(l.identifier)" }
        let reserved = await AssetInventory.reservedLocales
        if !reserved.contains(where: { $0.identifier == pack.locale.identifier }), reserved.count >= AssetInventory.maximumReservedLocales,
           let oldest = reserved.min(by: { defaults.double(forKey: usedKey($0)) < defaults.double(forKey: usedKey($1)) }) {
            await AssetInventory.release(reservedLocale: oldest)
        }
        _ = try? await AssetInventory.reserve(locale: pack.locale)
        defaults.set(Date().timeIntervalSince1970, forKey: usedKey(pack.locale))
    }

    /// Downloads the pack for [module] (from Apple, once; the recording or speech is never sent). This is the only place
    /// a pack is downloaded, and Dart calls it only after the reader has agreed. One download per pack at a time: a
    /// second caller waits for the first.
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
