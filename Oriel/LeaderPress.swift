//
//  LeaderPress.swift
//  Oriel
//

import Foundation

enum LeaderPressAction: Equatable {
    case show
    case search
    case hide
}

enum LeaderPress {
    /// A second press within this time after the panel opens starts
    /// search mode instead of closing the panel.
    static let doublePressInterval: TimeInterval = 0.35

    static func action(
        isPanelOpen: Bool,
        isSearching: Bool,
        isSearchEnabled: Bool,
        secondsSincePanelOpened: TimeInterval
    ) -> LeaderPressAction {
        guard isPanelOpen else { return .show }

        let isDoublePress = secondsSincePanelOpened <= doublePressInterval
        return isDoublePress && !isSearching && isSearchEnabled ? .search : .hide
    }
}
