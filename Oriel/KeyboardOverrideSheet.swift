//
//  KeyboardOverrideSheet.swift
//  Oriel
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct KeyboardOverrideDraft: Identifiable {
    let keyboard: KeyboardDevice
    let existingOverride: KeyboardLeaderOverride?

    var id: KeyboardIdentity { keyboard.identity }
}

struct KeyboardOverrideSheet: View {
    let keyboard: KeyboardDevice
    let existingOverride: KeyboardLeaderOverride?
    @ObservedObject var coordinator: LeaderKeyCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var leaderKey: LeaderKey?
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var errorMessage: String?

    init(
        keyboard: KeyboardDevice,
        existingOverride: KeyboardLeaderOverride?,
        coordinator: LeaderKeyCoordinator
    ) {
        self.keyboard = keyboard
        self.existingOverride = existingOverride
        self.coordinator = coordinator
        _leaderKey = State(initialValue: existingOverride?.leaderKey)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(keyboard.name)
                .font(.headline)

            Text(leaderKey?.displayString ?? "No shortcut recorded")
                .font(.system(.title3, design: .monospaced).weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))

            Text(isRecording
                 ? "Press a key combination including ⌃, ⌥ or ⌘. Esc cancels."
                 : "Record the leader key to use while this keyboard is connected.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(isRecording ? "Cancel Recording" : "Record Shortcut") {
                    isRecording ? stopRecording() : startRecording()
                }
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(existingOverride == nil ? "Add Override" : "Save Override") {
                    saveOverride()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(leaderKey == nil || isRecording)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        errorMessage = nil
        if case let .failure(error) = coordinator.pause() {
            errorMessage = error.localizedDescription
            NSSound.beep()
            return
        }
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            capture(event)
        }
    }

    private func stopRecording() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        guard isRecording else { return }
        isRecording = false
        do {
            try coordinator.resume()
        } catch {
            errorMessage = error.localizedDescription
            NSSound.beep()
        }
    }

    private func capture(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape),
           event.modifierFlags.intersection([.control, .option, .command]).isEmpty {
            stopRecording()
            return nil
        }
        let modifiers = LeaderKey.carbonModifiers(from: event.modifierFlags)
        guard modifiers & UInt32(controlKey | optionKey | cmdKey) != 0 else {
            NSSound.beep()
            return nil
        }
        leaderKey = LeaderKey(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
        stopRecording()
        return nil
    }

    private func saveOverride() {
        guard let leaderKey else { return }
        do {
            try coordinator.addOverride(
                KeyboardLeaderOverride(
                    id: existingOverride?.id ?? UUID(),
                    keyboard: keyboard.identity,
                    keyboardName: keyboard.name,
                    leaderKey: leaderKey
                )
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            NSSound.beep()
        }
    }
}
