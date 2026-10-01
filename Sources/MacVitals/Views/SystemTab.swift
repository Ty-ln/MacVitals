import SwiftUI

struct SystemTab: View {
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThermalBanner(state: state.thermalState, history: state.thermalHistory, now: state.lastUpdate, settings: state.settings)

            CPUThermalHistory(state: state)

            MetricBar(
                title: "Memory",
                value: "\(Format.gb(state.memory.used)) / \(Format.gb(state.memory.total, decimals: 0)) GB",
                detail: memoryDetail,
                fraction: state.memory.fraction,
                color: pressureColor
            )

            SectionHeader(title: "Top processes")
            if state.processes.isEmpty {
                Text("Loading…").foregroundStyle(.secondary)
            }
            ForEach(state.processes) { process in
                HStack {
                    Text(process.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("\(Int(process.cpu.rounded()))% · \(Format.memory(process.memory))")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, design: .monospaced))
            }

            SectionHeader(title: "Battery and power")
            PowerRow(power: state.power)

            SectionHeader(title: "Disk and network")
            HStack {
                if let disk = state.disk {
                    Label("\(Format.disk(disk.free)) free", systemImage: "internaldrive")
                        .help("\(Format.disk(disk.free)) free of \(Format.disk(disk.total))")
                }
                Spacer()
                Text("↓ \(Format.rate(state.net.downPerSecond))  ↑ \(Format.rate(state.net.upPerSecond))")
                    .monospacedDigit()
            }
        }
        .font(.callout)
    }

    private var memoryDetail: String {
        var parts: [String] = []
        if state.memory.swapUsed > 0 { parts.append("swap \(Format.gb(state.memory.swapUsed)) GB") }
        switch state.memory.pressure {
        case .normal: break
        case .warning: parts.append("pressure high")
        case .critical: parts.append("pressure critical")
        }
        return parts.joined(separator: " · ")
    }

    private var pressureColor: Color {
        switch state.memory.pressure {
        case .normal: .accentColor
        case .warning: .orange
        case .critical: .red
        }
    }

}

private struct MetricBar: View {
    let title: String
    let value: String
    let detail: String
    let fraction: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value).monospacedDigit()
                if !detail.isEmpty {
                    Text("· \(detail)").foregroundStyle(.secondary).monospacedDigit()
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(color).frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.3), value: fraction)
        }
    }
}

private struct ThermalBanner: View {
    let state: ProcessInfo.ThermalState
    let history: [ThermalEvent]
    let now: Date
    let settings: Settings

    var body: some View {
        if state != .nominal {
            HStack(spacing: 8) {
                Image(systemName: state == .fair ? "thermometer.medium" : "flame")
                Text(message)
                Spacer(minLength: 0)
            }
            .foregroundStyle(settings.color(for: state))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(settings.color(for: state).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var message: String {
        if state == .fair { return "Running warm · thermal state fair" }
        var text = "Throttling · thermal state \(state.label)"
        if let since = throttledSince {
            let minutes = Int(now.timeIntervalSince(since) / 60)
            text += minutes < 1 ? " · just started" : " · for \(minutes) min"
        }
        return text
    }

    /// Start of the current unbroken run of serious-or-worse states.
    private var throttledSince: Date? {
        var since: Date?
        for event in history.reversed() {
            guard event.state.rawValue >= ProcessInfo.ThermalState.serious.rawValue else { break }
            since = event.date
        }
        return since
    }
}

/// CPU load chart with the thermal state band underneath, on one shared 30-minute time axis.
private struct CPUThermalHistory: View {
    let state: AppState

    var body: some View {
        let now = state.lastUpdate
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("CPU").foregroundStyle(.secondary)
                Spacer()
                Text(Format.percent(state.cpu.total)).monospacedDigit()
                Text("· P \(Format.percent(state.cpu.performance)) · E \(Format.percent(state.cpu.efficiency))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            CPUSparkline(points: state.cpuHistory, now: now)
                .frame(height: 36)
                .padding(.bottom, 4)

            HStack {
                Label("Thermal", systemImage: "thermometer.medium").foregroundStyle(.secondary)
                Spacer()
                Text(state.thermalState.label).foregroundStyle(state.settings.color(for: state.thermalState))
            }
            ThermalBand(history: state.thermalHistory, now: now, settings: state.settings)
                .frame(height: 6)
            HStack {
                Text("30 min ago")
                Spacer()
                Text("now")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Area chart of CPU load. Gaps longer than a minute (sleep) break the line.
private struct CPUSparkline: View {
    let points: [CPUPoint]
    let now: Date

    var body: some View {
        GeometryReader { geo in
            let segments = self.segments(in: geo.size)
            ZStack {
                ForEach(segments.indices, id: \.self) { i in
                    area(segments[i], height: geo.size.height).fill(Color.accentColor.opacity(0.18))
                    line(segments[i]).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }

    private func segments(in size: CGSize) -> [[CGPoint]] {
        let start = now.addingTimeInterval(-ThermalMonitor.window)
        var result: [[CGPoint]] = []
        var previous: Date?
        for point in points where point.date >= start {
            let x = point.date.timeIntervalSince(start) / ThermalMonitor.window * size.width
            let y = 1 + (size.height - 2) * (1 - min(max(point.load, 0), 1))
            if let previous, point.date.timeIntervalSince(previous) <= 60, !result.isEmpty {
                result[result.count - 1].append(CGPoint(x: x, y: y))
            } else {
                result.append([CGPoint(x: x, y: y)])
            }
            previous = point.date
        }
        return result.filter { $0.count > 1 }
    }

    private func line(_ points: [CGPoint]) -> Path {
        Path { $0.addLines(points) }
    }

    private func area(_ points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLines(points)
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }
}

private struct ThermalBand: View {
    let history: [ThermalEvent]
    let now: Date
    let settings: Settings

    var body: some View {
        GeometryReader { geo in
            let start = now.addingTimeInterval(-ThermalMonitor.window)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                ForEach(Array(history.enumerated()), id: \.offset) { i, event in
                    let from = max(event.date, start)
                    let to = i + 1 < history.count ? history[i + 1].date : now
                    let x = from.timeIntervalSince(start) / ThermalMonitor.window * geo.size.width
                    let w = max(to.timeIntervalSince(from), 0) / ThermalMonitor.window * geo.size.width
                    Rectangle().fill(settings.color(for: event.state)).frame(width: w).offset(x: x)
                }
            }
            .clipShape(Capsule())
        }
    }
}

private struct PowerRow: View {
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
