//
//  CustomBindingsStoreTests.swift
//  switchrTests
//

import XCTest
@testable import Switchr

final class CustomBindingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CustomBindingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRejectsKeyUsedByAnotherApp() throws {
        let store = CustomBindingsStore(defaults: defaults)
        try store.add(binding(bundleID: "com.example.one", key: "a"))

        XCTAssertThrowsError(try store.add(binding(bundleID: "com.example.two", key: "a"))) { error in
            XCTAssertEqual(error as? CustomBindingError, .keyInUse(appName: "App com.example.one"))
        }
        XCTAssertEqual(store.bindings.map(\.bundleID), ["com.example.one"])
    }

    func testRejectsInvalidKey() {
        let store = CustomBindingsStore(defaults: defaults)

        XCTAssertThrowsError(try store.add(binding(bundleID: "com.example.one", key: "ab"))) { error in
            XCTAssertEqual(error as? CustomBindingError, .invalidKey)
        }
        XCTAssertTrue(store.bindings.isEmpty)
    }

    func testNormalizesKeyAndReplacesBindingForSameApp() throws {
        let store = CustomBindingsStore(defaults: defaults)
        try store.add(binding(bundleID: "com.example.one", key: "A"))
        try store.add(binding(bundleID: "com.example.one", key: "b"))

        XCTAssertEqual(store.bindings.count, 1)
        XCTAssertEqual(store.bindings.first?.key, "b")
    }

    func testCleansInvalidAndDuplicateSavedBindings() throws {
        let saved = [
            binding(bundleID: "com.example.one", key: "A"),
            binding(bundleID: "com.example.two", key: "a"),
            binding(bundleID: "com.example.three", key: "invalid"),
            binding(bundleID: "com.example.one", key: "z"),
        ]
        defaults.set(try JSONEncoder().encode(saved), forKey: CustomBindingsStore.defaultsKey)

        let store = CustomBindingsStore(defaults: defaults)

        XCTAssertEqual(store.bindings.map(\.bundleID), ["com.example.one"])
        XCTAssertEqual(store.bindings.map(\.key), ["a"])
        let storedData = try XCTUnwrap(defaults.data(forKey: CustomBindingsStore.defaultsKey))
        XCTAssertEqual(try JSONDecoder().decode([CustomBinding].self, from: storedData), store.bindings)
    }

    private func binding(bundleID: String, key: String) -> CustomBinding {
        CustomBinding(
            bundleID: bundleID,
            appName: "App \(bundleID)",
            appPath: "/Applications/Example.app",
            key: key
        )
    }
}
