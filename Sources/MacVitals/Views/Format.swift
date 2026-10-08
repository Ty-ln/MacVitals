import SwiftUI

enum Format {
    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    /// Binary gigabytes, like Activity Monitor.
    static func gb(_ bytes: UInt64, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", Double(bytes) / 1_073_741_824)
    }

    /// Binary units, like Activity Monitor.
    static func memory(_ bytes: UInt64) -> String { scaled(Double(bytes), base: 1024) }

    /// Decimal units, like Finder.
    static func disk(_ bytes: Int64) -> String { scaled(Double(bytes), base: 1000) }

    static func rate(_ bytesPerSecond: Double) -> String { scaled(bytesPerSecond, base: 1000) + "/s" }

    /// Locale-independent so numbers match the English UI (ByteCountFormatter follows the system locale).
    private static func scaled(_ value: Double, base: Double) -> String {
        var value = value
        var unit = 0
        let units = ["B", "KB", "MB", "GB", "TB"]
        while value >= base, unit < units.count - 1 {
            value /= base
            unit += 1
        }
        let decimals = unit == 0 || value >= 10 ? 0 : 1
        return String(format: "%.\(decimals)f %@", value, units[unit])
    }

    static func relative(_ date: Date, to now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func temperature(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = unit == .celsius ? celsius : celsius * 9 / 5 + 32
        return "\(Int(value.rounded())) \(unit.symbol)"
    }

    static func duration(minutes: Int) -> String { "\(minutes / 60):" + String(format: "%02d", minutes % 60) }
}
