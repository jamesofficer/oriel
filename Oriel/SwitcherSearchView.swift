//
//  SwitcherSearchView.swift
//  Oriel
//

import AppKit
import SwiftUI

enum SearchResultID: Hashable {
    case window(WindowKey)
    case closedApp(String)
}

enum SearchResult: Identifiable {
    case window(WindowInfo)
    case closedApp(CustomBinding)

    var id: SearchResultID {
        switch self {
        case let .window(window): .window(window.key)
        case let .closedApp(binding): .closedApp(binding.bundleID)
        }
    }

    var appName: String {
        switch self {
        case let .window(window): window.appName
        case let .closedApp(binding): binding.appName
        }
    }

    var title: String {
        switch self {
        case let .window(window): window.title
        case .closedApp: ""
        }
    }
}

struct SwitcherSearchView: View {
    let query: String
    let results: [SearchResult]
    let selectedID: SearchResultID?
    let panelSize: CGSize
    let panelOpacity: Double
    let onSelect: (SearchResult) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    private var colors: SwitcherColors {
        SwitcherColors(colorScheme: colorScheme, contrast: accessibilityContrast)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()

            if results.isEmpty {
                Text("No windows match")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: SwitcherLayout.rowSpacing) {
                            ForEach(results) { result in
                                SearchResultRow(result: result, isSelected: result.id == selectedID, colors: colors)
                                    .id(result.id)
                                    .onTapGesture { onSelect(result) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, SwitcherLayout.bodyVerticalPadding)
                    }
                    .background(OverlayScrollerStyle())
                    .onChange(of: selectedID) { _, id in
                        proxy.scrollTo(id)
                    }
                }
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .background(colors.panelBackground.opacity(panelOpacity), in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(colors.border, lineWidth: accessibilityContrast == .increased ? 1.5 : 1)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .regular))
                .frame(width: 26)

            HStack(spacing: 1) {
                Text(query)
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .truncationMode(.head)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 20)

                if query.isEmpty {
                    Text("Search windows")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(query.isEmpty ? "Search windows" : "Search: \(query)")

            HStack(spacing: 8) {
                Text("Esc")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 7)
                    .frame(height: 28)
                    .background(colors.keySurface, in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(colors.border, lineWidth: 1)
                    }
                Text(query.isEmpty ? "Close" : "Clear")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: SwitcherLayout.headerHeight)
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let colors: SwitcherColors

    private var isClosed: Bool {
        if case .closedApp = result { return true }
        return false
    }

    private var icon: NSImage? {
        switch result {
        case let .window(window): window.app.icon
        case let .closedApp(binding): NSWorkspace.shared.icon(forFile: binding.appPath)
        }
    }

    private var displayTitle: String {
        result.title.isEmpty ? result.appName : result.title
    }

    private var state: (symbol: String, label: String)? {
        switch result {
        case let .window(window) where window.isMinimized: ("minus.rectangle", "Minimized")
        case .closedApp: ("xmark.circle", "Closed")
        case .window: nil
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .saturation(isClosed ? 0.25 : 1)
                    .opacity(isClosed ? 0.6 : 1)
                    .frame(width: 26, height: 26)
            } else {
                Color.clear.frame(width: 26, height: 26)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isClosed ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(result.appName)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let state {
                Label(state.label, systemImage: state.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 9)
        .frame(height: SwitcherLayout.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.22) : colors.rowSurface, in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isSelected ? Color.accentColor : colors.border, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([displayTitle, result.appName, state?.label].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
