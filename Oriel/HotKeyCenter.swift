//
//  HotKeyCenter.swift
//  Oriel
//

import AppKit
import Carbon.HIToolbox

struct Shortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
}

enum HotKeyRegistrationError: Error, Equatable, LocalizedError {
    case shortcutInUse
    case invalidShortcut
    case notConfigured
    case systemError(OSStatus)
    case restorationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .shortcutInUse:
            return "This shortcut is already in use. Choose a different shortcut."
        case .invalidShortcut:
            return "macOS cannot use this shortcut. Choose a different shortcut."
        case .notConfigured:
            return "The shortcut is not configured."
        case .systemError:
            return "Oriel could not register this shortcut."
        case .restorationFailed:
            return "Oriel could not restore the previous shortcut."
        }
    }

    static func from(_ status: OSStatus) -> HotKeyRegistrationError {
        switch status {
        case OSStatus(eventHotKeyExistsErr):
            return .shortcutInUse
        case OSStatus(eventHotKeyInvalidErr):
            return .invalidShortcut
        default:
            return .systemError(status)
        }
    }
}

protocol HotKeyControlling: AnyObject {
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws
    func replace(keyCode: UInt32, modifiers: UInt32) throws
    func pause() -> Result<Void, HotKeyRegistrationError>
    func resume() throws
}

protocol HotKeySystem: AnyObject {
    func installHandler() -> OSStatus
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus
    func unregister() -> OSStatus
}

final class HotKeyCenter: HotKeyControlling {
    static let shared = HotKeyCenter(system: CarbonHotKeySystem())

    private let system: HotKeySystem
    private var handler: (() -> Void)?
    private var shortcut: Shortcut?
    private var isActive = false
    private var isHandlerInstalled = false

    init(system: HotKeySystem) {
        self.system = system
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws {
        try installHandlerIfNeeded()
        self.handler = handler
        try replaceRegistration(with: Shortcut(keyCode: keyCode, modifiers: modifiers))
    }

    func replace(keyCode: UInt32, modifiers: UInt32) throws {
        guard handler != nil else { throw HotKeyRegistrationError.notConfigured }
        try replaceRegistration(with: Shortcut(keyCode: keyCode, modifiers: modifiers))
    }

    @discardableResult
    func pause() -> Result<Void, HotKeyRegistrationError> {
        guard isActive else { return .success(()) }
        let status = system.unregister()
        guard status == noErr else { return .failure(.from(status)) }
        isActive = false
        return .success(())
    }

    func resume() throws {
        guard !isActive else { return }
        guard let shortcut, handler != nil else { throw HotKeyRegistrationError.notConfigured }
        let status = system.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
        guard status == noErr else { throw HotKeyRegistrationError.from(status) }
        isActive = true
    }

    fileprivate func fire() {
        handler?()
    }

    private func installHandlerIfNeeded() throws {
        guard !isHandlerInstalled else { return }
        let status = system.installHandler()
        guard status == noErr else { throw HotKeyRegistrationError.from(status) }
        isHandlerInstalled = true
    }

    private func replaceRegistration(with candidate: Shortcut) throws {
        let previous = shortcut
        let wasActive = isActive

        if wasActive {
            let status = system.unregister()
            guard status == noErr else { throw HotKeyRegistrationError.from(status) }
            isActive = false
        }

        let status = system.register(keyCode: candidate.keyCode, modifiers: candidate.modifiers)
        guard status == noErr else {
            if wasActive, let previous {
                let restorationStatus = system.register(
                    keyCode: previous.keyCode,
                    modifiers: previous.modifiers
                )
                guard restorationStatus == noErr else {
                    throw HotKeyRegistrationError.restorationFailed(restorationStatus)
                }
                isActive = true
            }
            throw HotKeyRegistrationError.from(status)
        }

        shortcut = candidate
        isActive = true
    }
}

private final class CarbonHotKeySystem: HotKeySystem {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func installHandler() -> OSStatus {
        guard eventHandlerRef == nil else { return noErr }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        return InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }

    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: OSType(0x5357_4348), id: 1)
        return RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() -> OSStatus {
        guard let hotKeyRef else { return noErr }
        let status = UnregisterEventHotKey(hotKeyRef)
        if status == noErr {
            self.hotKeyRef = nil
        }
        return status
    }
}

private nonisolated func hotKeyEventCallback(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    MainActor.assumeIsolated {
        HotKeyCenter.shared.fire()
    }
    return noErr
}
