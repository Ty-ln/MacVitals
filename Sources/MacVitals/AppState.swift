import Foundation
import Observation

/// Owns the monitors and samples them on a timer: every 10 s in the background,
/// every 2 s while the dashboard is visible.
@Observable
final class AppState {
    var cpu = CPUSample()
    var cpuHistory: [HistoryPoint] = []
    var temperature: Double?
    var temperatureHistory: [HistoryPoint] = []
    var memory = MemorySample()
    var thermalState: ProcessInfo.ThermalState
    var thermalHistory: [ThermalEvent] = []
    var processes: [ProcessUsage] = []
    var power: PowerSample?
    var disk: DiskSample?
    var net = NetSample()
    var lastUpdate = Date()
    /// System dark mode. The menu bar cat is redrawn when it changes.
    var darkMode = AppState.systemIsDark()

    var brew: BrewResult?
    var brewError: String?
    var brewChecking = false
    var brewLastChecked: Date?
    /// Last check that ran `brew update`; the interval in Settings counts from here.
    @ObservationIgnored private var brewLastUpdated: Date?
    /// Homebrew changes caused by our own check are ignored until then.
    @ObservationIgnored private var brewIgnoreChangesUntil = Date.distantPast

    let settings = Settings()

    var popoverOpen = false {
        didSet {
            guard oldValue != popoverOpen else { return }
            schedule()
            if popoverOpen { refresh() }
        }
    }

    @ObservationIgnored private let cpuMonitor = CPUMonitor()
    @ObservationIgnored private let netMonitor = NetMonitor()
    @ObservationIgnored private let thermal = ThermalMonitor()
    @ObservationIgnored private let temperatureMonitor = TemperatureMonitor()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var brewWatcher: BrewWatcher?

    init() {
        thermalState = thermal.state
        thermalHistory = thermal.history
        thermal.onChange = { [weak self] in self?.syncThermal() }
        refresh()
        schedule()
        // Refresh the Brew tab right after you upgrade or update in the terminal.
        brewWatcher = BrewWatcher { [weak self] in self?.brewChanged() }
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [weak self] _ in self?.darkMode = AppState.systemIsDark() }
    }

    private static func systemIsDark() -> Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }

    var isThrottling: Bool { thermalState.isThrottling }
    var brewPending: Bool { (brew?.count ?? 0) > 0 }

    var dots: [StatusDot] {
        var dots: [StatusDot] = [isThrottling ? .throttling : .normal]
        if brewPending { dots.append(.brew) }
        return dots
    }

    var accessibilitySummary: String {
        var parts = [isThrottling ? "Throttling" : "Normal"]
        if brewPending { parts.append("\(brew?.count ?? 0) brew updates") }
        return "MacVitals: " + parts.joined(separator: ", ")
    }

    var brewNextCheck: Date? { brewLastUpdated?.addingTimeInterval(TimeInterval(settings.brewIntervalHours) * 3600) }

    func refresh() {
        cpu = cpuMonitor.sample()
        temperature = temperatureMonitor.sample()
        recordHistory()
        memory = MemoryMonitor.sample()
        power = PowerMonitor.sample()
        disk = DiskMonitor.sample()
        net = netMonitor.sample()
        thermal.record()
        syncThermal()
        lastUpdate = Date()

        if popoverOpen {
            DispatchQueue.global(qos: .utility).async {
                let top = ProcessMonitor.top()
                DispatchQueue.main.async { self.processes = top }
            }
        }
        // Checked on every tick rather than with its own timer, so a check missed during sleep runs on wake.
        if let next = brewNextCheck, next > Date() { return }
        checkBrew()
    }

    /// `update: false` skips `brew update`, for rechecks after Homebrew changed locally.
    func checkBrew(update: Bool = true) {
        guard !brewChecking else { return }
        brewChecking = true
        DispatchQueue.global(qos: .utility).async {
            let result = BrewChecker.check(update: update)
            DispatchQueue.main.async {
                let now = Date()
                self.brewChecking = false
                self.brewLastChecked = now
                if update { self.brewLastUpdated = now }
                // Our own `brew update` touches the watched cache; don't react to that.
                self.brewIgnoreChangesUntil = now.addingTimeInterval(10)
                switch result {
                case .success(let value):
                    self.brew = value
                    self.brewError = nil
                case .failure(let error):
                    // Keep the last list: one failed check doesn't mean the updates went away.
                    self.brewError = error.localizedDescription
                }
            }
        }
    }

    private func brewChanged() {
        guard !brewChecking, Date() > brewIgnoreChangesUntil else { return }
        checkBrew(update: false)
    }

    /// Keeps the same 30-minute window as the thermal history.
    private func recordHistory() {
        let now = Date()
        let cutoff = now.addingTimeInterval(-ThermalMonitor.window)
        func append(_ value: Double, to history: inout [HistoryPoint]) {
            history.append(HistoryPoint(date: now, value: value))
            if let first = history.firstIndex(where: { $0.date >= cutoff }), first > 0 {
                history.removeFirst(first)
            }
        }
        append(cpu.total, to: &cpuHistory)
        if let temperature { append(temperature, to: &temperatureHistory) }
    }

    private func syncThermal() {
        thermalState = thermal.state
        thermalHistory = thermal.history
    }

    private func schedule() {
        timer?.invalidate()
        let interval: TimeInterval = popoverOpen ? 2 : 10
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = interval * 0.2
        // .common so sampling keeps going while the dashboard is being interacted with.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
