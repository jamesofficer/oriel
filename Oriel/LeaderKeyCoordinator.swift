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

        do {
            try hotKey.register(
                keyCode: selection.leaderKey.keyCode,
                modifiers: selection.leaderKey.carbonModifiers,
                handler: handler
            )
            self.selection = selection
            activationError = nil
            isStarted = true
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

        do {
            try apply(resolvedSelection(overrides: overrides))
            store.add(override)
        } catch {
            activationError = error.localizedDescription
            throw error
        }
    }

    func removeOverride(_ override: KeyboardLeaderOverride) throws {
        let overrides = store.overrides.filter { $0.id != override.id }

        do {
            try apply(resolvedSelection(overrides: overrides))
            store.remove(override)
        } catch {
            activationError = error.localizedDescription
            throw error
        }
    }

    func moveOverride(at index: Int, by offset: Int) throws {
        let destinationIndex = index + offset
        guard store.overrides.indices.contains(index),
              store.overrides.indices.contains(destinationIndex) else { return }

        let original = store.overrides
        let destination = offset < 0 ? destinationIndex : destinationIndex + 1
        store.move(fromOffsets: IndexSet(integer: index), toOffset: destination)

        do {
            try apply(resolvedSelection())
        } catch {
            store.setOverrides(original)
            activationError = error.localizedDescription
            throw error
        }
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

    private func apply(_ candidate: LeaderKeySelection) throws {
        if candidate.leaderKey != selection.leaderKey {
            try hotKey.replace(
                keyCode: candidate.leaderKey.keyCode,
                modifiers: candidate.leaderKey.carbonModifiers
            )
        }

        selection = candidate
        activationError = nil
    }
}
