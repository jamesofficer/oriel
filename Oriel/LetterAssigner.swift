//
//  LetterAssigner.swift
//  Oriel
//

import AppKit
import ApplicationServices
import Foundation

struct SwitcherRow: Identifiable {
    let letter: Character?
    let window: WindowInfo
    var id: UUID { window.id }
}

private struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}

final class LetterAssigner {
    private static let defaultsKey = "appLetterAssignments"

    private var engine = LetterAssignmentEngine<WindowKey>()

    private var persisted: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: Self.defaultsKey) }
    }

    func assign(to windows: [WindowInfo]) -> [SwitcherRow] {
        let bindings = CustomBindingsStore.shared.bindings
        let customLetters = Dictionary(
            uniqueKeysWithValues: bindings.compactMap { binding in
                binding.letter.map { (binding.bundleID, $0) }
            }
        )
        let descriptors = windows.map { window in
            LetterAssignmentWindow(
                id: WindowKey(element: window.axWindow),
                bundleID: window.app.bundleIdentifier,
                appName: window.appName
            )
        }
        let result = engine.assign(
            windows: descriptors,
            customLetters: customLetters,
            reservedLetters: CustomBindingsStore.shared.reservedLetters,
            persistedLetters: persisted
        )
        persisted = result.persistedLetters

        var windowsByKey: [WindowKey: WindowInfo] = [:]
        for window in windows {
            windowsByKey[WindowKey(element: window.axWindow)] = window
        }
        return result.assignments.compactMap { assignment in
            guard let window = windowsByKey[assignment.id] else { return nil }
            return SwitcherRow(letter: assignment.letter, window: window)
        }
    }
}
