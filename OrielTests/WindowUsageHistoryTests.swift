//
//  WindowUsageHistoryTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class WindowUsageHistoryTests: XCTestCase {
    func testLaterUseIsMoreRecent() {
        var history = WindowUsageHistory<String>()

        history.record("a")
        history.record("b")
        history.record("a")

        XCTAssertGreaterThan(history.lastUsed("a")!, history.lastUsed("b")!)
        XCTAssertNil(history.lastUsed("c"))
    }

    func testDropsOldestWindowAboveLimit() {
        var history = WindowUsageHistory<String>(limit: 2)

        history.record("a")
        history.record("b")
        history.record("c")

        XCTAssertNil(history.lastUsed("a"))
        XCTAssertNotNil(history.lastUsed("b"))
        XCTAssertNotNil(history.lastUsed("c"))
    }
}
