//
//  SwitcherView.swift
//  switchr
//

import AppKit
import SwiftUI

enum SwitcherLayout {
    static let headerHeight: CGFloat = 54
    static let bodyVerticalPadding: CGFloat = 20
    static let columnHeaderHeight: CGFloat = 20
    static let columnSpacing: CGFloat = 10
    static let rowHeight: CGFloat = 48
    static let rowSpacing: CGFloat = 4
    static let stateHeaderHeight: CGFloat = 20
    static let stateHeaderTopPadding: CGFloat = 8
    static let minimumPanelHeight: CGFloat = 360
    static let maximumPanelHeight: CGFloat = 760
    static let panelChromeHeight = headerHeight + 1 + (bodyVerticalPadding * 2) + columnHeaderHeight + columnSpacing

    static func listHeight(activeCount: Int, minimizedCount: Int, closedCount: Int) -> CGFloat {
        let rowCount = activeCount + minimizedCount + closedCount
        let stateHeaderCount = (minimizedCount > 0 ? 1 : 0) + (closedCount > 0 ? 1 : 0)
        let childCount = rowCount + stateHeaderCount
        let childSpacing = CGFloat(max(0, childCount - 1)) * rowSpacing
        let minimizedTopPadding = minimizedCount > 0 && activeCount > 0 ? stateHeaderTopPadding : 0
        let closedTopPadding = closedCount > 0 && activeCount + minimizedCount > 0 ? stateHeaderTopPadding : 0
        return CGFloat(rowCount) * rowHeight
            + CGFloat(stateHeaderCount) * stateHeaderHeight
            + minimizedTopPadding
            + closedTopPadding
            + childSpacing
    }

    static func panelHeight(leftListHeight: CGFloat, rightListHeight: CGFloat, availableHeight: CGFloat) -> CGFloat {
        let preferredHeight = panelChromeHeight + max(leftListHeight, rightListHeight)
        return min(availableHeight, max(minimumPanelHeight, preferredHeight))
    }
}

struct SwitcherView: View {
    let pinnedRows: [SwitcherRow]
    let otherRows: [SwitcherRow]
    let closedApps: [CustomBinding]
    let hasPermission: Bool
    let panelWidth: CGFloat
    let listHeight: CGFloat
    let onSelect: (SwitcherRow) -> Void
    let onLaunch: (CustomBinding) -> Void
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    private var activePinnedRows: [SwitcherRow] {
        pinnedRows.filter { !$0.window.isMinimized }
    }

    private var minimizedPinnedRows: [SwitcherRow] {
        pinnedRows.filter(\.window.isMinimized)
    }

    private var activeOtherRows: [SwitcherRow] {
        otherRows.filter { !$0.window.isMinimized }
    }

    private var minimizedOtherRows: [SwitcherRow] {
        otherRows.filter(\.window.isMinimized)
    }

