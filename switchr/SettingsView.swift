//
//  SettingsView.swift
//  switchr
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var keyboardMonitor: KeyboardDeviceMonitor
    @ObservedObject var keyboardOverridesStore: KeyboardLeaderOverridesStore
    @ObservedObject var leaderKeyCoordinator: LeaderKeyCoordinator

    var body: some View {
        HStack(spacing: 0) {
            Form {
                LeaderKeySettingsView(coordinator: leaderKeyCoordinator)
                KeyboardOverridesSettingsView(
                    keyboardMonitor: keyboardMonitor,
                    store: keyboardOverridesStore,
                    coordinator: leaderKeyCoordinator
                )
                AppBindingsSettingsView()
            }
            .formStyle(.grouped)
            .frame(width: 400)

            Divider()

            Form {
                BehaviorSettingsView()
            }
            .formStyle(.grouped)
            .frame(maxWidth: .infinity)
        }
        .background(OverlayScrollerStyle())
        .frame(width: 920, height: 560)
    }
}
