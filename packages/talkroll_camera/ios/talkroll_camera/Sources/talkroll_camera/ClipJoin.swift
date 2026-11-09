import AVFoundation

/// Joins the keeper clips of a section-by-section run, in the order given, into one MP4 with `AVMutableComposition`
/// and `AVAssetExportSession`. Clips that share one orientation and size are copied without re-encoding; a clip filmed
/// in another orientation is fitted into the first clip's frame (and the picture is re-encoded).
enum ClipJoin {
    private struct Piece {
        var range: CMTimeRange        // where the clip sits on the joined timeline
        var transform: CGAffineTransform
        var size: CGSize              // upright size
        var natural: CGSize           // size as stored in the file
    }

    static func join(_ urls: [URL], to output: URL) async throws {
        guard !urls.isEmpty else { throw error(20, "Nothing to join") }
        let composition = AVMutableComposition()
        guard let outVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let outAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw error(21, "No tracks")
        }
        var cursor = CMTime.zero
        var pieces: [Piece] = []
        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let video = try await asset.loadTracks(withMediaType: .video).first else { throw error(22, "A clip has no video") }
            // The picture sets the clip's length; its sound is cut to it so the next clip's sound stays in step.
            let length = try await video.load(.timeRange).duration
            let range = CMTimeRange(start: .zero, duration: length)
            try outVideo.insertTimeRange(range, of: video, at: cursor)
            if let sound = try await asset.loadTracks(withMediaType: .audio).first {
                let soundRange = try await sound.load(.timeRange)
                let keep = CMTimeRange(start: .zero, duration: CMTimeMinimum(soundRange.duration, length))
                try outAudio.insertTimeRange(keep, of: sound, at: cursor)
            }
            let transform = try await video.load(.preferredTransform)
            let natural = try await video.load(.naturalSize)
            let upright = CGRect(origin: .zero, size: natural).applying(transform)
            pieces.append(Piece(range: CMTimeRange(start: cursor, duration: length), transform: transform,
                                size: CGSize(width: abs(upright.width), height: abs(upright.height)), natural: natural))
            cursor = CMTimeAdd(cursor, length)
        }

        let same = pieces.allSatisfy { $0.size == pieces[0].size && $0.transform == pieces[0].transform }
        try? FileManager.default.removeItem(at: output)
        let session: AVAssetExportSession?
        if same {
            outVideo.preferredTransform = pieces[0].transform
            session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        } else {
            session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
            session?.videoComposition = fitted(outVideo, pieces)
        }
        guard let session else { throw error(23, "Cannot export") }
        session.outputURL = output
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { done.resume() }
        }
        guard session.status == .completed else { throw session.error ?? error(24, "Export failed") }
    }

    /// Each clip upright, scaled to fit the first clip's frame and centred in it.
    private static func fitted(_ track: AVMutableCompositionTrack, _ pieces: [Piece]) -> AVMutableVideoComposition {
        let frame = pieces[0].size
        let instructions: [AVMutableVideoCompositionInstruction] = pieces.map { piece in
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            // The clip's own rotation, moved back to the origin, then fitted into the frame.
            let size = piece.size
            let rotated = CGRect(origin: .zero, size: piece.natural).applying(piece.transform)
            let toOrigin = piece.transform.concatenating(CGAffineTransform(translationX: -rotated.minX, y: -rotated.minY))
            let scale = min(frame.width / size.width, frame.height / size.height)
            let fit = toOrigin
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: (frame.width - size.width * scale) / 2, y: (frame.height - size.height * scale) / 2))
            layer.setTransform(fit, at: piece.range.start)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = piece.range
            instruction.layerInstructions = [layer]
            return instruction
        }
        let composition = AVMutableVideoComposition()
        composition.renderSize = frame
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.instructions = instructions
        return composition
    }

    private static func error(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "talkroll", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
