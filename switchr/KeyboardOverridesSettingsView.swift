//
//  KeyboardOverridesSettingsView.swift
//  switchr
//

import AppKit
import SwiftUI

struct KeyboardOverridesSettingsView: View {
    @ObservedObject var keyboardMonitor: KeyboardDeviceMonitor
    @ObservedObject var store: KeyboardLeaderOverridesStore
    @ObservedObject var coordinator: LeaderKeyCoordinator
    @State private var pendingOverride: KeyboardOverrideDraft?
    @State private var actionError: String?

    private var availableKeyboards: [KeyboardDevice] {
        keyboardMonitor.connectedKeyboards.filter { device in
            !device.isBuiltIn && !store.overrides.contains { $0.keyboard == device.identity }
        }
    }

    private var activeOverrideID: UUID? {
        guard case let .override(override) = coordinator.selection else { return nil }
        return override.id
    }

    var body: some View {
        Section("Keyboard Overrides") {
            if store.overrides.isEmpty {
                Text("No keyboard overrides. The default leader key is used for every keyboard.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(store.overrides.enumerated()), id: \.element.id) { index, override in
                overrideRow(override, at: index)
            }

            Menu {
                ForEach(availableKeyboards) { keyboard in
                    Button(keyboard.name) {
                        pendingOverride = KeyboardOverrideDraft(keyboard: keyboard, existingOverride: nil)
                    }
                }
            } label: {
                Label("Add Keyboard Override…", systemImage: "plus")
            }
            .disabled(availableKeyboards.isEmpty)

            if keyboardMonitor.connectedKeyboards.allSatisfy(\.isBuiltIn) {
                Text("Connect an external keyboard to add an override.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else if availableKeyboards.isEmpty {
                Text("All connected external keyboards have overrides.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("The first connected override in this list becomes active. The default returns when no override keyboard is connected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let error = actionError ?? coordinator.activationError ?? keyboardMonitor.monitoringError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .sheet(item: $pendingOverride) { draft in
            KeyboardOverrideSheet(
                keyboard: draft.keyboard,
                existingOverride: draft.existingOverride,
                coordinator: coordinator
            )
        }
    }

    private func overrideRow(_ override: KeyboardLeaderOverride, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(override.keyboardName)
                    Text(statusText(for: override))
                        .font(.callout)
                        .foregroundStyle(activeOverrideID == override.id ? .green : .secondary)
                }
                Spacer()
                Text(override.leaderKey.displayString)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                Button {
                    editOverride(override)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit override")
                Button {
                    moveOverride(at: index, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .help("Move override up")
                Button {
                    moveOverride(at: index, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(index == store.overrides.count - 1)
                .help("Move override down")
                Button {
                    removeOverride(override)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove override")
            }
        }
    }

    private func statusText(for override: KeyboardLeaderOverride) -> String {
        if activeOverrideID == override.id { return "Active" }
        let isConnected = keyboardMonitor.connectedKeyboards.contains { $0.identity == override.keyboard }
        return isConnected ? "Connected" : "Disconnected"
    }

    private func editOverride(_ override: KeyboardLeaderOverride) {
        let isBuiltIn = keyboardMonitor.connectedKeyboards
            .first { $0.identity == override.keyboard }?.isBuiltIn ?? false
        pendingOverride = KeyboardOverrideDraft(
            keyboard: KeyboardDevice(
                identity: override.keyboard,
                name: override.keyboardName,
                isBuiltIn: isBuiltIn
            ),
            existingOverride: override
        )
    }

    private func moveOverride(at index: Int, by offset: Int) {
        do {
            try coordinator.moveOverride(at: index, by: offset)
            actionError = nil
        } catch {
            actionError = error.localizedDescription
            NSSound.beep()
        }
    }

    private func removeOverride(_ override: KeyboardLeaderOverride) {
        do {
            try coordinator.removeOverride(override)
            actionError = nil
        } catch {
            actionError = error.localizedDescription
            NSSound.beep()
        }
    }
}

