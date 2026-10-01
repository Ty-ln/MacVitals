import AppKit
import SwiftUI

/// `MacVitals --snapshot <dir> [--demo]` renders both dashboard tabs and the status dots to PNGs, then quits.
/// Uses an off-screen window, so it needs no screen recording permission.
enum Snapshot {
    static var directory: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func run(state: AppState, into dir: String) {
        state.popoverOpen = true
        // Wait for the brew check and a second CPU sample before rendering.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard !state.brewChecking, !state.processes.isEmpty else { return }
            timer.invalidate()
            if CommandLine.arguments.contains("--demo") { state.seedDemo() }
            for mode in ["light", "dark"] {
                render(DashboardView(state: state, initialTab: .system), mode: mode, to: "\(dir)/system-\(mode).png")
                render(DashboardView(state: state, initialTab: .brew), mode: mode, to: "\(dir)/brew-\(mode).png")
                render(DashboardView(state: state, showSettings: true), mode: mode, to: "\(dir)/settings-\(mode).png")
            }
            for (name, dots) in [("normal", [StatusDot.normal]), ("brew", [.normal, .brew]),
                                 ("throttling", [.throttling]), ("both", [.throttling, .brew])] {
                write(StatusDots.image(for: dots, settings: state.settings), to: "\(dir)/dots-\(name).png")
            }
            NSApp.terminate(nil)
        }
    }

    private static func render(_ view: some View, mode: String, to path: String) {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: mode == "dark" ? .darkAqua : .aqua)
        host.frame.size = host.fittingSize
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.backgroundColor = .windowBackgroundColor
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// Drawn at 2x so the dots stay sharp on Retina screens.
    private static func write(_ image: NSImage, to path: String) {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(image.size.width * 2),
                                         pixelsHigh: Int(image.size.height * 2), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return }
        rep.size = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
