//
//  WindowAction.swift
//  Oriel
//

import Foundation

enum WindowAction: Equatable {
    case place(WindowPlacement.Target)
    case undoPlacement
    case toggleFullScreen
    case hideApp
}

struct WindowActionKey: Identifiable {
    let key: Character
    let title: String
    let action: WindowAction

    var id: Character { key }

    static func action(for key: Character) -> WindowAction? {
        WindowActionSection.all.flatMap(\.keys).first { $0.key == key }?.action
    }
}

struct WindowActionSection: Identifiable {
    let title: String
    let symbol: String
    let keys: [WindowActionKey]

    var id: String { title }

    static let all: [WindowActionSection] = [
        WindowActionSection(title: "Halves and thirds", symbol: "rectangle.split.2x1", keys: [
            WindowActionKey(key: "l", title: "Left half", action: .place(.left)),
            WindowActionKey(key: "r", title: "Right half", action: .place(.right)),
            WindowActionKey(key: "t", title: "Top half", action: .place(.top)),
            WindowActionKey(key: "b", title: "Bottom half", action: .place(.bottom)),
        ]),
        WindowActionSection(title: "Size and place", symbol: "arrow.up.left.and.arrow.down.right", keys: [
            WindowActionKey(key: "m", title: "Maximize", action: .place(.maximize)),
            WindowActionKey(key: "f", title: "Full screen", action: .toggleFullScreen),
            WindowActionKey(key: "c", title: "Center", action: .place(.center)),
        ]),
        WindowActionSection(title: "Display", symbol: "display", keys: [
            WindowActionKey(key: "n", title: "Next display", action: .place(.nextDisplay)),
            WindowActionKey(key: "p", title: "Previous display", action: .place(.previousDisplay)),
        ]),
        WindowActionSection(title: "Window", symbol: "macwindow", keys: [
            WindowActionKey(key: "u", title: "Undo move", action: .undoPlacement),
            WindowActionKey(key: "h", title: "Hide app", action: .hideApp),
        ]),
    ]
}
