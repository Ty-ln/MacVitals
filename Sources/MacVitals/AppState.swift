import Foundation
import Observation

/// Owns the monitors and samples them on a timer: every 10 s in the background,
/// every 2 s while the dashboard is visible.
@Observable
final class AppState {
    var cpu = CPUSample()
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
