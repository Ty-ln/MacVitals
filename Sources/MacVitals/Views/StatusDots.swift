import AppKit

enum StatusDot: Hashable {
    case normal, throttling, brew
}

enum StatusDots {
    private static let diameter: CGFloat = 8
    private static let gap: CGFloat = 4
    private static let height: CGFloat = 16

    /// Not a template image, so the menu bar keeps the colors instead of tinting them.
    static func image(for dots: [StatusDot], settings: Settings) -> NSImage {
        let width = CGFloat(dots.count) * diameter + CGFloat(max(dots.count - 1, 0)) * gap
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            for (i, dot) in dots.enumerated() {
                settings.color(for: dot).setFill()
                let x = CGFloat(i) * (diameter + gap)
                NSBezierPath(ovalIn: NSRect(x: x, y: (height - diameter) / 2, width: diameter, height: diameter)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
