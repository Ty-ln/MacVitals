import AppKit
import Observation

enum DotColor: String, CaseIterable, Identifiable {
    case green, red, blue, orange, yellow, purple, pink, teal, gray

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .green: .systemGreen
        case .red: .systemRed
        case .blue: .systemBlue
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .purple: .systemPurple
        case .pink: .systemPink
        case .teal: .systemTeal
        case .gray: .systemGray
        }
    }
}

/// User preferences, persisted in UserDefaults.
@Observable
final class Settings {
    static let brewIntervals = [1, 3, 6, 12, 24]
    private static let defaults: [StatusDot: DotColor] = [.normal: .green, .throttling: .red, .brew: .blue]

    var colors: [StatusDot: DotColor] { didSet { save() } }
    var brewIntervalHours: Int { didSet { save() } }

    init() {
        let store = UserDefaults.standard
        colors = Self.defaults.reduce(into: [:]) { result, entry in
            result[entry.key] = store.string(forKey: "color.\(entry.key)").flatMap(DotColor.init) ?? entry.value
        }
        let hours = store.integer(forKey: "brewIntervalHours")
        brewIntervalHours = Self.brewIntervals.contains(hours) ? hours : 6
    }

    func color(for dot: StatusDot) -> NSColor { (colors[dot] ?? Self.defaults[dot]!).nsColor }

    func resetColors() { colors = Self.defaults }

    private func save() {
        let store = UserDefaults.standard
        for (dot, color) in colors { store.set(color.rawValue, forKey: "color.\(dot)") }
        store.set(brewIntervalHours, forKey: "brewIntervalHours")
    }
}
