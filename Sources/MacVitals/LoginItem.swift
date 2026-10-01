import Foundation
import ServiceManagement

/// Launch at login via SMAppService, falling back to a LaunchAgent when the
/// ad-hoc-signed app can't register.
enum LoginItem {
    private static let agentURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/io.github.macvitals.plist")

    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
            || FileManager.default.fileExists(atPath: agentURL.path)
    }

    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
            } catch {
                writeAgent()
            }
        } else {
            try? SMAppService.mainApp.unregister()
            try? FileManager.default.removeItem(at: agentURL)
        }
    }

    private static func writeAgent() {
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": "io.github.macvitals",
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        try? FileManager.default.createDirectory(at: agentURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: agentURL, atomically: true)
    }
}
