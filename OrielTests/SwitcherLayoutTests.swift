//
//  SwitcherLayoutTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class SwitcherLayoutTests: XCTestCase {
    func testEmptyListHasNoHeight() {
        XCTAssertEqual(SwitcherLayout.listHeight(activeCount: 0, minimizedCount: 0, closedCount: 0), 0)
    }

    func testActiveRowsIncludeSpacing() {
        XCTAssertEqual(SwitcherLayout.listHeight(activeCount: 2, minimizedCount: 0, closedCount: 0), 100)
    }

    func testStateGroupsIncludeHeadersPaddingAndSpacing() {
        XCTAssertEqual(SwitcherLayout.listHeight(activeCount: 1, minimizedCount: 1, closedCount: 1), 216)
    }

    func testPanelUsesMinimumHeight() {
        XCTAssertEqual(
            SwitcherLayout.panelHeight(leftListHeight: 0, rightListHeight: 0, availableHeight: 760),
            SwitcherLayout.minimumPanelHeight
        )
    }

    func testPanelUsesTallestColumn() {
        let expectedHeight = SwitcherLayout.panelChromeHeight + 400
        XCTAssertEqual(
            SwitcherLayout.panelHeight(leftListHeight: 200, rightListHeight: 400, availableHeight: 760),
            expectedHeight
        )
    }

    func testPanelDoesNotExceedAvailableHeight() {
        XCTAssertEqual(
            SwitcherLayout.panelHeight(leftListHeight: 1_000, rightListHeight: 0, availableHeight: 600),
            600
        )
    }
}
