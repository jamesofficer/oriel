//
//  LeaderKeySettingsView.swift
//  Oriel
//

import AppKit
import SwiftUI

struct LeaderKeySettingsView: View {
    @ObservedObject var coordinator: LeaderKeyCoordinator
    @StateObject private var recorder = ShortcutRecorder()
    @AppStorage(AppPreferences.Key.leaderKeyCode) private var leaderKeyCode = AppPreferences.defaultLeaderKeyCode
    @AppStorage(AppPreferences.Key.leaderKeyModifiers) private var leaderModifiers = AppPreferences.defaultLeaderKeyModifiers
    @State private var registrationError: String?

    private var leaderKey: LeaderKey {
        LeaderKey(keyCode: UInt32(leaderKeyCode), carbonModifiers: UInt32(leaderModifiers))
    }

    var body: some View {
        Section("Default Leader Key") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(recorder.isRecording ? "Press shortcut…" : leaderKey.displayString)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .foregroundStyle(recorder.isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Button(recorder.isRecording ? "Cancel" : "Record Shortcut") {
                        recorder.isRecording ? recorder.stop() : startRecording()
                    }
                }
                Text(recorder.isRecording
                     ? ShortcutCapture.instructions
                     : "Press this shortcut anywhere to open the switcher.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if let error = registrationError ?? recorder.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .onDisappear { recorder.stop() }
    }

    private func startRecording() {
        registrationError = nil
        recorder.start(pausing: coordinator) { leaderKey in
            setDefaultLeader(leaderKey)
        }
    }

    private func setDefaultLeader(_ leaderKey: LeaderKey) {
        do {
            try coordinator.setDefaultLeader(leaderKey)
        } catch {
            registrationError = error.localizedDescription
            NSSound.beep()
        }
    }
}
