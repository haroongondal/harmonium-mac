import Foundation
import IOKit.hid

// Apple's hinge sensor on recent MacBooks: feature report 1 = [id, angle lo, angle hi] in degrees. Not public API.
final class LidSensor {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    private let device: IOHIDDevice

    init?() {
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x05AC,
            kIOHIDProductIDKey: 0x8104,
            kIOHIDPrimaryUsagePageKey: 0x20,
            kIOHIDPrimaryUsageKey: 0x8A,
        ] as CFDictionary)
        guard IOHIDManagerOpen(manager, 0) == kIOReturnSuccess,
              let found = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>)?.first
        else { return nil }
        device = found
        guard angle() != nil else { return nil }
    }

    deinit { IOHIDManagerClose(manager, 0) }

    func angle() -> Double? {
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        guard IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length) == kIOReturnSuccess, length >= 3
        else { return nil }
        return Double(UInt16(report[2]) << 8 | UInt16(report[1]))
    }
}
