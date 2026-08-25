//
//  WindowPlacementTests.swift
//  switchrTests
//

import XCTest
@testable import Switchr

final class WindowPlacementTests: XCTestCase {
    func testPreservesBottomRightPlacementAcrossScreens() {
        let result = WindowPlacement.destinationFrame(
            windowFrame: CGRect(x: 800, y: 600, width: 200, height: 200),
            sourceFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            destinationFrame: CGRect(x: 1_000, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(result, CGRect(x: 1_300, y: 200, width: 200, height: 200))
    }

    func testPreservesProportionalPlacement() {
        let result = WindowPlacement.destinationFrame(
            windowFrame: CGRect(x: 400, y: 300, width: 200, height: 200),
            sourceFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            destinationFrame: CGRect(x: 1_000, y: 100, width: 600, height: 500)
        )

        XCTAssertEqual(result, CGRect(x: 1_200, y: 250, width: 200, height: 200))
    }

    func testClampsOversizedWindowToDestinationScreen() {
        let result = WindowPlacement.destinationFrame(
            windowFrame: CGRect(x: 0, y: 0, width: 1_200, height: 900),
            sourceFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
            destinationFrame: CGRect(x: 1_000, y: 100, width: 600, height: 500)
        )

        XCTAssertEqual(result, CGRect(x: 1_000, y: 100, width: 600, height: 500))
    }
}
