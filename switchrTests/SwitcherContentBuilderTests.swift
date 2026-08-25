//
//  SwitcherContentBuilderTests.swift
//  switchrTests
//

import XCTest
@testable import Switchr

final class SwitcherContentBuilderTests: XCTestCase {
    func testBuildsPinnedOtherMinimizedAndClosedGroups() {
        let items = [
            SwitcherItem(value: "pinned active", bundleID: "pinned", isMinimized: false),
            SwitcherItem(value: "pinned minimized", bundleID: "pinned", isMinimized: true),
            SwitcherItem(value: "other active", bundleID: "other", isMinimized: false),
            SwitcherItem(value: "other minimized", bundleID: nil, isMinimized: true),
        ]
        let bindings = [
            binding(bundleID: "pinned", key: "p"),
            binding(bundleID: "closed", key: "c"),
        ]

        let content = SwitcherContentBuilder.build(items: items, bindings: bindings, showClosedApps: true)

        XCTAssertEqual(content.activePinned, ["pinned active"])
        XCTAssertEqual(content.minimizedPinned, ["pinned minimized"])
        XCTAssertEqual(content.activeOther, ["other active"])
        XCTAssertEqual(content.minimizedOther, ["other minimized"])
        XCTAssertEqual(content.closedApps.map(\.bundleID), ["closed"])
    }

    func testOmitsClosedAppsWhenSettingIsDisabled() {
        let content = SwitcherContentBuilder.build(
            items: [SwitcherItem(value: "open", bundleID: "open", isMinimized: false)],
            bindings: [binding(bundleID: "closed", key: "c")],
            showClosedApps: false
        )

        XCTAssertTrue(content.closedApps.isEmpty)
    }

    private func binding(bundleID: String, key: String) -> CustomBinding {
        CustomBinding(bundleID: bundleID, appName: bundleID, appPath: "/\(bundleID).app", key: key)
    }
}
