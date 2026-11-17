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

    func setOverrides(_ overrides: [KeyboardLeaderOverride]) {
        self.overrides = overrides
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(overrides) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
