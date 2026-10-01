import Foundation

struct CPUSample {
    var total: Double = 0        // 0...1
    var performance: Double = 0  // 0...1
    var efficiency: Double = 0   // 0...1
}

struct CPUPoint {
    let date: Date
    let load: Double  // 0...1
}

/// Per-core load from host_processor_info tick deltas.
/// On Apple Silicon the efficiency cores come first in logical CPU order.
final class CPUMonitor {
    private var previous: [(busy: UInt64, total: UInt64)] = []
    private let efficiencyCount = Sysctl.int("hw.perflevel1.logicalcpu") ?? 0

    func sample() -> CPUSample {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                  &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return CPUSample() }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        var current: [(busy: UInt64, total: UInt64)] = []
        for cpu in 0..<Int(cpuCount) {
            let base = Int(CPU_STATE_MAX) * cpu
            func ticks(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            let busy = ticks(CPU_STATE_USER) + ticks(CPU_STATE_SYSTEM) + ticks(CPU_STATE_NICE)
            current.append((busy, busy + ticks(CPU_STATE_IDLE)))
        }
        defer { previous = current }
        guard previous.count == current.count else { return CPUSample() }

        var all = (busy: 0.0, total: 0.0), eff = all, perf = all
        for (i, (now, before)) in zip(current, previous).enumerated() {
            let busy = Double(now.busy &- before.busy), total = Double(now.total &- before.total)
            all.busy += busy; all.total += total
            if i < efficiencyCount { eff.busy += busy; eff.total += total }
            else { perf.busy += busy; perf.total += total }
        }
        func ratio(_ p: (busy: Double, total: Double)) -> Double { p.total > 0 ? p.busy / p.total : 0 }
        return CPUSample(total: ratio(all), performance: ratio(perf), efficiency: ratio(eff))
    }
}
