//
//  AppDelegate.swift
//  Oriel
//

import AppKit
import Carbon.HIToolbox
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let switcher = SwitcherPanelController()
    let keyboardMonitor = KeyboardDeviceMonitor()
    let keyboardOverridesStore = KeyboardLeaderOverridesStore.shared
    lazy var leaderKeyCoordinator = LeaderKeyCoordinator(store: keyboardOverridesStore)

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.registerDefaults()
        promptForAccessibilityIfNeeded()
        startLeaderKey()
        keyboardMonitor.$connectedKeyboards
            .sink { [weak self] keyboards in
                self?.leaderKeyCoordinator.updateConnectedKeyboards(keyboards)
            }
            .store(in: &cancellables)
        keyboardMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }

    private func startLeaderKey() {
        do {
            try leaderKeyCoordinator.start { [weak self] in
                self?.switcher.toggle()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Oriel could not register its shortcut"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func promptForAccessibilityIfNeeded() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
