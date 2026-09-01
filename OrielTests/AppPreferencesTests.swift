//
//  AppPreferencesTests.swift
//  OrielTests
//

import Carbon.HIToolbox
import XCTest
@testable import Oriel

final class AppPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultLeaderIsCommandSemicolon() {
        XCTAssertEqual(LeaderKey.default.keyCode, UInt32(kVK_ANSI_Semicolon))
        XCTAssertEqual(LeaderKey.default.carbonModifiers, UInt32(cmdKey))
    }

    func testUsesDefaultsWhenValuesAreMissing() {
        XCTAssertEqual(AppPreferences.revealDelayMilliseconds(in: defaults), 100)
        XCTAssertEqual(AppPreferences.panelOpacity(in: defaults), 0.9)
        XCTAssertTrue(AppPreferences.animatePanel(in: defaults))
        XCTAssertTrue(AppPreferences.showClosedApps(in: defaults))
        XCTAssertFalse(AppPreferences.bringToCurrentScreen(in: defaults))
        XCTAssertFalse(AppPreferences.maximizeOnFocus(in: defaults))
        XCTAssertEqual(AppPreferences.leaderKey(in: defaults).keyCode, LeaderKey.default.keyCode)
        XCTAssertEqual(AppPreferences.leaderKey(in: defaults).carbonModifiers, LeaderKey.default.carbonModifiers)
    }

    func testClampsRevealDelay() {
        defaults.set(-1, forKey: AppPreferences.Key.revealDelayMilliseconds)
        XCTAssertEqual(AppPreferences.revealDelayMilliseconds(in: defaults), 0)

        defaults.set(1_001, forKey: AppPreferences.Key.revealDelayMilliseconds)
        XCTAssertEqual(AppPreferences.revealDelayMilliseconds(in: defaults), 1_000)
    }

    func testClampsPanelOpacity() {
        defaults.set(0.5, forKey: AppPreferences.Key.panelOpacity)
        XCTAssertEqual(AppPreferences.panelOpacity(in: defaults), 0.8)

        defaults.set(1.5, forKey: AppPreferences.Key.panelOpacity)
        XCTAssertEqual(AppPreferences.panelOpacity(in: defaults), 1.0)
    }

    func testReadsStoredLeaderKey() {
        defaults.set(42, forKey: AppPreferences.Key.leaderKeyCode)
        defaults.set(256, forKey: AppPreferences.Key.leaderKeyModifiers)

        let leaderKey = AppPreferences.leaderKey(in: defaults)
        XCTAssertEqual(leaderKey.keyCode, 42)
        XCTAssertEqual(leaderKey.carbonModifiers, 256)
    }
}
