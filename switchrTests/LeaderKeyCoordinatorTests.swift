//
//  LeaderKeyCoordinatorTests.swift
//  switchrTests
//

import XCTest
@testable import Switchr

final class LeaderKeyCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LeaderKeyCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testActivatesOverrideWhenKeyboardConnects() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let override = keyboardOverride()
        store.add(override)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}

        coordinator.updateConnectedKeyboards([device(for: override)])

        XCTAssertEqual(coordinator.selection, .override(override))
        XCTAssertEqual(hotKey.activeKey, override.leaderKey)
    }

    func testKeepsCurrentLeaderWhenConnectedOverrideCannotRegister() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let override = keyboardOverride()
        store.add(override)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        let defaultSelection = coordinator.selection
        hotKey.replacementError = .shortcutInUse

        coordinator.updateConnectedKeyboards([device(for: override)])

        XCTAssertEqual(coordinator.selection, defaultSelection)
        XCTAssertEqual(coordinator.activationError, HotKeyRegistrationError.shortcutInUse.localizedDescription)
    }

    func testChangesAndPersistsDefaultLeader() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        let newDefault = LeaderKey(keyCode: 7, carbonModifiers: 8)

        try coordinator.setDefaultLeader(newDefault)

        XCTAssertEqual(coordinator.selection, .default(newDefault))
        XCTAssertEqual(hotKey.activeKey, newDefault)
        XCTAssertEqual(AppPreferences.leaderKey(in: defaults), newDefault)
    }

    func testAddingConnectedOverrideActivatesAndPersistsIt() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        let override = keyboardOverride()
        coordinator.updateConnectedKeyboards([device(for: override)])

        try coordinator.addOverride(override)

        XCTAssertEqual(coordinator.selection, .override(override))
        XCTAssertEqual(hotKey.activeKey, override.leaderKey)
        XCTAssertEqual(store.overrides, [override])
    }

    func testReturnsToDefaultWhenOverrideKeyboardDisconnects() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let override = keyboardOverride()
        store.add(override)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        coordinator.updateConnectedKeyboards([device(for: override)])

        coordinator.updateConnectedKeyboards([])

        XCTAssertEqual(coordinator.selection, .default(AppPreferences.leaderKey(in: defaults)))
        XCTAssertEqual(hotKey.activeKey, AppPreferences.leaderKey(in: defaults))
    }

    func testDoesNotPersistDefaultWhenRegistrationFails() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        let previousDefault = AppPreferences.leaderKey(in: defaults)
        hotKey.replacementError = .shortcutInUse

        XCTAssertThrowsError(
            try coordinator.setDefaultLeader(LeaderKey(keyCode: 7, carbonModifiers: 8))
        )
        XCTAssertEqual(AppPreferences.leaderKey(in: defaults), previousDefault)
        XCTAssertEqual(coordinator.selection, .default(previousDefault))
    }

    func testDoesNotPersistConnectedOverrideWhenRegistrationFails() throws {
        let hotKey = FakeHotKeyController()
        let store = KeyboardLeaderOverridesStore(defaults: defaults)
        let coordinator = LeaderKeyCoordinator(hotKey: hotKey, store: store, defaults: defaults)
        try coordinator.start {}
        let override = keyboardOverride()
        coordinator.updateConnectedKeyboards([device(for: override)])
        hotKey.replacementError = .shortcutInUse

        XCTAssertThrowsError(try coordinator.addOverride(override))
        XCTAssertTrue(store.overrides.isEmpty)
    }

    private func keyboardOverride() -> KeyboardLeaderOverride {
        KeyboardLeaderOverride(
            keyboard: KeyboardIdentity(
                vendorID: 1,
                productID: 2,
                serialNumber: "serial",
                locationID: 10,
                transport: "USB"
            ),
            keyboardName: "External Keyboard",
            leaderKey: LeaderKey(keyCode: 3, carbonModifiers: 4)
        )
    }

    private func device(for override: KeyboardLeaderOverride) -> KeyboardDevice {
        KeyboardDevice(identity: override.keyboard, name: override.keyboardName, isBuiltIn: false)
    }
}

private final class FakeHotKeyController: HotKeyControlling {
    var activeKey: LeaderKey?
    var replacementError: HotKeyRegistrationError?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws {
        activeKey = LeaderKey(keyCode: keyCode, carbonModifiers: modifiers)
    }

    func replace(keyCode: UInt32, modifiers: UInt32) throws {
        if let replacementError { throw replacementError }
        activeKey = LeaderKey(keyCode: keyCode, carbonModifiers: modifiers)
    }

    func pause() -> Result<Void, HotKeyRegistrationError> {
        .success(())
    }

    func resume() throws {}
}
