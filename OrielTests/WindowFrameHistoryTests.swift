//
//  WindowFrameHistoryTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class WindowFrameHistoryTests: XCTestCase {
    private let first = CGRect(x: 10, y: 10, width: 400, height: 300)
    private let second = CGRect(x: 0, y: 0, width: 600, height: 800)

    func testUndoesMovesFromLastToFirst() {
        var history = WindowFrameHistory<String>()

        history.record(first, for: "a")
        history.record(second, for: "a")

        XCTAssertEqual(history.removeLastFrame(for: "a"), second)
        XCTAssertEqual(history.removeLastFrame(for: "a"), first)
        XCTAssertNil(history.removeLastFrame(for: "a"))
    }

    func testHasNothingToUndoForAWindowThatDidNotMove() {
        var history = WindowFrameHistory<String>()

        history.record(first, for: "a")

        XCTAssertNil(history.removeLastFrame(for: "b"))
        XCTAssertEqual(history.removeLastFrame(for: "a"), first)
    }

    func testMoveOfADifferentWindowDropsTheOlderMoves() {
        var history = WindowFrameHistory<String>()

        history.record(first, for: "a")
        history.record(second, for: "b")

        XCTAssertNil(history.removeLastFrame(for: "a"))
        XCTAssertEqual(history.removeLastFrame(for: "b"), second)
    }
}
