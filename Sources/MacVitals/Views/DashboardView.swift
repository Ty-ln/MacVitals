import SwiftUI

struct DashboardView: View {
    let state: AppState
    @State private var tab: Tab
    @State private var showSettings: Bool

    enum Tab { case system, brew }

    init(state: AppState, initialTab: Tab = .system, showSettings: Bool = false) {
        self.state = state
        _tab = State(initialValue: initialTab)
        _showSettings = State(initialValue: showSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                Text("Settings").font(.headline)
                SettingsView(settings: state.settings)
            } else {
                Picker("", selection: $tab) {
                    Text("System").tag(Tab.system)
                    Text(brewTabTitle).tag(Tab.brew)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                switch tab {
                case .system: SystemTab(state: state)
                case .brew: BrewTab(state: state)
                }
            }

            Divider()
            HStack {
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: showSettings ? "chevron.backward" : "gearshape")
                }
                .buttonStyle(.borderless)
                .help(showSettings ? "Back" : "Settings")
                .accessibilityLabel(showSettings ? "Back" : "Settings")
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .font(.callout)
        }
        .padding(14)
        .frame(width: 330)
        .background(VisibilityReader { state.popoverOpen = $0 })
    }

    private var brewTabTitle: String {
        let count = state.brew?.count ?? 0
        return count > 0 ? "Brew · \(count)" : "Brew"
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}
