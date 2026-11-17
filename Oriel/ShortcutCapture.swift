//
//  ShortcutCapture.swift
//  Oriel
//

import AppKit
import Carbon.HIToolbox

enum ShortcutCapture: Equatable {
    case cancelled
    case invalid
    case shortcut(LeaderKey)

    static let instructions = "Press a key combination including ⌃, ⌥ or ⌘. Esc cancels."

    /// A shortcut must include Control, Option or Command, or it
    /// would fire during normal typing. Escape alone cancels.
    static func from(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) -> ShortcutCapture {
        let modifiers = LeaderKey.carbonModifiers(from: modifierFlags)
        let hasRequiredModifier = modifiers & UInt32(controlKey | optionKey | cmdKey) != 0

        if hasRequiredModifier {
            return .shortcut(LeaderKey(keyCode: UInt32(keyCode), carbonModifiers: modifiers))
        }

        return keyCode == UInt16(kVK_Escape) ? .cancelled : .invalid
    }
}