    private var panelBackgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.067, green: 0.086, blue: 0.106)
            : Color(red: 0.910, green: 0.925, blue: 0.945)
    }

    private var borderColor: Color {
        if accessibilityContrast == .increased {
            return colorScheme == .dark
                ? Color(red: 0.376, green: 0.408, blue: 0.447)
                : Color(red: 0.659, green: 0.678, blue: 0.710)
        }
        return colorScheme == .dark
            ? Color(red: 0.204, green: 0.231, blue: 0.259)
            : Color(red: 0.847, green: 0.859, blue: 0.878)
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.137, green: 0.157, blue: 0.176)
            : Color(red: 0.973, green: 0.976, blue: 0.984)
    }

    private var keySurfaceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.184, green: 0.196, blue: 0.208)
            : Color(red: 0.949, green: 0.953, blue: 0.961)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !hasPermission {
                permissionHint
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            } else if pinnedRows.isEmpty && otherRows.isEmpty && closedApps.isEmpty {
                Text("No windows open")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    windowColumn(
                        title: "Pinned Apps",
                        symbol: "pin",
                        count: pinnedRows.count + closedApps.count,
                        activeRows: activePinnedRows,
                        minimizedRows: minimizedPinnedRows,
                        closedApps: closedApps
                    )
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, alignment: .top)

                    Divider()

                    windowColumn(
                        title: "Other Windows",
                        symbol: "rectangle.on.rectangle",
                        count: otherRows.count,
                        activeRows: activeOtherRows,
                        minimizedRows: minimizedOtherRows,
                        closedApps: []
                    )
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, SwitcherLayout.bodyVerticalPadding)
                .background(OverlayScrollerStyle())
            }
        }
        .frame(width: panelWidth)
        .background(panelBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: accessibilityContrast == .increased ? 1.5 : 1)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Switch Window")
                    .font(.system(size: 15, weight: .semibold))
                Text("Press a letter to switch")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                HStack(spacing: 8) {
                    Text("Esc")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 7)
                        .frame(height: 28)
                        .background(keySurfaceColor, in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(borderColor, lineWidth: 1)
                        }
                    Text("Close")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel("Close switcher")
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 24)
        .frame(height: SwitcherLayout.headerHeight)
    }

    private func windowColumn(
        title: String,
        symbol: String,
        count: Int,
        activeRows: [SwitcherRow],
        minimizedRows: [SwitcherRow],
        closedApps: [CustomBinding]
    ) -> some View {
        VStack(alignment: .leading, spacing: SwitcherLayout.columnSpacing) {
            sectionHeader(title, symbol: symbol, count: count)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: SwitcherLayout.rowSpacing) {
                    ForEach(activeRows) { row in
                        rowView(row)
                    }

                    if !minimizedRows.isEmpty {
                        stateHeader("Minimized", symbol: "minus.rectangle", count: minimizedRows.count)
                            .padding(.top, activeRows.isEmpty ? 0 : SwitcherLayout.stateHeaderTopPadding)

                        ForEach(minimizedRows) { row in
                            rowView(row)
                        }
                    }

                    if !closedApps.isEmpty {
                        stateHeader("Closed", symbol: "xmark.circle", count: closedApps.count)
                            .padding(.top, activeRows.isEmpty && minimizedRows.isEmpty ? 0 : SwitcherLayout.stateHeaderTopPadding)

                        ForEach(closedApps) { binding in
                            closedAppRow(binding)
                        }
                    }
                }
            }
            .frame(height: listHeight)
        }
    }

    private func sectionHeader(_ title: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            countBadge(count)
        }
        .frame(height: SwitcherLayout.columnHeaderHeight)
        .accessibilityElement(children: .combine)
    }

    private func stateHeader(_ title: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
            countBadge(count)
        }
        .frame(height: SwitcherLayout.stateHeaderHeight)
        .accessibilityElement(children: .combine)
    }

    private func countBadge(_ count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(rowSurfaceColor, in: Capsule())
    }

    private func rowView(_ row: SwitcherRow) -> some View {
        HStack(spacing: 10) {
            letterKey(row.letter.map { String($0).uppercased() } ?? "", isClosed: false)

            if let icon = row.window.app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)
            } else {
                Color.clear.frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(row.window.displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(row.window.appName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if row.window.isMinimized {
                Image(systemName: "minus.rectangle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .help("Minimized")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: SwitcherLayout.rowHeight)
        .background(rowSurfaceColor, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { onSelect(row) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(row))
    }

    private func closedAppRow(_ binding: CustomBinding) -> some View {
        HStack(spacing: 10) {
            letterKey(binding.key.uppercased(), isClosed: true)

            Image(nsImage: NSWorkspace.shared.icon(forFile: binding.appPath))
                .resizable()
                .interpolation(.high)
                .saturation(0.25)
                .opacity(0.6)
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(binding.appName)
                    .font(.system(size: 13, weight: .medium))
                Text(binding.appName)
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            .opacity(0.65)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize()
                .help("Closed")
        }
        .padding(.horizontal, 9)
        .frame(height: SwitcherLayout.rowHeight)
        .background(rowSurfaceColor, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture { onLaunch(binding) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(binding.key.uppercased()), \(binding.appName), \(binding.appName), closed")
    }

    private func letterKey(_ letter: String, isClosed: Bool) -> some View {
        Text(letter)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(isClosed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            .frame(width: 32, height: 32)
            .background(keySurfaceColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
    }

    private func rowAccessibilityLabel(_ row: SwitcherRow) -> String {
        let letter = row.letter.map { String($0).uppercased() } ?? "No shortcut"
        let state = row.window.isMinimized ? ", minimized" : ""
        return "\(letter), \(row.window.displayTitle), \(row.window.appName)\(state)"
    }

    private var permissionHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Accessibility permission needed", systemImage: "lock.shield")
                .font(.headline)
            Text("Switchr needs Accessibility access to list and focus windows.")
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
