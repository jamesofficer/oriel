//
//  AccessibilityPermissionHint.swift
//  Oriel
//

import AppKit
import SwiftUI

struct AccessibilityPermissionHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility permission needed", systemImage: "lock.shield")
                .font(.headline)
            Text("Oriel needs Accessibility access to list and focus windows.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
        .padding(16)
    }
}
