import Foundation

/// Reads the SoC die temperature sensors ("PMU tdie…") through IOKit's HID event system,
/// the same source tools like Stats use. These functions aren't in the public headers,
/// so they're looked up by name at runtime. No root needed. Returns nil where no sensors
/// exist (Intel Macs, or if Apple changes or removes the API).
final class TemperatureMonitor {
    private let client: AnyObject?
    private let sensors: [AnyObject]

    init() {
        guard let hid = HID.shared, let client = hid.clientCreate(kCFAllocatorDefault).map(HID.take) else {
            self.client = nil
            sensors = []
            return
        }
        // Apple's vendor usage page for temperature sensors.
        _ = hid.setMatching(HID.pass(client), ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = hid.copyServices(HID.pass(client)).map(HID.take) as? [AnyObject] ?? []
        self.client = client
        sensors = services.filter { service in
            let name = hid.copyProperty(HID.pass(service), "Product" as CFString).map(HID.take) as? String
            return name?.contains("tdie") == true
        }
    }

    var isAvailable: Bool { !sensors.isEmpty }

    /// Hottest die sensor in °C; that's the one that drives throttling.
    func sample() -> Double? {
        guard let hid = HID.shared else { return nil }
        let readings = sensors.compactMap { sensor -> Double? in
            guard let event = hid.copyEvent(HID.pass(sensor), HID.temperatureEvent, 0, 0).map(HID.take) else { return nil }
            let value = hid.floatValue(HID.pass(event), HID.temperatureField)
            return (1...150).contains(value) ? value : nil
        }
        return readings.max()
    }
}

/// The private functions, looked up with `dlsym` instead of linked: if a macOS update removes one,
/// the temperature chart goes away instead of the whole app failing to launch.
private struct HID {
    typealias Object = UnsafeMutableRawPointer

    static let temperatureEvent: Int64 = 15
    static let temperatureField = Int32(15 << 16)

    let clientCreate: @convention(c) (CFAllocator?) -> Object?
    let setMatching: @convention(c) (Object, CFDictionary) -> Int32
    let copyServices: @convention(c) (Object) -> Object?
    let copyProperty: @convention(c) (Object, CFString) -> Object?
    let copyEvent: @convention(c) (Object, Int64, Int32, Int64) -> Object?
    let floatValue: @convention(c) (Object, Int32) -> Double

    static let shared: HID? = {
        guard let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else { return nil }
        func load<T>(_ name: String, as _: T.Type) -> T? {
            dlsym(iokit, name).map { unsafeBitCast($0, to: T.self) }
        }
        guard let clientCreate = load("IOHIDEventSystemClientCreate", as: (@convention(c) (CFAllocator?) -> Object?).self),
              let setMatching = load("IOHIDEventSystemClientSetMatching", as: (@convention(c) (Object, CFDictionary) -> Int32).self),
              let copyServices = load("IOHIDEventSystemClientCopyServices", as: (@convention(c) (Object) -> Object?).self),
              let copyProperty = load("IOHIDServiceClientCopyProperty", as: (@convention(c) (Object, CFString) -> Object?).self),
              let copyEvent = load("IOHIDServiceClientCopyEvent", as: (@convention(c) (Object, Int64, Int32, Int64) -> Object?).self),
              let floatValue = load("IOHIDEventGetFloatValue", as: (@convention(c) (Object, Int32) -> Double).self)
        else { return nil }
        return HID(clientCreate: clientCreate, setMatching: setMatching, copyServices: copyServices,
                   copyProperty: copyProperty, copyEvent: copyEvent, floatValue: floatValue)
    }()

    /// Takes ownership of an object a Create or Copy function returned.
    static func take(_ object: Object) -> AnyObject { Unmanaged<AnyObject>.fromOpaque(object).takeRetainedValue() }

    /// Lends an object to a call; the caller keeps it alive.
    static func pass(_ object: AnyObject) -> Object { Unmanaged.passUnretained(object).toOpaque() }
}
