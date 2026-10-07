//
//  WindowSearchTests.swift
//  OrielTests
//

import XCTest
@testable import Oriel

final class WindowSearchTests: XCTestCase {
    func testOrdersByMatchQuality() {
        let candidates = [
            candidate("letters", app: "Visual Studio"),
            candidate("substring", app: "Discord"),
            candidate("word", app: "Notes", title: "Code review"),
            candidate("prefix", app: "Code Runner"),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "co"), ["prefix", "word", "substring"])
        XCTAssertEqual(WindowSearch.rank(candidates, query: "vs"), ["letters"])
    }

    func testDropsWindowsThatDoNotMatch() {
        let candidates = [candidate("chrome", app: "Google Chrome"), candidate("slack", app: "Slack")]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "chr"), ["chrome"])
        XCTAssertEqual(WindowSearch.rank(candidates, query: "zzz"), [])
    }

    func testIgnoresCaseAccentsAndOuterSpaces() {
        let candidates = [candidate("cafe", app: "Café Notes")]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "  CAFE "), ["cafe"])
    }

    func testMatchesQueriesWithSpacesAtWordStart() {
        let candidates = [
            candidate("inside", app: "Notes", title: "my studio code"),
            candidate("code", app: "Visual Studio Code"),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "studio co"), ["inside", "code"])
    }

    func testEqualMatchesPutUnpinnedBeforePinnedBeforeClosed() {
        let candidates = [
            candidate("closed", app: "Chat Closed", group: .closed),
            candidate("pinned", app: "Chat Pinned", group: .pinned),
            candidate("other", app: "Chat Other"),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "chat"), ["other", "pinned", "closed"])
    }

    func testBetterMatchWinsOverGroup() {
        let candidates = [
            candidate("other", app: "Notes", title: "Chrome tips"),
            candidate("pinned", app: "Chrome", group: .pinned),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "chrome"), ["pinned", "other"])
    }

    func testEqualMatchesPutRecentFirstThenKeepInputOrder() {
        let candidates = [
            candidate("never", app: "Chrome"),
            candidate("old", app: "Chrome", lastUsed: 1),
            candidate("new", app: "Chrome", lastUsed: 5),
            candidate("alsoNever", app: "Chrome"),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: "ch"), ["new", "old", "never", "alsoNever"])
    }

    func testEmptyQueryKeepsAllWindows() {
        let candidates = [
            candidate("pinned", app: "Slack", group: .pinned),
            candidate("other", app: "Arc"),
        ]

        XCTAssertEqual(WindowSearch.rank(candidates, query: " "), ["other", "pinned"])
    }

    func testDeletingLastWord() {
        XCTAssertEqual(SearchText.deletingLastWord("visual studio"), "visual ")
        XCTAssertEqual(SearchText.deletingLastWord("visual studio  "), "visual ")
        XCTAssertEqual(SearchText.deletingLastWord("visual"), "")
        XCTAssertEqual(SearchText.deletingLastWord(""), "")
    }

    func testTypedTextKeepsCharactersAndDropsControlKeys() {
        XCTAssertEqual(SearchText.typedText("a"), "a")
        XCTAssertEqual(SearchText.typedText(" "), " ")
        XCTAssertEqual(SearchText.typedText("é"), "é")
        XCTAssertNil(SearchText.typedText(nil))
        XCTAssertNil(SearchText.typedText("\t"))
        XCTAssertNil(SearchText.typedText("\u{F700}"))
    }

    private func candidate(
        _ id: String,
        app: String,
        title: String = "",
        group: WindowSearchGroup = .other,
        lastUsed: Int? = nil
    ) -> WindowSearchCandidate<String> {
        WindowSearchCandidate(id: id, appName: app, title: title, group: group, lastUsed: lastUsed)
    }
}
