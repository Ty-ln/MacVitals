import Foundation

struct ThermalEvent {
    let date: Date
    let state: ProcessInfo.ThermalState
}

/// Tracks ProcessInfo.thermalState, the only public signal for throttling on fanless Macs.
/// Set MACVITALS_FAKE_THERMAL=fair|serious|critical to test. Only the environment counts, not a stored
/// default, so a test value can't outlive the launch it was meant for.
final class ThermalMonitor {
    static let window: TimeInterval = 30 * 60

    private(set) var history: [ThermalEvent] = []
    var onChange: (() -> Void)?
    private var observer: NSObjectProtocol?

    var state: ProcessInfo.ThermalState { Self.fakeState ?? ProcessInfo.processInfo.thermalState }

    init() {
        history = [ThermalEvent(date: Date(), state: state)]
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.record() }
    }

    /// Appends a transition if the state changed and drops events older than the window,
    /// keeping the last one before the cutoff so the timeline starts with a known state.
    func record() {
        let now = Date()
        if history.last?.state != state {
            history.append(ThermalEvent(date: now, state: state))
            onChange?()
        }
        let cutoff = now.addingTimeInterval(-Self.window)
        while history.count > 1, history[1].date < cutoff { history.removeFirst() }
    }

    private static let fakeState: ProcessInfo.ThermalState? = {
        switch ProcessInfo.processInfo.environment["MACVITALS_FAKE_THERMAL"]?.lowercased() {
        case "nominal": return .nominal
        case "fair": return .fair
        case "serious": return .serious
        case "critical": return .critical
        default: return nil
        }
    }()
}

extension ProcessInfo.ThermalState {
    /// `serious` and `critical` are when macOS limits performance.
    var isThrottling: Bool { rawValue >= ProcessInfo.ThermalState.serious.rawValue }

    var label: String {
        switch self {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
}
