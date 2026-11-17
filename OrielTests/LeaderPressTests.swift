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

    func testQuickSecondPressStartsWindowActions() {
        XCTAssertEqual(action(seconds: 0.1), .windowActions)
        XCTAssertEqual(action(seconds: LeaderPress.doublePressInterval), .windowActions)
    }

    func testSlowSecondPressHidesPanel() {
        XCTAssertEqual(action(seconds: LeaderPress.doublePressInterval + 0.01), .hide)
    }

    func testQuickPressHidesPanelThatDoesNotShowLetters() {
        XCTAssertEqual(action(isShowingLetters: false, seconds: 0.1), .hide)
    }

    func testQuickSecondPressHidesPanelWhenWindowActionsAreOff() {
        XCTAssertEqual(action(isWindowActionsEnabled: false, seconds: 0.1), .hide)
    }

    private func action(
        isPanelOpen: Bool = true,
        isShowingLetters: Bool = true,
        isWindowActionsEnabled: Bool = true,
        seconds: TimeInterval
    ) -> LeaderPressAction {
        LeaderPress.action(
            isPanelOpen: isPanelOpen,
            isShowingLetters: isShowingLetters,
            isWindowActionsEnabled: isWindowActionsEnabled,
            secondsSincePanelOpened: seconds
        )
    }
}
