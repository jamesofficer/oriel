//
//  WindowPlacementTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

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

    private let laptop = CGRect(x: 0, y: 0, width: 1_200, height: 800)
    private let monitor = CGRect(x: 1_200, y: 0, width: 2_400, height: 1_200)
    private let window = CGRect(x: 100, y: 100, width: 600, height: 400)

    func testSideTargetsFillHalfOfTheScreen() {
        XCTAssertEqual(frame(.left), CGRect(x: 0, y: 0, width: 600, height: 800))
        XCTAssertEqual(frame(.right), CGRect(x: 600, y: 0, width: 600, height: 800))
        XCTAssertEqual(frame(.top), CGRect(x: 0, y: 0, width: 1_200, height: 400))
        XCTAssertEqual(frame(.bottom), CGRect(x: 0, y: 400, width: 1_200, height: 400))
    }

    func testRepeatedSideTargetCyclesThroughThirdsAndBackToHalf() {
        XCTAssertEqual(frame(.right, repeatCount: 1), CGRect(x: 800, y: 0, width: 400, height: 800))
        XCTAssertEqual(frame(.right, repeatCount: 2), CGRect(x: 400, y: 0, width: 800, height: 800))
        XCTAssertEqual(frame(.right, repeatCount: 3), frame(.right))
    }

    func testMaximizeFillsTheScreenThatHasTheWindow() {
        let onMonitor = CGRect(x: 1_500, y: 100, width: 600, height: 400)

        XCTAssertEqual(frame(.maximize, window: onMonitor), monitor)
    }

    func testCenterKeepsTheWindowSize() {
        XCTAssertEqual(frame(.center), CGRect(x: 300, y: 200, width: 600, height: 400))
    }

    func testNextAndPreviousDisplayGoLeftToRightAndWrap() {
        let onMonitor = CGRect(x: 1_500, y: 100, width: 600, height: 400)

        XCTAssertTrue(monitor.contains(frame(.nextDisplay)!))
        XCTAssertTrue(monitor.contains(frame(.previousDisplay)!))
        XCTAssertTrue(laptop.contains(frame(.nextDisplay, window: onMonitor)!))
    }

    func testDisplayTargetsKeepTheFrameWithOneDisplay() {
        let result = WindowPlacement.frame(for: .nextDisplay, repeatCount: 0, windowFrame: window, screens: [laptop])

        XCTAssertEqual(result?.frame, window)
    }

    func testKeepsAnOverhangingFrameInsideTheScreen() {
        let result = WindowPlacement.frame(CGRect(x: 800, y: 600, width: 700, height: 400), keptInside: laptop)

        XCTAssertEqual(result, CGRect(x: 500, y: 400, width: 700, height: 400))
    }

    private func frame(
        _ target: WindowPlacement.Target,
        repeatCount: Int = 0,
        window: CGRect? = nil
    ) -> CGRect? {
        WindowPlacement.frame(
            for: target,
            repeatCount: repeatCount,
            windowFrame: window ?? self.window,
            screens: [monitor, laptop]
        )?.frame
    }
}
