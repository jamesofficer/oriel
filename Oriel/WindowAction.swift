//
//  WindowAction.swift
//  Oriel
//

import Foundation

enum WindowAction: Equatable {
    case place(WindowPlacement.Target)
    case hideApp
}

struct WindowActionKey: Identifiable {
    let key: Character
    let title: String
    let action: WindowAction

    var id: Character { key }

    /// The panel shows each group as one row of keys.
    static let groups: [[WindowActionKey]] = [
        [
            WindowActionKey(key: "l", title: "Left half", action: .place(.left)),
            WindowActionKey(key: "r", title: "Right half", action: .place(.right)),
            WindowActionKey(key: "m", title: "Maximize", action: .place(.maximize)),
        ],
        [
            WindowActionKey(key: "t", title: "Top half", action: .place(.top)),
            WindowActionKey(key: "b", title: "Bottom half", action: .place(.bottom)),
            WindowActionKey(key: "c", title: "Center", action: .place(.center)),
        ],
        [
            WindowActionKey(key: "n", title: "Next display", action: .place(.nextDisplay)),
            WindowActionKey(key: "p", title: "Previous display", action: .place(.previousDisplay)),
            WindowActionKey(key: "h", title: "Hide app", action: .hideApp),
        ],
    ]

    static func action(for key: Character) -> WindowAction? {
        groups.joined().first { $0.key == key }?.action
    }
}
