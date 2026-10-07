//
//  SwitcherPanelController.swift
//  Oriel
//
//  A Spotlight-style non-activating panel: it takes key presses without
//  activating this app, so dismissing returns you to where you were.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

final class SwitcherPanelController: NSObject, NSWindowDelegate {
    /// A second leader press within this time after the panel opens
    /// starts search mode instead of closing the panel.
    private static let doublePressInterval: TimeInterval = 0.35

    private var panel: SwitcherPanel?
    private var panelScreen: NSScreen?
    private var shownAt: TimeInterval = 0
    private var revealWork: DispatchWorkItem?
    // True once a window was selected with the leader modifiers still held:
    // the panel stays up so further letters keep switching, until release.
    private var isFlicking = false
    // The reveal delay elapsed while the leader modifiers were still held;
    // show the panel when they're released instead.
    private var revealPending = false
    private var hostingView: NSHostingView<SwitcherView>?
    private var searchHostingView: NSHostingView<SwitcherSearchView>?
    private var windows: [WindowInfo] = []
    private var rows: [SwitcherRow] = []
    private var closedApps: [CustomBinding] = []
    private var isSearching = false
    private var searchQuery = ""
    private var searchResults: [SearchResult] = []
    private var selectedResultID: SearchResultID?
    private var searchPanelSize = CGSize.zero
    private var usageHistory = WindowUsageHistory<WindowKey>()
    private let letterAssigner = LetterAssigner()
    private let windowCache: WindowCache

    init(windowCache: WindowCache) {
        self.windowCache = windowCache
        super.init()
        windowCache.onChange = { [weak self] in self?.windowsDidChange() }
    }

    func toggle() {
        let isDoublePress = ProcessInfo.processInfo.systemUptime - shownAt <= Self.doublePressInterval

        if panel == nil {
            show()
        } else if isDoublePress, !isSearching, AppPreferences.searchOnDoublePress() {
            startSearch()
        } else {
            hide()
        }
    }

