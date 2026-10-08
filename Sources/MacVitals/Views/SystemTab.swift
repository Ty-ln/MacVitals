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

    /// Start of the current unbroken run of throttling states.
    private var throttledSince: Date? {
        var since: Date?
        for event in history.reversed() {
            guard event.state.isThrottling else { break }
            since = event.date
        }
        return since
    }
}

/// CPU and temperature charts with the thermal state band underneath, on one shared 30-minute time axis.
private struct CPUThermalHistory: View {
    let state: AppState

    /// Fixed scale so the chart shows real headroom; Apple Silicon throttles around 95–105 °C.
    private static let temperatureRange = 20.0...110.0

    var body: some View {
        let now = state.lastUpdate
        let settings = state.settings
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("CPU").foregroundStyle(.secondary)
                Spacer()
                Text(Format.percent(state.cpu.total)).monospacedDigit()
                if state.cpu.hasCoreTypes {
                    Text("· P \(Format.percent(state.cpu.performance)) · E \(Format.percent(state.cpu.efficiency))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            HistoryChart(points: state.cpuHistory, now: now, range: 0...1,
                         style: settings.chartStyle, color: settings.cpuChartColor.color)
                .frame(height: 36)
                .padding(.bottom, 4)

            if let temperature = state.temperature {
                // The thermal state colors the temperature chart, so there's no separate band.
                HStack {
                    Label("Temperature", systemImage: "thermometer.medium").foregroundStyle(.secondary)
                    Spacer()
                    Text(Format.temperature(temperature, unit: settings.temperatureUnit))
                        .monospacedDigit()
                        .help("Hottest SoC die sensor")
                    Text("· \(state.thermalState.label)")
                        .foregroundStyle(settings.color(for: state.thermalState))
                }
                HistoryChart(points: state.temperatureHistory, now: now, range: Self.temperatureRange,
                             style: settings.chartStyle, color: settings.color(for: state.thermalState),
                             tint: thermalTint(now: now))
                    .frame(height: 40)
            } else {
                // No temperature sensors (e.g. Intel): show the thermal state as a band instead.
                HStack {
                    Label("Thermal", systemImage: "flame").foregroundStyle(.secondary)
                    Spacer()
                    Text(state.thermalState.label).foregroundStyle(settings.color(for: state.thermalState))
                }
                ThermalBand(history: state.thermalHistory, now: now, settings: settings)
                    .frame(height: 6)
            }
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

    /// One colored time span per thermal state, from the thermal history.
    private func thermalTint(now: Date) -> [ChartTint] {
        let history = state.thermalHistory
        return history.indices.map { i in
            ChartTint(from: history[i].date,
                      to: i + 1 < history.count ? history[i + 1].date : now,
                      color: state.settings.color(for: history[i].state))
        }
    }
}
