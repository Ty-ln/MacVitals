import Foundation

struct DiskSample {
    var free: Int64 = 0
    var total: Int64 = 0
}

struct NetSample {
    var downPerSecond: Double = 0
    var upPerSecond: Double = 0
}

enum DiskMonitor {
    static func sample() -> DiskSample? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys) else { return nil }
        return DiskSample(free: values.volumeAvailableCapacityForImportantUsage ?? 0,
                          total: Int64(values.volumeTotalCapacity ?? 0))
    }
}

/// Throughput from per-interface byte counters. The counters are 32-bit and wrap, so deltas are per interface.
final class NetMonitor {
    /// Loopback, plus interfaces whose traffic isn't network traffic of its own: VPN tunnels and bridges
    /// carry what's already counted on the physical interface, AWDL and LLW are AirDrop and Continuity.
    private static let skipped = ["lo", "utun", "ipsec", "gif", "stf", "bridge", "awdl", "llw"]

    private var previous: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var lastDate: Date?

    func sample() -> NetSample {
        var current: [String: (rx: UInt32, tx: UInt32)] = [:]
        var addrs: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&addrs) == 0, let first = addrs {
            for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
                let ifa = ptr.pointee
                guard ifa.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), let data = ifa.ifa_data else { continue }
                let name = String(cString: ifa.ifa_name)
                guard !Self.skipped.contains(where: name.hasPrefix) else { continue }
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                current[name] = (stats.ifi_ibytes, stats.ifi_obytes)
            }
            freeifaddrs(addrs)
        }

        let now = Date()
        defer { previous = current; lastDate = now }
        guard let lastDate, now.timeIntervalSince(lastDate) > 0 else { return NetSample() }

        var rx: UInt64 = 0, tx: UInt64 = 0
        for (name, counters) in current {
            guard let before = previous[name] else { continue }
            rx += UInt64(counters.rx &- before.rx)
            tx += UInt64(counters.tx &- before.tx)
        }
        let seconds = now.timeIntervalSince(lastDate)
        return NetSample(downPerSecond: Double(rx) / seconds, upPerSecond: Double(tx) / seconds)
    }
}
