import AppKit

enum StatusDot: Hashable {
    case normal, throttling, brew
}

/// The menu bar item: the cat, with the status dots as a small badge at its lower right.
enum StatusDots {
    private static let height: CGFloat = 18
    private static let dotSize: CGFloat = 5
    /// Clear ring around each dot, so it stays readable where it overlaps the cat's lines.
    private static let gap: CGFloat = 1

    private static let cat: NSImage? = Data(base64Encoded: CatImage.pngBase64).flatMap(NSImage.init(data:))

    /// Not a template image, so the dots keep their colors. The cat is drawn black or white to match
    /// the menu bar instead; `dark` is the fallback when the drawing appearance can't be determined.
    static func image(for dots: [StatusDot], settings: Settings, dark: Bool) -> NSImage {
        let catWidth = cat.map { height * $0.size.width / $0.size.height } ?? 0
        let firstDotX = catWidth - dotSize * 0.5
        let width = firstDotX + CGFloat(dots.count) * (dotSize + gap) + gap
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            let appearance = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua])
            let isDark = appearance.map { $0 == .darkAqua } ?? dark
            if let cat {
                tinted(cat, isDark ? .white : .black).draw(in: NSRect(x: 0, y: 0, width: catWidth, height: height))
            }
            for (i, dot) in dots.enumerated() {
                let rect = NSRect(x: firstDotX + CGFloat(i) * (dotSize + gap), y: gap, width: dotSize, height: dotSize)
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: rect.insetBy(dx: -gap, dy: -gap)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                settings.color(for: dot).setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
