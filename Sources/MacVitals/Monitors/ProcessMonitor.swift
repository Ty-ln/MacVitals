import Foundation

struct ProcessUsage: Identifiable {
    let id: Int32
    let name: String
    let cpu: Double     // percent, can exceed 100 on multiple cores
    let memory: UInt64  // bytes (resident)
}

enum ProcessMonitor {
    /// Top processes by CPU, via `ps` so no private APIs or root are needed.
    static func top(_ limit: Int = 5) -> [ProcessUsage] {
        guard let output = Shell.run("/bin/ps", ["-Aceo", "pid=,pcpu=,rss=,comm=", "-r"], timeout: 5)?.stdout
        else { return [] }
        return output.split(separator: "\n").prefix(limit).compactMap { line in
            let fields = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard fields.count == 4, let pid = Int32(fields[0]), let cpu = Double(fields[1]),
                  let rss = UInt64(fields[2]) else { return nil }
            return ProcessUsage(id: pid, name: String(fields[3]), cpu: cpu, memory: rss * 1024)
        }
    }
}
