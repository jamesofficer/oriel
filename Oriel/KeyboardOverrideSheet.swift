//
//  KeyboardOverrideSheet.swift
//  Oriel
//

import AppKit
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
    @StateObject private var recorder = ShortcutRecorder()
    @Environment(\.dismiss) private var dismiss
    @State private var leaderKey: LeaderKey?
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

            Text(recorder.isRecording
                 ? ShortcutCapture.instructions
                 : "Record the leader key to use while this keyboard is connected.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = errorMessage ?? recorder.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(recorder.isRecording ? "Cancel Recording" : "Record Shortcut") {
                    recorder.isRecording ? recorder.stop() : startRecording()
                }
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(existingOverride == nil ? "Add Override" : "Save Override") {
                    saveOverride()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(leaderKey == nil || recorder.isRecording)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onDisappear { recorder.stop() }
    }

    private func startRecording() {
        errorMessage = nil
        recorder.start(pausing: coordinator) { leaderKey = $0 }
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
