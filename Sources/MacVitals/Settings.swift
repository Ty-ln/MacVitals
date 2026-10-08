import AppKit
import Observation
import SwiftUI

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

/// A chart color: the system accent color or one of the dot colors. Stored as "accent" or a DotColor name.
enum ChartColor: Hashable {
    case accent
    case dot(DotColor)

    static let all: [ChartColor] = [.accent] + DotColor.allCases.map { .dot($0) }

    init?(rawValue: String) {
        if rawValue == "accent" { self = .accent } else if let dot = DotColor(rawValue: rawValue) { self = .dot(dot) } else { return nil }
    }

    var rawValue: String {
        switch self {
        case .accent: "accent"
        case .dot(let dot): dot.rawValue
        }
    }

    var color: Color {
        switch self {
        case .accent: .accentColor
        case .dot(let dot): Color(nsColor: dot.nsColor)
        }
    }
}

enum ChartStyle: String, CaseIterable, Identifiable {
    case area, line, bars
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius, fahrenheit
    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }
}

/// User preferences, persisted in UserDefaults.
@Observable
final class Settings {
    static let brewIntervals = [1, 3, 6, 12, 24]
    private static let defaults: [StatusDot: DotColor] = [.normal: .green, .throttling: .red, .brew: .blue]
    static let defaultCPUChartColor = ChartColor.accent

    var colors: [StatusDot: DotColor] { didSet { save() } }
    var brewIntervalHours: Int { didSet { save() } }
    var chartStyle: ChartStyle { didSet { save() } }
    var cpuChartColor: ChartColor { didSet { save() } }
    var temperatureUnit: TemperatureUnit { didSet { save() } }

    init() {
        let store = UserDefaults.standard
        colors = Self.defaults.reduce(into: [:]) { result, entry in
            result[entry.key] = store.string(forKey: "color.\(entry.key)").flatMap(DotColor.init) ?? entry.value
        }
        let hours = store.integer(forKey: "brewIntervalHours")
        brewIntervalHours = Self.brewIntervals.contains(hours) ? hours : 6
        chartStyle = store.string(forKey: "chartStyle").flatMap(ChartStyle.init) ?? .area
        cpuChartColor = store.string(forKey: "chartColor.cpu").flatMap(ChartColor.init) ?? Self.defaultCPUChartColor
        temperatureUnit = store.string(forKey: "temperatureUnit").flatMap(TemperatureUnit.init) ?? .celsius
    }

    func color(for dot: StatusDot) -> NSColor { (colors[dot] ?? Self.defaults[dot]!).nsColor }

    /// Nominal and throttling follow the chosen dot colors; fair (warm) stays orange.
    func color(for thermal: ProcessInfo.ThermalState) -> Color {
        switch thermal {
        case .nominal: Color(nsColor: color(for: .normal))
        case .fair: .orange
        default: Color(nsColor: color(for: .throttling))
        }
    }

    func resetColors() { colors = Self.defaults }

    func resetCharts() {
        chartStyle = .area
        cpuChartColor = Self.defaultCPUChartColor
        temperatureUnit = .celsius
    }

    private func save() {
        let store = UserDefaults.standard
        for (dot, color) in colors { store.set(color.rawValue, forKey: "color.\(dot)") }
        store.set(brewIntervalHours, forKey: "brewIntervalHours")
        store.set(chartStyle.rawValue, forKey: "chartStyle")
        store.set(cpuChartColor.rawValue, forKey: "chartColor.cpu")
        store.set(temperatureUnit.rawValue, forKey: "temperatureUnit")
    }
}
