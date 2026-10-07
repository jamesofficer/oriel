//
//  LeaderPressTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class LeaderPressTests: XCTestCase {
    func testFirstPressShowsPanel() {
        XCTAssertEqual(action(isPanelOpen: false, seconds: 0), .show)
    }

    func testQuickSecondPressStartsSearch() {
        XCTAssertEqual(action(seconds: 0.1), .search)
        XCTAssertEqual(action(seconds: LeaderPress.doublePressInterval), .search)
    }

    func testSlowSecondPressHidesPanel() {
        XCTAssertEqual(action(seconds: LeaderPress.doublePressInterval + 0.01), .hide)
    }

    func testThirdPressHidesPanel() {
        XCTAssertEqual(action(isSearching: true, seconds: 0.1), .hide)
    }

    func testQuickSecondPressHidesPanelWhenSearchIsOff() {
        XCTAssertEqual(action(isSearchEnabled: false, seconds: 0.1), .hide)
    }

    private func action(
        isPanelOpen: Bool = true,
        isSearching: Bool = false,
        isSearchEnabled: Bool = true,
        seconds: TimeInterval
    ) -> LeaderPressAction {
        LeaderPress.action(
            isPanelOpen: isPanelOpen,
            isSearching: isSearching,
            isSearchEnabled: isSearchEnabled,
            secondsSincePanelOpened: seconds
        )
    }
}
