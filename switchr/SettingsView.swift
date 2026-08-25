//
//  SettingsView.swift
//  switchr
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        HStack(spacing: 0) {
            Form {
                LeaderKeySettingsView()
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
