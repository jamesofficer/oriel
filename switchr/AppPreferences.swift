//
//  AppPreferences.swift
//  switchr
//

import Foundation

enum AppPreferences {
    enum Key {
        static let bringToCurrentScreen = "bringWindowToCurrentScreen"
        static let maximizeOnFocus = "maximizeWindowWhenFocused"
        static let animatePanel = "animateSwitcherAppearance"
        static let showClosedApps = "showClosedAppsInSwitcher"
        static let revealDelayMilliseconds = "switcherRevealDelayMilliseconds"
        static let panelOpacity = "switcherPanelOpacity"
        static let leaderKeyCode = "leaderKeyCode"
        static let leaderKeyModifiers = "leaderKeyModifiers"
    }

    static let defaultBringToCurrentScreen = false
    static let defaultMaximizeOnFocus = false
    static let defaultAnimatePanel = true
    static let defaultShowClosedApps = true
    static let defaultRevealDelayMilliseconds = 100
    static let revealDelayRange = 0...1_000
    static let defaultPanelOpacity = 0.9
    static let panelOpacityRange = 0.8...1.0

    static var defaultLeaderKeyCode: Int {
        Int(LeaderKey.default.keyCode)
    }

    static var defaultLeaderKeyModifiers: Int {
        Int(LeaderKey.default.carbonModifiers)
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.bringToCurrentScreen: defaultBringToCurrentScreen,
            Key.maximizeOnFocus: defaultMaximizeOnFocus,
            Key.animatePanel: defaultAnimatePanel,
            Key.showClosedApps: defaultShowClosedApps,
            Key.revealDelayMilliseconds: defaultRevealDelayMilliseconds,
            Key.panelOpacity: defaultPanelOpacity,
            Key.leaderKeyCode: defaultLeaderKeyCode,
            Key.leaderKeyModifiers: defaultLeaderKeyModifiers,
        ])
    }

    static func bringToCurrentScreen(in defaults: UserDefaults = .standard) -> Bool {
        boolValue(forKey: Key.bringToCurrentScreen, defaultValue: defaultBringToCurrentScreen, in: defaults)
    }

    static func maximizeOnFocus(in defaults: UserDefaults = .standard) -> Bool {
        boolValue(forKey: Key.maximizeOnFocus, defaultValue: defaultMaximizeOnFocus, in: defaults)
    }

    static func animatePanel(in defaults: UserDefaults = .standard) -> Bool {
        boolValue(forKey: Key.animatePanel, defaultValue: defaultAnimatePanel, in: defaults)
    }

    static func showClosedApps(in defaults: UserDefaults = .standard) -> Bool {
        boolValue(forKey: Key.showClosedApps, defaultValue: defaultShowClosedApps, in: defaults)
    }

    static func revealDelayMilliseconds(in defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: Key.revealDelayMilliseconds) != nil else {
            return defaultRevealDelayMilliseconds
        }
        return min(max(defaults.integer(forKey: Key.revealDelayMilliseconds), revealDelayRange.lowerBound), revealDelayRange.upperBound)
    }

    static func panelOpacity(in defaults: UserDefaults = .standard) -> Double {
        guard defaults.object(forKey: Key.panelOpacity) != nil else {
            return defaultPanelOpacity
        }
        return min(max(defaults.double(forKey: Key.panelOpacity), panelOpacityRange.lowerBound), panelOpacityRange.upperBound)
    }

    static func leaderKey(in defaults: UserDefaults = .standard) -> LeaderKey {
        guard defaults.object(forKey: Key.leaderKeyCode) != nil else {
            return .default
        }
        return LeaderKey(
            keyCode: UInt32(defaults.integer(forKey: Key.leaderKeyCode)),
            carbonModifiers: UInt32(defaults.integer(forKey: Key.leaderKeyModifiers))
        )
    }

    static func setLeaderKey(_ leaderKey: LeaderKey, in defaults: UserDefaults = .standard) {
        defaults.set(Int(leaderKey.keyCode), forKey: Key.leaderKeyCode)
        defaults.set(Int(leaderKey.carbonModifiers), forKey: Key.leaderKeyModifiers)
    }

    private static func boolValue(forKey key: String, defaultValue: Bool, in defaults: UserDefaults) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
