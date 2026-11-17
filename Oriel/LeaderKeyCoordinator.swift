//
//  LeaderKeyCoordinator.swift
//  Oriel
//

import Combine
import Foundation

final class LeaderKeyCoordinator: ObservableObject {
    @Published private(set) var selection: LeaderKeySelection
    @Published private(set) var activationError: String?

    private let hotKey: HotKeyControlling
    private let store: KeyboardLeaderOverridesStore
    private let defaults: UserDefaults
    private var connectedKeyboards = Set<KeyboardIdentity>()
    private var isStarted = false
    // Nil until a registration succeeds. The selection alone does
    // not show this, as a registration can fail at startup.
    private var registeredKey: LeaderKey?

    init(
        hotKey: HotKeyControlling = HotKeyCenter.shared,
        store: KeyboardLeaderOverridesStore = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.hotKey = hotKey
        self.store = store
        self.defaults = defaults
        selection = .default(AppPreferences.leaderKey(in: defaults))
    }

    func start(handler: @escaping () -> Void) throws {
        let selection = resolvedSelection()
        isStarted = true

        do {
            try hotKey.register(
                keyCode: selection.leaderKey.keyCode,
                modifiers: selection.leaderKey.carbonModifiers,
                handler: handler
            )
            registeredKey = selection.leaderKey
            self.selection = selection
            activationError = nil
        } catch {
            activationError = error.localizedDescription
            throw error
        }
    }

    func updateConnectedKeyboards(_ keyboards: [KeyboardDevice]) {
        connectedKeyboards = Set(keyboards.map(\.identity))
        guard isStarted else {
            selection = resolvedSelection()
            return
        }

        do {
            try apply(resolvedSelection())
        } catch {
            activationError = error.localizedDescription
        }
    }

    func setDefaultLeader(_ leaderKey: LeaderKey) throws {
        do {
            try apply(resolvedSelection(defaultKey: leaderKey))
            AppPreferences.setLeaderKey(leaderKey, in: defaults)
        } catch {
            activationError = error.localizedDescription
            throw error
        }
    }

    func addOverride(_ override: KeyboardLeaderOverride) throws {
        var overrides = store.overrides

        if let index = overrides.firstIndex(where: { $0.keyboard == override.keyboard }) {
            overrides[index] = override
        } else {
            overrides.append(override)
        }

        try setOverrides(overrides)
    }

    func removeOverride(_ override: KeyboardLeaderOverride) throws {
        try setOverrides(store.overrides.filter { $0.id != override.id })
    }

    func moveOverride(at index: Int, by offset: Int) throws {
        var overrides = store.overrides
        let destination = index + offset
        guard overrides.indices.contains(index), overrides.indices.contains(destination) else { return }

        overrides.insert(overrides.remove(at: index), at: destination)
        try setOverrides(overrides)
    }

    func pause() -> Result<Void, HotKeyRegistrationError> {
        hotKey.pause()
    }

    func resume() throws {
        try hotKey.resume()
    }

    private func resolvedSelection(
        defaultKey: LeaderKey? = nil,
        overrides: [KeyboardLeaderOverride]? = nil
    ) -> LeaderKeySelection {
        LeaderKeyResolver.resolve(
            defaultKey: defaultKey ?? AppPreferences.leaderKey(in: defaults),
            overrides: overrides ?? store.overrides,
            connectedKeyboards: connectedKeyboards
        )
    }

    /// The list is saved only after its leader key registers, so
    /// a list that cannot become active is never stored.
    private func setOverrides(_ overrides: [KeyboardLeaderOverride]) throws {
        do {
            try apply(resolvedSelection(overrides: overrides))
            store.setOverrides(overrides)
        } catch {
            activationError = error.localizedDescription
            throw error
        }
    }

    private func apply(_ candidate: LeaderKeySelection) throws {
        if candidate.leaderKey != registeredKey {
            try hotKey.replace(
                keyCode: candidate.leaderKey.keyCode,
                modifiers: candidate.leaderKey.carbonModifiers
            )
            registeredKey = candidate.leaderKey
        }

        selection = candidate
        activationError = nil
    }
}
