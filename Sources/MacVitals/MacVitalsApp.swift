import SwiftUI

@main
struct MacVitalsApp: App {
    @State private var state: AppState

    init() {
        // `--login-item on|off` toggles launch at login from the command line, then exits.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--login-item"), i + 1 < args.count {
            LoginItem.set(args[i + 1] == "on")
            exit(0)
        }

        let state = AppState()
        _state = State(initialValue: state)
        if let dir = Snapshot.directory {
            DispatchQueue.main.async { Snapshot.run(state: state, into: dir) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView(state: state)
        } label: {
            Image(nsImage: StatusDots.image(for: state.dots, settings: state.settings, dark: state.darkMode))
                .accessibilityLabel(state.accessibilitySummary)
        }
        .menuBarExtraStyle(.window)
    }
}
