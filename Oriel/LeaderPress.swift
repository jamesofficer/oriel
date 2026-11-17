//
//  LeaderPress.swift
//  Oriel
//

import Foundation

enum LeaderPressAction: Equatable {
    case show
    case windowActions
    case hide
}

enum LeaderPress {
    /// A second press within this time after the panel opens starts
    /// the window actions instead of closing the panel.
    static let doublePressInterval: TimeInterval = 0.35

    static func action(
        isPanelOpen: Bool,
        isShowingLetters: Bool,
        isWindowActionsEnabled: Bool,
        secondsSincePanelOpened: TimeInterval
    ) -> LeaderPressAction {
        guard isPanelOpen else { return .show }

        let isDoublePress = secondsSincePanelOpened <= doublePressInterval
        return isDoublePress && isShowingLetters && isWindowActionsEnabled ? .windowActions : .hide
    }
}
