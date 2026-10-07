//
//  WindowUsageHistory.swift
//  Oriel
//
//  Remembers which windows were switched to most recently. It is
//  kept in memory only, so it starts again when Oriel restarts.
//

import Foundation

struct WindowUsageHistory<ID: Hashable> {
    private var stamps: [ID: Int] = [:]
    private var counter = 0
    private let limit: Int

    init(limit: Int = 200) {
        self.limit = limit
    }

    mutating func record(_ id: ID) {
        counter += 1
        stamps[id] = counter

        if stamps.count > limit, let oldest = stamps.min(by: { $0.value < $1.value })?.key {
            stamps[oldest] = nil
        }
    }

    /// A higher value means more recent. Nil means never used.
    func lastUsed(_ id: ID) -> Int? {
        stamps[id]
    }
}
