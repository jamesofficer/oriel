//
//  ShortcutCaptureTests.swift
//  OrielTests
//

import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Oriel

final class ShortcutCaptureTests: XCTestCase {
    func testKeyWithoutControlOptionOrCommandIsInvalid() {
        XCTAssertEqual(capture(kVK_ANSI_A, []), .invalid)
        XCTAssertEqual(capture(kVK_ANSI_A, .shift), .invalid)
    }

    func testEscapeAloneCancels() {
        XCTAssertEqual(capture(kVK_Escape, []), .cancelled)
    }

    func testKeyWithCommandIsShortcut() {
        XCTAssertEqual(
            capture(kVK_ANSI_A, [.command, .shift]),
            .shortcut(LeaderKey(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: UInt32(cmdKey | shiftKey)))
        )
        XCTAssertEqual(
            capture(kVK_Escape, .command),
            .shortcut(LeaderKey(keyCode: UInt32(kVK_Escape), carbonModifiers: UInt32(cmdKey)))
        )
    }

    private func capture(_ keyCode: Int, _ modifierFlags: NSEvent.ModifierFlags) -> ShortcutCapture {
        ShortcutCapture.from(keyCode: UInt16(keyCode), modifierFlags: modifierFlags)
    }
}
