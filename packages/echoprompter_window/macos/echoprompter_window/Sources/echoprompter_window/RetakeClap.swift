import Cocoa

/// The retake clap: a short beep and/or a brief flash in a small window that, unlike the prompter, is NOT hidden
/// from screen capture, so a screen recorder sees it and the person editing can find each take.
final class RetakeClap {
    private var flashWindow: NSWindow?
    private var flashWork: DispatchWorkItem?
    private var sound: NSSound?

    private static let flashSeconds = 0.2
    private static let size = NSSize(width: 160, height: 100)
    private static let margin: CGFloat = 16

    /// A 0.12 s burst at 1760 Hz with a hard start, so its onset is easy to spot in a waveform.
    private static let beep: Data = {
        let rate = 44100, frames = Int(Double(rate) * 0.12)
        var pcm = [Int16](repeating: 0, count: frames)
        for i in 0..<frames {
            let t = Double(i) / Double(rate)
            // Linear fade over the last 15 ms only, so the click at the start stays sharp.
            let tail = min(1.0, Double(frames - i) / (0.015 * Double(rate)))
            pcm[i] = Int16(sin(2 * .pi * 1760 * t) * 0.85 * tail * Double(Int16.max))
        }
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + frames * 2))
        d.append("WAVEfmt ".data(using: .ascii)!); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append("data".data(using: .ascii)!); u32(UInt32(frames * 2))
        pcm.withUnsafeBytes { d.append(contentsOf: $0) }
        return d
    }()

    func fire(sound wantsSound: Bool, flash wantsFlash: Bool, corner: String, on screen: NSScreen?) {
        if wantsSound {
            sound?.stop()
            sound = NSSound(data: Self.beep)
            sound?.play()
        }
        if wantsFlash, let screen = screen ?? NSScreen.main { flash(corner: corner, on: screen) }
    }

    private func flash(corner: String, on screen: NSScreen) {
        flashWork?.cancel()
        let v = screen.visibleFrame, size = Self.size, m = Self.margin
        let frame = NSRect(x: corner.hasSuffix("Left") ? v.minX + m : v.maxX - m - size.width,
                           y: corner.hasPrefix("top") ? v.maxY - m - size.height : v.minY + m,
                           width: size.width, height: size.height)
        let w = flashWindow ?? NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        if flashWindow == nil {
            w.isReleasedWhenClosed = false
            w.backgroundColor = .white
            w.isOpaque = true
            w.hasShadow = false
            w.ignoresMouseEvents = true
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            // The point of the flash: recorders must see it, whatever the prompter's own capture setting says.
            w.sharingType = .readOnly
            flashWindow = w
        }
        w.setFrame(frame, display: true)
        w.orderFrontRegardless()
        let work = DispatchWorkItem { [weak self] in self?.flashWindow?.orderOut(nil) }
        flashWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.flashSeconds, execute: work)
    }

    func dismiss() {
        flashWork?.cancel()
        flashWindow?.orderOut(nil)
        sound?.stop()
    }
}
