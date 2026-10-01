import Foundation

/// Reads the SoC die temperature sensors ("PMU tdie…") through IOKit's HID event system,
/// the same source tools like Stats use. These functions aren't in the public headers,
/// so they're declared here by symbol name. No root needed. Returns nil where no sensors
/// exist (Intel Macs, or if Apple changes the API).
final class TemperatureMonitor {
    private let client: AnyObject?
    private let sensors: [AnyObject]

    init() {
        guard let client = HID.clientCreate(kCFAllocatorDefault)?.takeRetainedValue() else {
            self.client = nil
            sensors = []
            return
        }
        // Apple's vendor usage page for temperature sensors.
        _ = HID.setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = HID.copyServices(client)?.takeRetainedValue() as? [AnyObject] ?? []
        self.client = client
        sensors = services.filter { service in
            let name = HID.copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String
            return name?.contains("tdie") == true
        }
    }

    var isAvailable: Bool { !sensors.isEmpty }

    /// Hottest die sensor in °C; that's the one that drives throttling.
    func sample() -> Double? {
        let readings = sensors.compactMap { sensor -> Double? in
            guard let event = HID.copyEvent(sensor, HID.temperatureEvent, 0, 0)?.takeRetainedValue() else { return nil }
            let value = HID.floatValue(event, HID.temperatureField)
            return (1...150).contains(value) ? value : nil
        }
        return readings.max()
    }
}

private enum HID {
    static let temperatureEvent: Int64 = 15
    static let temperatureField = Int32(15 << 16)

    @_silgen_name("IOHIDEventSystemClientCreate")
    static func clientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDEventSystemClientSetMatching")
    static func setMatching(_ client: AnyObject, _ matching: CFDictionary) -> Int32
    @_silgen_name("IOHIDEventSystemClientCopyServices")
    static func copyServices(_ client: AnyObject) -> Unmanaged<CFArray>?
    @_silgen_name("IOHIDServiceClientCopyProperty")
    static func copyProperty(_ service: AnyObject, _ key: CFString) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDServiceClientCopyEvent")
    static func copyEvent(_ service: AnyObject, _ type: Int64, _ options: Int32, _ timeout: Int64) -> Unmanaged<AnyObject>?
    @_silgen_name("IOHIDEventGetFloatValue")
    static func floatValue(_ event: AnyObject, _ field: Int32) -> Double
}
