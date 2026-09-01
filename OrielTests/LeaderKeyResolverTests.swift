//
//  LeaderKeyResolverTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class LeaderKeyResolverTests: XCTestCase {
    func testUsesDefaultWhenNoOverrideKeyboardIsConnected() {
        let defaultKey = LeaderKey(keyCode: 1, carbonModifiers: 2)
        let override = KeyboardLeaderOverride(
            keyboard: identity(locationID: 10),
            keyboardName: "External Keyboard",
            leaderKey: LeaderKey(keyCode: 3, carbonModifiers: 4)
        )

        let selection = LeaderKeyResolver.resolve(
            defaultKey: defaultKey,
            overrides: [override],
            connectedKeyboards: []
        )

        XCTAssertEqual(selection, .default(defaultKey))
    }

    func testSerialIdentitySurvivesLocationChanges() {
        let first = KeyboardIdentity(
            vendorID: 1,
            productID: 2,
            serialNumber: "serial",
            locationID: 10,
            transport: "USB"
        )
        let moved = KeyboardIdentity(
            vendorID: 1,
            productID: 2,
            serialNumber: "serial",
            locationID: 20,
            transport: "Bluetooth"
        )

        XCTAssertEqual(first, moved)
    }

    func testUsesFirstConnectedOverride() {
        let first = KeyboardLeaderOverride(
            keyboard: identity(locationID: 10),
            keyboardName: "First Keyboard",
            leaderKey: LeaderKey(keyCode: 3, carbonModifiers: 4)
        )
        let second = KeyboardLeaderOverride(
            keyboard: identity(locationID: 20),
            keyboardName: "Second Keyboard",
            leaderKey: LeaderKey(keyCode: 5, carbonModifiers: 6)
        )

        let selection = LeaderKeyResolver.resolve(
            defaultKey: LeaderKey(keyCode: 1, carbonModifiers: 2),
            overrides: [first, second],
            connectedKeyboards: [second.keyboard, first.keyboard]
        )

        XCTAssertEqual(selection, .override(first))
    }

    private func identity(locationID: Int) -> KeyboardIdentity {
        KeyboardIdentity(
            vendorID: 1,
            productID: 2,
            serialNumber: nil,
            locationID: locationID,
            transport: "USB"
        )
    }
}
