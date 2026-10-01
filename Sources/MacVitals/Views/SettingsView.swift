import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var needsApproval = LoginItem.needsApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Dot colors")
            ColorRow(title: "Normal", dot: .normal, settings: settings)
            ColorRow(title: "Throttling", dot: .throttling, settings: settings)
            ColorRow(title: "Brew updates", dot: .brew, settings: settings)
            Button("Reset colors") { settings.resetColors() }
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
}

private struct ColorRow: View {
    let title: String
    let dot: StatusDot
    @Bindable var settings: Settings

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 5) {
                ForEach(DotColor.allCases) { color in
                    let selected = settings.colors[dot] == color
                    Circle()
                        .fill(Color(nsColor: color.nsColor))
                        .frame(width: 14, height: 14)
                        .padding(2)
                        .overlay(Circle().strokeBorder(selected ? Color.primary : .clear, lineWidth: 1.5))
                        .contentShape(Circle())
                        .onTapGesture { settings.colors[dot] = color }
                        .help(color.rawValue.capitalized)
                        .accessibilityLabel("\(title): \(color.rawValue)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
