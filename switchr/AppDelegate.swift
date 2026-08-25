//
//  AppDelegate.swift
//  switchr
//

import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    let switcher = SwitcherPanelController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.registerDefaults()
        promptForAccessibilityIfNeeded()
        registerLeaderKey()

    }

    private func registerLeaderKey() {
        let key = LeaderKey.current
        do {
            try HotKeyCenter.shared.register(
                keyCode: key.keyCode,
                modifiers: key.carbonModifiers
            ) { [weak self] in
                self?.switcher.toggle()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Switchr could not register its shortcut"
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
