import Darwin

enum MemoryPressure: Int {
    case normal = 1, warning = 2, critical = 4
}

struct MemorySample {
    var used: UInt64 = 0
    var total: UInt64 = 0
    var swapUsed: UInt64 = 0
    var pressure: MemoryPressure = .normal
    var fraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

/// "Used" matches Activity Monitor: app memory + wired + compressed.
enum MemoryMonitor {
    static func sample() -> MemorySample {
        var result = MemorySample()
        result.total = UInt64(Sysctl.int("hw.memsize") ?? 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            // The counters aren't read atomically, so purgeable can briefly exceed internal; don't underflow.
            let app = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
            result.used = (app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * page
        }
        if let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self) {
            result.swapUsed = swap.xsu_used
        }
        result.pressure = MemoryPressure(rawValue: Sysctl.int("kern.memorystatus_vm_pressure_level") ?? 1) ?? .normal
        return result
    }
}
