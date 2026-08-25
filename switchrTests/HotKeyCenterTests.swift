//
//  HotKeyCenterTests.swift
//  switchrTests
//

import Carbon.HIToolbox
import XCTest
@testable import Switchr

final class HotKeyCenterTests: XCTestCase {
    func testKeepsPreviousShortcutWhenReplacementIsInUse() throws {
        let system = FakeHotKeySystem()
        let center = HotKeyCenter(system: system)
        try center.register(keyCode: 1, modifiers: 2) {}
        system.nextRegistrationStatus = OSStatus(eventHotKeyExistsErr)

        XCTAssertThrowsError(try center.replace(keyCode: 3, modifiers: 4)) { error in
            XCTAssertEqual(error as? HotKeyRegistrationError, .shortcutInUse)
        }
        XCTAssertEqual(system.activeShortcut, Shortcut(keyCode: 1, modifiers: 2))
    }

    func testReplacesActiveShortcut() throws {
        let system = FakeHotKeySystem()
        let center = HotKeyCenter(system: system)
        try center.register(keyCode: 1, modifiers: 2) {}

        try center.replace(keyCode: 3, modifiers: 4)

        XCTAssertEqual(system.activeShortcut, Shortcut(keyCode: 3, modifiers: 4))
    }

    func testPauseAndResumeRestoreConfiguredShortcut() throws {
        let system = FakeHotKeySystem()
        let center = HotKeyCenter(system: system)
        try center.register(keyCode: 1, modifiers: 2) {}

        XCTAssertNoThrow(try center.pause().get())
        XCTAssertNil(system.activeShortcut)

        try center.resume()
        XCTAssertEqual(system.activeShortcut, Shortcut(keyCode: 1, modifiers: 2))
    }

    func testReportsInvalidShortcut() {
        let system = FakeHotKeySystem()
        system.nextRegistrationStatus = OSStatus(eventHotKeyInvalidErr)
        let center = HotKeyCenter(system: system)

        XCTAssertThrowsError(try center.register(keyCode: 1, modifiers: 2) {}) { error in
            XCTAssertEqual(error as? HotKeyRegistrationError, .invalidShortcut)
        }
        XCTAssertNil(system.activeShortcut)
    }

    func testCanReplaceShortcutAfterInitialRegistrationFails() throws {
        let system = FakeHotKeySystem()
        system.nextRegistrationStatus = OSStatus(eventHotKeyExistsErr)
        let center = HotKeyCenter(system: system)
        XCTAssertThrowsError(try center.register(keyCode: 1, modifiers: 2) {})

        try center.replace(keyCode: 3, modifiers: 4)

        XCTAssertEqual(system.activeShortcut, Shortcut(keyCode: 3, modifiers: 4))
    }
}

private final class FakeHotKeySystem: HotKeySystem {
    var activeShortcut: Shortcut?
    var nextRegistrationStatus: OSStatus = noErr

    func installHandler() -> OSStatus {
        noErr
    }

    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        defer { nextRegistrationStatus = noErr }
        guard nextRegistrationStatus == noErr else { return nextRegistrationStatus }
        activeShortcut = Shortcut(keyCode: keyCode, modifiers: modifiers)
        return noErr
    }

    func unregister() -> OSStatus {
        activeShortcut = nil
        return noErr
    }
}
