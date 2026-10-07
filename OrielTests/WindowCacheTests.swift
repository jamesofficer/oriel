//
//  WindowCacheTests.swift
//  OrielTests
//

import AppKit
import XCTest
@testable import Oriel

final class WindowCacheTests: XCTestCase {
    func testRefreshStoresListedWindows() {
        let windows = [window()]
        let cache = WindowCache { windows }
        let changed = expectation(description: "changed")
        cache.onChange = { changed.fulfill() }

        cache.refresh()

        wait(for: [changed], timeout: 2)
        XCTAssertEqual(cache.windows?.count, 1)
    }

    func testRefreshDuringListingRunsOneMoreListing() {
        let lister = BlockingLister()
        let cache = WindowCache { lister.list() }
        let changed = expectation(description: "changed")
        changed.expectedFulfillmentCount = 2
        cache.onChange = { changed.fulfill() }

        cache.refresh()
        cache.refresh()
        cache.refresh()
        lister.release()

        wait(for: [changed], timeout: 2)
        XCTAssertEqual(lister.callCount, 2)
    }

    private func window() -> WindowInfo {
        WindowInfo(
            app: .current,
            axWindow: AXUIElementCreateApplication(getpid()),
            title: "",
            isMinimized: false
        )
    }
}

private final class BlockingLister: @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var calls = 0

    var callCount: Int {
        lock.withLock { calls }
    }

    func list() -> [WindowInfo] {
        let isFirstCall = lock.withLock {
            calls += 1
            return calls == 1
        }

        if isFirstCall {
            gate.wait()
        }

        return []
    }

    func release() {
        gate.signal()
    }
}
