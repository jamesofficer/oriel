//
//  KeyboardDeviceMonitor.swift
//  switchr
//

import Combine
import Foundation
import IOKit.hid

final class KeyboardDeviceMonitor: ObservableObject {
    @Published private(set) var connectedKeyboards: [KeyboardDevice] = []
    @Published private(set) var monitoringError: String?

    private let manager: IOHIDManager
    private var isStarted = false

    init() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, keyboardDevicesChanged, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, keyboardDevicesChanged, context)
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> IOReturn {
        guard !isStarted else { return kIOReturnSuccess }
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            monitoringError = "Switchr could not monitor connected keyboards (\(result))."
            return result
        }
        monitoringError = nil
        isStarted = true
        refreshDevices()
        return result
    }

    func stop() {
        guard isStarted else { return }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        isStarted = false
        connectedKeyboards = []
    }

    fileprivate func refreshDevices() {
        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            connectedKeyboards = []
            return
        }
        let count = CFSetGetCount(deviceSet)
        var pointers = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &pointers)
        var identities = Set<KeyboardIdentity>()
        connectedKeyboards = pointers.compactMap { pointer in
            guard let pointer else { return nil }
            let device = Unmanaged<IOHIDDevice>.fromOpaque(pointer).takeUnretainedValue()
            let keyboard = Self.keyboardDevice(from: device)
            guard identities.insert(keyboard.identity).inserted else { return nil }
            return keyboard
        }
        .sorted {
            if $0.isBuiltIn != $1.isBuiltIn { return $0.isBuiltIn }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func keyboardDevice(from device: IOHIDDevice) -> KeyboardDevice {
        let productName = stringProperty(device, key: kIOHIDProductKey) ?? "Unknown Keyboard"
        let identity = KeyboardIdentity(
            vendorID: intProperty(device, key: kIOHIDVendorIDKey),
            productID: intProperty(device, key: kIOHIDProductIDKey),
            serialNumber: stringProperty(device, key: kIOHIDSerialNumberKey),
            locationID: intProperty(device, key: kIOHIDLocationIDKey),
            transport: stringProperty(device, key: kIOHIDTransportKey)
        )
        return KeyboardDevice(
            identity: identity,
            name: productName,
            isBuiltIn: boolProperty(device, key: kIOHIDBuiltInKey)
        )
    }

    private static func intProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    private static func boolProperty(_ device: IOHIDDevice, key: String) -> Bool {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.boolValue ?? false
    }
}

private func keyboardDevicesChanged(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let monitor = Unmanaged<KeyboardDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
    monitor.refreshDevices()
}