    func show() {
        let panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
        panel.onFlagsChanged = { [weak self] event in self?.handleFlags(event) }

        panelScreen = NSScreen.main
        shownAt = ProcessInfo.processInfo.systemUptime
        self.panel = panel

        // Take keyboard focus before listing windows. Key events from a fast
        // leader roll then wait for Oriel instead of reaching the old app.
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        // Show the stored list at once. A new list replaces it when ready.
        updateContent(with: windowCache.windows ?? WindowManager.listWindows())
        windowCache.refresh()

        // The panel stays invisible for a beat. A fast leader and letter
        // switches without showing it; it appears only after a short pause.
        let revealDelay = Double(AppPreferences.revealDelayMilliseconds()) / 1_000
        let work = DispatchWorkItem { [weak self] in self?.reveal() }
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay, execute: work)
    }

    private func windowsDidChange() {
        guard panel != nil, let windows = windowCache.windows else { return }

        if isSearching {
            self.windows = windows
            updateSearchResults(resetSelection: false)
        } else {
            updateContent(with: windows)
        }
    }

    private func updateContent(with windows: [WindowInfo]) {
        guard let panel else { return }

        let visibleFrame = panelScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_240, height: 900)
        let panelWidth = min(1_040, max(1, visibleFrame.width - 80))
        let maxPanelHeight = min(SwitcherLayout.maximumPanelHeight, max(1, visibleFrame.height - 80))

        self.windows = windows
        rows = letterAssigner.assign(to: windows)

        let bindings = CustomBindingsStore.shared.bindings
        let content = SwitcherContentBuilder.build(
            items: rows.map {
                SwitcherItem(
                    value: $0,
                    bundleID: $0.window.app.bundleIdentifier,
                    isMinimized: $0.window.isMinimized
                )
            },
            bindings: bindings,
            showClosedApps: AppPreferences.showClosedApps()
        )
        closedApps = content.closedApps
        let pinnedListHeight = SwitcherLayout.listHeight(
            activeCount: content.activePinned.count,
            minimizedCount: content.minimizedPinned.count,
            closedCount: content.closedApps.count
        )
        let otherListHeight = SwitcherLayout.listHeight(
            activeCount: content.activeOther.count,
            minimizedCount: content.minimizedOther.count,
            closedCount: 0
        )
        let panelHeight = SwitcherLayout.panelHeight(
            leftListHeight: pinnedListHeight,
            rightListHeight: otherListHeight,
            availableHeight: maxPanelHeight
        )
        let listHeight = max(1, panelHeight - SwitcherLayout.panelChromeHeight)
        let panelOpacity = AppPreferences.panelOpacity()

        let view = SwitcherView(
            content: content,
            hasPermission: WindowManager.hasAccessibilityPermission,
            panelWidth: panelWidth,
            listHeight: listHeight,
            panelOpacity: panelOpacity,
            onSelect: { [weak self] row in self?.select(row) },
            onLaunch: { [weak self] binding in self?.launch(binding) },
            onClose: { [weak self] in self?.hide() }
        )
        let contentSize = NSSize(width: panelWidth, height: panelHeight)
        panel.setContentSize(contentSize)

        if let hostingView {
            hostingView.rootView = view
            hostingView.frame.size = contentSize
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = contentSize
            panel.contentView = hosting
            hostingView = hosting
        }

        let origin = NSPoint(
            x: visibleFrame.midX - contentSize.width / 2,
            y: visibleFrame.midY - contentSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    /// Search keeps the panel's current size and place, so the panel does
    /// not jump while the results change. It shows at once, even while
    /// the leader modifiers are still held down.
    private func startSearch() {
        guard let panel else { return }

        isSearching = true
        isFlicking = false
        searchQuery = ""
        searchPanelSize = panel.frame.size
        updateSearchResults(resetSelection: true)

        revealWork?.cancel()
        revealWork = nil
        makeVisible()
    }

    private func stopSearch() {
        guard let panel, let hostingView else { return }

        isSearching = false
        searchQuery = ""
        searchResults = []
        selectedResultID = nil
        searchHostingView = nil
        panel.contentView = hostingView
        updateContent(with: windows)
    }

    private func setSearchQuery(_ query: String) {
        searchQuery = query
        updateSearchResults(resetSelection: true)
    }

    /// The window list can change while the user types. Keep the same
    /// window selected if it is still there, as its position can change.
    private func updateSearchResults(resetSelection: Bool) {
        let bindings = CustomBindingsStore.shared.bindings
        let pinnedBundleIDs = Set(bindings.map(\.bundleID))
        let openBundleIDs = Set(windows.compactMap(\.app.bundleIdentifier))
        let closedBindings = AppPreferences.showClosedApps()
            ? bindings.filter { !openBundleIDs.contains($0.bundleID) }
            : []
        let candidates = windows.map(SearchResult.window) + closedBindings.map(SearchResult.closedApp)

        let order = WindowSearch.rank(
            candidates.enumerated().map { index, result in
                WindowSearchCandidate(
                    id: index,
                    appName: result.appName,
                    title: result.title,
                    group: searchGroup(for: result, pinnedBundleIDs: pinnedBundleIDs),
                    lastUsed: lastUsed(result)
                )
            },
            query: searchQuery
        )
        searchResults = order.map { candidates[$0] }

        if resetSelection || !searchResults.contains(where: { $0.id == selectedResultID }) {
            selectedResultID = searchResults.first?.id
        }

        renderSearch()
    }

    private func searchGroup(for result: SearchResult, pinnedBundleIDs: Set<String>) -> WindowSearchGroup {
        switch result {
        case .closedApp:
            return .closed
        case let .window(window):
            let isPinned = window.app.bundleIdentifier.map(pinnedBundleIDs.contains) ?? false
            return isPinned ? .pinned : .other
        }
    }

    private func lastUsed(_ result: SearchResult) -> Int? {
        guard case let .window(window) = result else { return nil }

        return usageHistory.lastUsed(window.key)
    }

    private func renderSearch() {
        guard let panel else { return }

        let view = SwitcherSearchView(
            query: searchQuery,
            results: searchResults,
            selectedID: selectedResultID,
            panelSize: searchPanelSize,
            panelOpacity: AppPreferences.panelOpacity(),
            onSelect: { [weak self] result in self?.open(result) }
        )

        if let searchHostingView {
            searchHostingView.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = searchPanelSize
            panel.contentView = hosting
            searchHostingView = hosting
        }
    }

    private func moveSelection(by offset: Int) {
        guard let index = searchResults.firstIndex(where: { $0.id == selectedResultID }) else { return }

        let newIndex = min(max(index + offset, 0), searchResults.count - 1)
        selectedResultID = searchResults[newIndex].id
        renderSearch()
    }

    private func reveal() {
        guard panel != nil else { return }
        // While the leader modifiers are held down the user is flicking, not
        // browsing: stay hidden and reveal on release instead.
        if NSEvent.modifierFlags.contains(LeaderKey.current.cocoaModifiers) {
            revealPending = true
            return
        }
        makeVisible()
    }

    private func makeVisible() {
        guard let panel else { return }

        revealPending = false
        let animate = AppPreferences.animatePanel()
        if animate {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                panel.animator().alphaValue = 1
            }
        } else {
            panel.alphaValue = 1
        }
    }

    func hide() {
        revealWork?.cancel()
        revealWork = nil
        isFlicking = false
        revealPending = false
        isSearching = false
        searchQuery = ""
        searchResults = []
        selectedResultID = nil
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        searchHostingView = nil
        panelScreen = nil
        windows = []
        rows = []
        closedApps = []
    }

    private func launch(_ binding: CustomBinding) {
        hide()
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: binding.appPath),
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    private func select(_ row: SwitcherRow) {
        hide()
        focus(row.window)
    }

    private func open(_ result: SearchResult) {
        switch result {
        case let .window(window):
            hide()
            focus(window)
        case let .closedApp(binding):
            launch(binding)
        }
    }

    /// Switch focus but keep the session alive: the target app takes key
    /// status when it activates, so reclaim it for the panel (nonactivating
    /// panels may hold key while another app stays active) unless the leader
    /// modifiers were released in the gap.
    private func flick(to row: SwitcherRow) {
        isFlicking = true
        focus(row.window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let panel = self.panel else { return }
            if NSEvent.modifierFlags.contains(LeaderKey.current.cocoaModifiers) {
                panel.makeKey()
            } else {
                self.hide()
            }
        }
    }

    private func focus(_ window: WindowInfo) {
        usageHistory.record(window.key)
        let moveTarget = AppPreferences.bringToCurrentScreen() ? panelScreen : nil
        let maximize = AppPreferences.maximizeOnFocus()
        WindowManager.focus(window, movingTo: moveTarget, maximizing: maximize)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if isSearching {
            return handleSearchKey(event)
        }
        if event.isARepeat {
            return true
        }
        if event.keyCode == 53 { // Escape
            hide()
            return true
        }
        guard let letter = event.charactersIgnoringModifiers?.lowercased().first else { return false }
        // Letters pressed with the leader modifiers still held flick between
        // windows without closing; a plain letter selects and closes.
        let leaderFlags = LeaderKey.current.cocoaModifiers
        let holdingLeader = !leaderFlags.isEmpty && event.modifierFlags.contains(leaderFlags)
        guard holdingLeader || !event.modifierFlags.contains(.command) else { return false }

        if let row = rows.first(where: { $0.letter == letter }) {
            holdingLeader ? flick(to: row) : select(row)
            return true
        }
        if let binding = closedApps.first(where: { $0.letter == letter }) {
            launch(binding)
            return true
        }
        return false
    }

    /// Search ignores Command, as the user can still hold the leader's
    /// Command key down when they start to type.
    private func handleSearchKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        let plainKey = event.charactersIgnoringModifiers?.lowercased()

        switch Int(event.keyCode) {
        case kVK_Escape:
            searchQuery.isEmpty ? hide() : setSearchQuery("")
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let result = searchResults.first(where: { $0.id == selectedResultID }) {
                open(result)
            }
        case kVK_DownArrow:
            moveSelection(by: 1)
        case kVK_UpArrow:
            moveSelection(by: -1)
        case kVK_Delete:
            if searchQuery.isEmpty {
                stopSearch()
            } else if flags.contains(.option) {
                setSearchQuery(SearchText.deletingLastWord(searchQuery))
            } else {
                setSearchQuery(String(searchQuery.dropLast()))
            }
        default:
            if flags.contains(.control) {
                if plainKey == "n" {
                    moveSelection(by: 1)
                } else if plainKey == "p" {
                    moveSelection(by: -1)
                }
                return true
            }

            let characters = flags.contains(.command) ? event.charactersIgnoringModifiers : event.characters
            guard let text = SearchText.typedText(characters) else { return false }

            setSearchQuery(searchQuery + text)
        }
        return true
    }

    private func handleFlags(_ event: NSEvent) {
        guard !event.modifierFlags.contains(LeaderKey.current.cocoaModifiers) else { return }
        if isFlicking {
            hide()
        } else if revealPending {
            reveal()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // During a flick the focused app steals key; take it back rather than
        // closing, as long as the leader modifiers are still held.
        if isFlicking, panel != nil, NSEvent.modifierFlags.contains(LeaderKey.current.cocoaModifiers) {
            DispatchQueue.main.async { [weak self] in self?.panel?.makeKey() }
            return
        }
        hide()
    }
}

final class SwitcherPanel: NSPanel {
    var onKeyDown: ((NSEvent) -> Bool)?
    var onFlagsChanged: ((NSEvent) -> Void)?

    // A borderless panel refuses key status unless we say otherwise.
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        onFlagsChanged?(event)
        super.flagsChanged(with: event)
    }
}
