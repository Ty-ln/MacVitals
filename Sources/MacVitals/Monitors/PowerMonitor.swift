import Foundation
import IOKit
import IOKit.ps

struct PowerSample {
    var percent: Int = 0
    var isCharging = false
    var onAdapter = false
    var minutesRemaining: Int?  // to empty when discharging, to full when charging
    var watts: Double?          // battery in/out, from AppleSmartBattery
    var lowPowerMode = false
}

enum PowerMonitor {
    static func sample() -> PowerSample? {
        let blob = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(blob).takeRetainedValue() as [CFTypeRef]
        guard let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any]
        else { return nil }

        var result = PowerSample()
        let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        result.percent = max > 0 ? current * 100 / max : current
        result.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        result.onAdapter = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let minutes = desc[result.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int ?? -1
        result.minutesRemaining = minutes > 0 ? minutes : nil
        result.watts = batteryWatts()
        result.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        return result
    }

    /// Voltage (mV) × amperage (mA). Amperage is signed but stored as an unsigned 64-bit value.
    private static func batteryWatts() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        func number(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber
        }
        guard let voltage = number("Voltage"),
              let amperage = number("InstantAmperage") ?? number("Amperage") else { return nil }
        let mA = Int64(bitPattern: amperage.uint64Value)
        return Double(voltage.int64Value) * Double(mA) / 1_000_000
    }
}
