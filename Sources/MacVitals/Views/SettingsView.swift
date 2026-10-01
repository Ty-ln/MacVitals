import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.needsApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Dot colors")
            ForEach([(StatusDot.normal, "Normal"), (.throttling, "Throttling"), (.brew, "Brew updates")], id: \.0) { dot, title in
                SwatchRow(
                    title: title,
                    options: DotColor.allCases.map { ($0.rawValue, Color(nsColor: $0.nsColor), $0.rawValue.capitalized) },
                    selection: Binding(
                        get: { settings.colors[dot]?.rawValue ?? "" },
                        set: { settings.colors[dot] = DotColor(rawValue: $0) }
                    )
                )
            }
            Button("Reset colors") { settings.resetColors() }
                .controlSize(.small)

            SectionHeader(title: "Charts")
            LabeledRow(title: "Style") {
                Picker("Style", selection: $settings.chartStyle) {
                    ForEach(ChartStyle.allCases) { Text($0.title).tag($0) }
                }
            }
            SwatchRow(title: "CPU color", options: chartOptions, selection: chartBinding(\.cpuChartColor))
            LabeledRow(title: "Unit") {
                Picker("Unit", selection: $settings.temperatureUnit) {
                    ForEach(TemperatureUnit.allCases) { Text($0.symbol).tag($0) }
                }
            }
            Button("Reset charts") { settings.resetCharts() }
                .controlSize(.small)

            SectionHeader(title: "Homebrew")
            Picker("Check every", selection: $settings.brewIntervalHours) {
                ForEach(Settings.brewIntervals, id: \.self) { hours in
                    Text(hours == 1 ? "1 hour" : "\(hours) hours").tag(hours)
                }
            }
            .fixedSize()

            SectionHeader(title: "General")
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, enabled in
                    LoginItem.set(enabled)
                    needsApproval = LoginItem.needsApproval
                }
            if needsApproval {
                Text("Approve MacVitals in System Settings › General › Login Items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private var chartOptions: [(String, Color, String)] {
        ChartColor.all.map { color in
            (color.rawValue, color.color, color == .accent ? "System accent color" : color.rawValue.capitalized)
        }
    }

    private func chartBinding(_ keyPath: ReferenceWritableKeyPath<Settings, ChartColor>) -> Binding<String> {
        Binding(
            get: { settings[keyPath: keyPath].rawValue },
            set: { if let color = ChartColor(rawValue: $0) { settings[keyPath: keyPath] = color } }
        )
    }
}

private struct LabeledRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            content
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// A row of color swatches. The system accent swatch is drawn as a color wheel, like in System Settings.
private struct SwatchRow: View {
    let title: String
    let options: [(id: String, color: Color, name: String)]
    @Binding var selection: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 4) {
                ForEach(options, id: \.id) { option in
                    let selected = selection == option.id
                    swatch(option)
                        .frame(width: 12, height: 12)
                        .padding(2)
                        .overlay(Circle().strokeBorder(selected ? Color.primary : .clear, lineWidth: 1.5))
                        .contentShape(Circle())
                        .onTapGesture { selection = option.id }
                        .help(option.name)
                        .accessibilityLabel("\(title): \(option.name)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private func swatch(_ option: (id: String, color: Color, name: String)) -> some View {
        if option.id == "accent" {
            Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
        } else {
            Circle().fill(option.color)
        }
    }
}
