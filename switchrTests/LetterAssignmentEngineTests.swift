//
//  LetterAssignmentEngineTests.swift
//  switchrTests
//

import XCTest
@testable import Switchr

final class LetterAssignmentEngineTests: XCTestCase {
    func testCustomAndReservedLettersWinOverAutomaticAssignments() {
        var engine = LetterAssignmentEngine<String>()
        let windows = [
            LetterAssignmentWindow(id: "safari", bundleID: "safari", appName: "Safari"),
            LetterAssignmentWindow(id: "chrome", bundleID: "chrome", appName: "Chrome"),
        ]

        let result = engine.assign(
            windows: windows,
            customLetters: ["chrome": "c"],
            reservedLetters: ["s"],
            persistedLetters: [:]
        )

        XCTAssertEqual(result.assignments.map(\.letter), ["a", "c"])
        XCTAssertEqual(result.persistedLetters, ["safari": "a"])
    }

    func testWindowOrderAndLettersStayStableWhenInputOrderChanges() {
        var engine = LetterAssignmentEngine<String>()
        let first = LetterAssignmentWindow(id: "first", bundleID: "browser", appName: "Browser")
        let second = LetterAssignmentWindow(id: "second", bundleID: "browser", appName: "Browser")

        let initial = engine.assign(
            windows: [first, second],
            customLetters: [:],
            reservedLetters: [],
            persistedLetters: [:]
        )
        let repeated = engine.assign(
            windows: [second, first],
            customLetters: [:],
            reservedLetters: [],
            persistedLetters: initial.persistedLetters
        )

        XCTAssertEqual(repeated.assignments.map(\.id), ["first", "second"])
        XCTAssertEqual(repeated.assignments.map(\.letter), initial.assignments.map(\.letter))
    }

    func testResolvesConflictingPersistedLettersInInputOrder() {
        var engine = LetterAssignmentEngine<String>()
        let windows = [
            LetterAssignmentWindow(id: "alpha", bundleID: "alpha", appName: "Alpha"),
            LetterAssignmentWindow(id: "alpine", bundleID: "alpine", appName: "Alpine"),
        ]

        let result = engine.assign(
            windows: windows,
            customLetters: [:],
            reservedLetters: [],
            persistedLetters: ["alpha": "a", "alpine": "a"]
        )

        XCTAssertEqual(result.assignments.map(\.letter), ["a", "l"])
        XCTAssertEqual(result.persistedLetters, ["alpha": "a", "alpine": "l"])
    }
}
