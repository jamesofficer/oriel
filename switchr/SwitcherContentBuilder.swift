//
//  SwitcherContentBuilder.swift
//  switchr
//

import Foundation

struct SwitcherItem<Value> {
    let value: Value
    let bundleID: String?
    let isMinimized: Bool
}

struct SwitcherContent<Value> {
    let activePinned: [Value]
    let minimizedPinned: [Value]
    let activeOther: [Value]
    let minimizedOther: [Value]
    let closedApps: [CustomBinding]

    var pinnedCount: Int {
        activePinned.count + minimizedPinned.count + closedApps.count
    }

    var otherCount: Int {
        activeOther.count + minimizedOther.count
    }
}

enum SwitcherContentBuilder {
    static func build<Value>(
        items: [SwitcherItem<Value>],
        bindings: [CustomBinding],
        showClosedApps: Bool
    ) -> SwitcherContent<Value> {
        let boundBundleIDs = Set(bindings.map(\.bundleID))
        var activePinned: [Value] = []
        var minimizedPinned: [Value] = []
        var activeOther: [Value] = []
        var minimizedOther: [Value] = []
        var openBundleIDs = Set<String>()

        for item in items {
            if let bundleID = item.bundleID {
                openBundleIDs.insert(bundleID)
            }
            let isPinned = item.bundleID.map(boundBundleIDs.contains) ?? false
            switch (isPinned, item.isMinimized) {
            case (true, false):
                activePinned.append(item.value)
            case (true, true):
                minimizedPinned.append(item.value)
            case (false, false):
                activeOther.append(item.value)
            case (false, true):
                minimizedOther.append(item.value)
            }
        }

        let closedApps = showClosedApps
            ? bindings.filter { !openBundleIDs.contains($0.bundleID) }
            : []
        return SwitcherContent(
            activePinned: activePinned,
            minimizedPinned: minimizedPinned,
            activeOther: activeOther,
            minimizedOther: minimizedOther,
            closedApps: closedApps
        )
    }
}
