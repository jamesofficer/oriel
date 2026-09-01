//
//  KeyboardLeaderOverridesStoreTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class KeyboardLeaderOverridesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "KeyboardLeaderOverridesStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testPersistsOverridePriority() {
        let first = override(name: "First", locationID: 1)
        let second = override(name: "Second", locationID: 2)
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        store.add(first)
        store.add(second)
        store.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        let restored = KeyboardLeaderOverridesStore(defaults: defaults)

        XCTAssertEqual(restored.overrides, [second, first])
    }

    func testReplacesOverrideForSameKeyboard() {
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let first = override(name: "Keyboard", locationID: 1)
        let replacement = KeyboardLeaderOverride(
            keyboard: first.keyboard,
            keyboardName: "Renamed Keyboard",
            leaderKey: LeaderKey(keyCode: 9, carbonModifiers: 10)
        )

        store.add(first)
        store.add(replacement)

        XCTAssertEqual(store.overrides.count, 1)
        XCTAssertEqual(store.overrides.first?.keyboardName, "Renamed Keyboard")
        XCTAssertEqual(store.overrides.first?.leaderKey, replacement.leaderKey)
    }

    private func override(name: String, locationID: Int) -> KeyboardLeaderOverride {
        KeyboardLeaderOverride(
            keyboard: KeyboardIdentity(
                vendorID: 1,
                productID: 2,
                serialNumber: nil,
                locationID: locationID,
                transport: "USB"
            ),
            keyboardName: name,
            leaderKey: LeaderKey(keyCode: UInt32(locationID), carbonModifiers: 2)
        )
    }
}
