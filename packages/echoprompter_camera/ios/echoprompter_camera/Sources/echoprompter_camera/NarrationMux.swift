import AVFoundation

/// A stretch of the narration file that played while the video was being recorded: `length` seconds of the file,
/// starting at `audioStart`, heard `videoStart` seconds into the video.
struct NarrationSegment {
    var videoStart: Double
    var audioStart: Double
    var length: Double
}

/// Narration mode films without the microphone. This puts the narration file itself into the finished video,
/// wherever it was playing during the take (it can pause, jump back or restart), so the result does not depend on
/// the speaker, headphones, volume or the silent switch.
enum NarrationMux {
    private static let timescale: CMTimeScale = 48000

    /// Writes a copy of `video` that carries the narration. Throws if the file has no audio or an export fails.
    static func mux(video: URL, narration: URL, segments: [NarrationSegment], to output: URL) async throws {
        let videoAsset = AVURLAsset(url: video)
        let narrationAsset = AVURLAsset(url: narration)
        guard let sourceAudio = try await narrationAsset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "echoprompter", code: 10, userInfo: [NSLocalizedDescriptionKey: "The narration file has no audio"])
        }
        guard let sourceVideo = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "echoprompter", code: 11, userInfo: [NSLocalizedDescriptionKey: "The take has no video"])
        }
        let videoLength = try await videoAsset.load(.duration)
        let narrationLength = CMTimeGetSeconds(try await narrationAsset.load(.duration))

        // 1. The pieces that played, at their place on the video's timeline, as one AAC track. Time with no
        //    narration is silence.
        let pieces = AVMutableComposition()
        guard let pieceTrack = pieces.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "echoprompter", code: 12, userInfo: [NSLocalizedDescriptionKey: "No audio track"])
        }
        for s in segments {
            let length = min(s.length, narrationLength - s.audioStart, CMTimeGetSeconds(videoLength) - s.videoStart)
            guard length > 0.02, s.audioStart >= 0 else { continue }
            try pieceTrack.insertTimeRange(
                CMTimeRange(start: CMTime(seconds: s.audioStart, preferredTimescale: timescale), duration: CMTime(seconds: length, preferredTimescale: timescale)),
                of: sourceAudio,
                at: CMTime(seconds: s.videoStart, preferredTimescale: timescale))
        }
        let soundtrack = FileManager.default.temporaryDirectory.appendingPathComponent("echoprompter_narration_\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: soundtrack) }
        try await export(pieces, preset: AVAssetExportPresetAppleM4A, type: .m4a, to: soundtrack, range: nil)

        // 2. The video as filmed plus that soundtrack, copied without re-encoding the picture.
        let finished = AVMutableComposition()
        guard let outVideo = finished.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let outAudio = finished.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "echoprompter", code: 12, userInfo: [NSLocalizedDescriptionKey: "No tracks"])
        }
        let full = CMTimeRange(start: .zero, duration: videoLength)
        try outVideo.insertTimeRange(full, of: sourceVideo, at: .zero)
        outVideo.preferredTransform = try await sourceVideo.load(.preferredTransform)
        let soundAsset = AVURLAsset(url: soundtrack)
        if let sound = try await soundAsset.loadTracks(withMediaType: .audio).first {
            let soundLength = try await soundAsset.load(.duration)
            let keep = CMTimeMinimum(soundLength, videoLength)
            try outAudio.insertTimeRange(CMTimeRange(start: .zero, duration: keep), of: sound, at: .zero)
        }
        try await export(finished, preset: AVAssetExportPresetPassthrough, type: .mp4, to: output, range: full)
    }

    private static func export(_ asset: AVAsset, preset: String, type: AVFileType, to url: URL, range: CMTimeRange?) async throws {
        try? FileManager.default.removeItem(at: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw NSError(domain: "echoprompter", code: 13, userInfo: [NSLocalizedDescriptionKey: "Cannot export"])
        }
        session.outputURL = url
        session.outputFileType = type
        if let range { session.timeRange = range }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { done.resume() }
        }
        guard session.status == .completed else {
            throw session.error ?? NSError(domain: "echoprompter", code: 14, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
        }
    }
}
