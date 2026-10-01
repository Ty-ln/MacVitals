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

    var brew: BrewResult?
    var brewError: String?
    var brewChecking = false
    var brewLastChecked: Date?

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

    init() {
        thermalState = thermal.state
        thermalHistory = thermal.history
        thermal.onChange = { [weak self] in self?.syncThermal() }
        refresh()
        schedule()
    }

    var isThrottling: Bool { thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue }
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

    var brewNextCheck: Date? { brewLastChecked?.addingTimeInterval(TimeInterval(settings.brewIntervalHours) * 3600) }

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

    func checkBrew() {
        guard !brewChecking else { return }
        brewChecking = true
        DispatchQueue.global(qos: .utility).async {
            let result = BrewChecker.check()
            DispatchQueue.main.async {
                self.brewChecking = false
                self.brewLastChecked = Date()
                switch result {
                case .success(let value):
                    self.brew = value
                    self.brewError = nil
                case .failure(let error):
                    self.brew = nil
                    self.brewError = error.localizedDescription
                }
            }
        }
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

    /// Replaces every reading with made-up sample data, for `--snapshot --demo`.
    /// Used for the README screenshots, so they don't show this Mac's processes or packages.
    func seedDemo() {
        let now = Date()
        let window = ThermalMonitor.window
        cpuHistory = stride(from: window, through: 0, by: -10).map { ago in
            let t = 1 - ago / window
            let load = 0.6 / (1 + exp(-(t - 0.5) / 0.03))
            return HistoryPoint(date: now.addingTimeInterval(-ago), value: min(0.12 + load + 0.05 * sin(t * 40), 1))
        }
        // The die heats up after the load starts and keeps climbing towards throttling.
        temperatureHistory = stride(from: window, through: 0, by: -10).map { ago in
            let t = 1 - ago / window
            let heat = 58 / (1 + exp(-(t - 0.6) / 0.08))
            return HistoryPoint(date: now.addingTimeInterval(-ago), value: 36 + heat + 1.2 * sin(t * 25))
        }
        temperature = temperatureHistory.last?.value
        thermalHistory = [
            ThermalEvent(date: now.addingTimeInterval(-window), state: .nominal),
            ThermalEvent(date: now.addingTimeInterval(-window * 0.42), state: .fair),
            ThermalEvent(date: now.addingTimeInterval(-window * 0.18), state: .serious),
        ]
        thermalState = .serious
        cpu = CPUSample(total: cpuHistory.last?.value ?? 0, performance: 0.94, efficiency: 0.64)

        let gb: UInt64 = 1 << 30, mb: UInt64 = 1 << 20
        memory = MemorySample(used: gb * 112 / 10, total: 16 * gb, swapUsed: gb * 8 / 10, pressure: .normal)
        processes = [
            ProcessUsage(id: 1, name: "Xcode", cpu: 182, memory: gb * 21 / 10),
            ProcessUsage(id: 2, name: "Google Chrome Helper", cpu: 64, memory: gb * 14 / 10),
            ProcessUsage(id: 3, name: "node", cpu: 31, memory: 620 * mb),
            ProcessUsage(id: 4, name: "WindowServer", cpu: 18, memory: 150 * mb),
            ProcessUsage(id: 5, name: "Spotify", cpu: 6, memory: 310 * mb),
        ]
        power = PowerSample(percent: 64, isCharging: false, onAdapter: false,
                            minutesRemaining: 190, watts: -14.2, lowPowerMode: false)
        disk = DiskSample(free: 212_000_000_000, total: 494_000_000_000)
        net = NetSample(downPerSecond: 1_200_000, upPerSecond: 80_000)

        brew = BrewResult(
            formulae: [
                OutdatedPackage(name: "node", installed: "24.8.0", latest: "24.9.1"),
                OutdatedPackage(name: "git", installed: "2.51.0", latest: "2.51.1"),
                OutdatedPackage(name: "ffmpeg", installed: "8.0", latest: "8.0.1"),
            ],
            casks: [OutdatedPackage(name: "visual-studio-code", installed: "1.104.2", latest: "1.105.0")]
        )
        brewError = nil
        brewChecking = false
        brewLastChecked = now.addingTimeInterval(-38 * 60)
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
