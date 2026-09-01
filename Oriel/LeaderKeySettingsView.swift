//
//  LeaderKeySettingsView.swift
//  Oriel
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct LeaderKeySettingsView: View {
    @ObservedObject var coordinator: LeaderKeyCoordinator
    @AppStorage(AppPreferences.Key.leaderKeyCode) private var leaderKeyCode = AppPreferences.defaultLeaderKeyCode
    @AppStorage(AppPreferences.Key.leaderKeyModifiers) private var leaderModifiers = AppPreferences.defaultLeaderKeyModifiers
    @State private var isRecording = false
    @State private var keyMonitor: Any?
    @State private var registrationError: String?

    private var leaderKey: LeaderKey {
        LeaderKey(keyCode: UInt32(leaderKeyCode), carbonModifiers: UInt32(leaderModifiers))
    }

    var body: some View {
        Section("Default Leader Key") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isRecording ? "Press shortcut…" : leaderKey.displayString)
                        .font(.system(.body, design: .monospaced).weight(.medium))
                        .foregroundStyle(isRecording ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Button(isRecording ? "Cancel" : "Record Shortcut") {
                        isRecording ? stopRecording() : startRecording()
                    }
                }
                Text(isRecording
                     ? "Press a key combination including ⌃, ⌥ or ⌘. Esc cancels."
                     : "Press this shortcut anywhere to open the switcher.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let registrationError {
                    Text(registrationError)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        registrationError = nil
        if case let .failure(error) = coordinator.pause() {
            registrationError = error.localizedDescription
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
        isRecording = false
        do {
            try coordinator.resume()
        } catch {
            registrationError = error.localizedDescription
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
        do {
            try coordinator.setDefaultLeader(
                LeaderKey(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers)
            )
        } catch {
            registrationError = error.localizedDescription
            NSSound.beep()
            stopRecording()
            return nil
        }
        leaderKeyCode = Int(event.keyCode)
        leaderModifiers = Int(modifiers)
        stopRecording()
        return nil
    }
}
