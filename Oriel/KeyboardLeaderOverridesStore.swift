//
//  KeyboardLeaderOverridesStore.swift
//  Oriel
//

import Combine
import Foundation

final class KeyboardLeaderOverridesStore: ObservableObject {
    static let shared = KeyboardLeaderOverridesStore()
    static let defaultsKey = "keyboardLeaderOverrides"

    @Published private(set) var overrides: [KeyboardLeaderOverride]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([KeyboardLeaderOverride].self, from: data) {
            overrides = decoded
        } else {
            overrides = []
        }
    }

    func add(_ override: KeyboardLeaderOverride) {
        if let index = overrides.firstIndex(where: { $0.keyboard == override.keyboard }) {
            overrides[index] = override
        } else {
            overrides.append(override)
        }
        save()
    }

    func remove(_ override: KeyboardLeaderOverride) {
        overrides.removeAll { $0.id == override.id }
        save()
    }

    func setOverrides(_ overrides: [KeyboardLeaderOverride]) {
        self.overrides = overrides
        save()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let moving = offsets.sorted().map { overrides[$0] }
        let remaining = overrides.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)
        let removedBeforeDestination = offsets.filter { $0 < destination }.count
        let insertionIndex = min(max(0, destination - removedBeforeDestination), remaining.count)
        overrides = remaining
        overrides.insert(contentsOf: moving, at: insertionIndex)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
