//
//  WindowActionsView.swift
//  Oriel
//

import AppKit
import SwiftUI

struct WindowActionsView: View {
    let app: NSRunningApplication
    let panelOpacity: Double
    let onSelect: (WindowAction) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    private var colors: SwitcherColors {
        SwitcherColors(colorScheme: colorScheme, contrast: accessibilityContrast)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(WindowActionKey.groups, id: \.first?.key) { group in
                    GridRow {
                        ForEach(group) { item in
                            keyRow(item)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, SwitcherLayout.bodyVerticalPadding)
        }
        .frame(width: 640)
        .switcherPanelChrome(colors: colors, opacity: panelOpacity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.localizedName ?? "Window actions")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text("Press a key to move this window. Press a half key again for one third, then two thirds.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                EscKeyCap(colors: colors)
                Text("Close")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: SwitcherLayout.headerHeight)
    }

    private func keyRow(_ item: WindowActionKey) -> some View {
        HStack(spacing: 10) {
            LetterKeyCap(letter: String(item.key).uppercased(), colors: colors)

            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .frame(height: SwitcherLayout.rowHeight)
        .background(colors.rowSurface, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(colors.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { onSelect(item.action) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(item.key).uppercased()), \(item.title)")
    }
}
