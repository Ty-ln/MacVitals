import SwiftUI

struct PowerRow: View {
    let power: PowerSample?

    var body: some View {
        if let power {
            HStack {
                Label(statusText(power), systemImage: icon(power))
                Spacer()
                Text(rightText(power)).foregroundStyle(.secondary).monospacedDigit()
            }
        } else {
            Text("No battery found").foregroundStyle(.secondary)
        }
    }

    private func statusText(_ p: PowerSample) -> String {
        let state = p.isCharging ? "charging" : p.onAdapter ? "on power adapter" : "on battery"
        return "\(p.percent)% · \(state)" + (p.lowPowerMode ? " · Low Power" : "")
    }

    private func rightText(_ p: PowerSample) -> String {
        var parts: [String] = []
        if let watts = p.watts, abs(watts) >= 0.1 {
            parts.append(String(format: "%@%.1f W", watts > 0 ? "+" : "", abs(watts)))
        }
        if let minutes = p.minutesRemaining {
            parts.append("\(Format.duration(minutes: minutes)) \(p.isCharging ? "to full" : "left")")
        }
        return parts.joined(separator: " · ")
    }

    private func icon(_ p: PowerSample) -> String {
        if p.isCharging { return "battery.100.bolt" }
        switch p.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}
