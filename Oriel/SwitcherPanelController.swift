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
    private var session: SwitcherSession?
    private var usageHistory = WindowUsageHistory<WindowKey>()
    private let letterAssigner = LetterAssigner()
    private let windowCache: WindowCache
    private let effectiveLeaderKey: () -> LeaderKey

    init(windowCache: WindowCache, effectiveLeaderKey: @escaping () -> LeaderKey) {
        self.windowCache = windowCache
        self.effectiveLeaderKey = effectiveLeaderKey
        super.init()
        windowCache.onChange = { [weak self] in self?.windowsDidChange() }
    }

    func toggle() {
        let action = LeaderPress.action(
            isPanelOpen: session != nil,
            isSearching: session?.search != nil,
            isSearchEnabled: AppPreferences.searchOnDoublePress(),
            secondsSincePanelOpened: session.map { ProcessInfo.processInfo.systemUptime - $0.shownAt } ?? 0
        )

        switch action {
        case .show: show()
        case .search: startSearch()
        case .hide: hide()
        }
    }

    private func show() {
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

        let session = SwitcherSession(
            panel: panel,
            screen: NSScreen.main,
            shownAt: ProcessInfo.processInfo.systemUptime
        )
        self.session = session

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
        session.revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay, execute: work)
    }

    private func windowsDidChange() {
        guard let session, let windows = windowCache.windows else { return }

        if session.search != nil {
            session.windows = windows
            updateSearchResults(resetSelection: false)
        } else {
            updateContent(with: windows)
        }
    }

    private func updateContent(with windows: [WindowInfo]) {
        guard let session else { return }

        let panel = session.panel
        let visibleFrame = session.screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1_240, height: 900)
        let panelWidth = min(1_040, max(1, visibleFrame.width - 80))
        let maxPanelHeight = min(SwitcherLayout.maximumPanelHeight, max(1, visibleFrame.height - 80))

        session.windows = windows
        session.rows = letterAssigner.assign(to: windows)

        let bindings = CustomBindingsStore.shared.bindings
        let content = SwitcherContentBuilder.build(
            items: session.rows.map {
                SwitcherItem(
                    value: $0,
                    bundleID: $0.window.app.bundleIdentifier,
                    isMinimized: $0.window.isMinimized
                )
            },
            bindings: bindings,
            showClosedApps: AppPreferences.showClosedApps()
        )
        session.closedApps = content.closedApps
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
            searchKey: AppPreferences.searchOnDoublePress() ? effectiveLeaderKey().displayString : nil,
            panelWidth: panelWidth,
            listHeight: listHeight,
            panelOpacity: panelOpacity,
            onSelect: { [weak self] row in self?.select(row) },
            onLaunch: { [weak self] binding in self?.launch(binding) },
            onClose: { [weak self] in self?.hide() }
        )
        let contentSize = NSSize(width: panelWidth, height: panelHeight)
        panel.setContentSize(contentSize)

        if let hostingView = session.hostingView {
            hostingView.rootView = view
            hostingView.frame.size = contentSize
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = contentSize
            panel.contentView = hosting
            session.hostingView = hosting
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
        guard let session else { return }

        session.isFlicking = false
        session.search = SearchState(panelSize: session.panel.frame.size)
        updateSearchResults(resetSelection: true)

        session.revealWork?.cancel()
        session.revealWork = nil
        makeVisible()
    }

    private func stopSearch() {
        guard let session, let hostingView = session.hostingView else { return }

        session.search = nil
        session.panel.contentView = hostingView
        updateContent(with: session.windows)
    }

    private func setSearchQuery(_ query: String) {
        session?.search?.query = query
        updateSearchResults(resetSelection: true)
    }

    /// The window list can change while the user types, and a window
    /// can move in the results. Keep the same window selected if it
    /// is still in the results.
    private func updateSearchResults(resetSelection: Bool) {
        guard let session, var search = session.search else { return }

        let bindings = CustomBindingsStore.shared.bindings
        let pinnedBundleIDs = Set(bindings.map(\.bundleID))
        let openBundleIDs = Set(session.windows.compactMap(\.app.bundleIdentifier))
        let closedBindings = AppPreferences.showClosedApps()
            ? bindings.filter { !openBundleIDs.contains($0.bundleID) }
            : []
        let candidates = session.windows.map(SearchResult.window) + closedBindings.map(SearchResult.closedApp)

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
            query: search.query
        )
        search.results = order.map { candidates[$0] }

        if resetSelection || !search.results.contains(where: { $0.id == search.selectedID }) {
            search.selectedID = search.results.first?.id
        }

        session.search = search
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
        guard let session, let search = session.search else { return }

        let view = SwitcherSearchView(
            query: search.query,
            results: search.results,
            hasPermission: WindowManager.hasAccessibilityPermission,
            selectedID: search.selectedID,
            panelSize: search.panelSize,
            panelOpacity: AppPreferences.panelOpacity(),
            onSelect: { [weak self] result in self?.open(result) }
        )

        if let hostingView = search.hostingView {
            hostingView.rootView = view
        } else {
            let hosting = NSHostingView(rootView: view)
            hosting.frame.size = search.panelSize
            session.panel.contentView = hosting
            session.search?.hostingView = hosting
        }
    }

    private func moveSelection(by offset: Int) {
        guard let search = session?.search,
              let index = search.results.firstIndex(where: { $0.id == search.selectedID }) else { return }

        let newIndex = min(max(index + offset, 0), search.results.count - 1)
        session?.search?.selectedID = search.results[newIndex].id
        renderSearch()
    }

    private func reveal() {
        guard let session else { return }
        // While the leader modifiers are held down the user is flicking, not
        // browsing: stay hidden and reveal on release instead.
        if NSEvent.modifierFlags.contains(effectiveLeaderKey().cocoaModifiers) {
            session.revealPending = true
            return
        }
        makeVisible()
    }

    private func makeVisible() {
        guard let session else { return }

        session.revealPending = false
        let panel = session.panel
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

    /// All open-panel state is in the session, so this resets all of it.
    private func hide() {
        guard let session else { return }

        self.session = nil
        session.revealWork?.cancel()
        session.panel.orderOut(nil)
    }

    private func launch(_ binding: CustomBinding) {
        hide()

        guard let url = locateApp(for: binding) else {
            showLaunchError(for: binding, message: "Oriel could not find this app. Remove the binding and add it again.")
            return
        }

        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { @Sendable [weak self] _, error in
            guard let error else { return }

            DispatchQueue.main.async {
                self?.showLaunchError(for: binding, message: error.localizedDescription)
            }
        }
    }

    /// The saved path is the copy that the user chose. If the app moved
    /// after that, macOS can still find it from its bundle identifier.
    /// The new path is then saved, which also repairs the app icon.
    private func locateApp(for binding: CustomBinding) -> URL? {
        if FileManager.default.fileExists(atPath: binding.appPath) {
            return URL(fileURLWithPath: binding.appPath)
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: binding.bundleID) else {
            return nil
        }

        CustomBindingsStore.shared.updateAppPath(url.path, forBundleID: binding.bundleID)
        return url
    }

    private func showLaunchError(for binding: CustomBinding, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Oriel could not open \(binding.appName)"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func select(_ row: SwitcherRow) {
        hideAndFocus(row.window)
    }

    private func open(_ result: SearchResult) {
        switch result {
        case let .window(window):
            hideAndFocus(window)
        case let .closedApp(binding):
            launch(binding)
        }
    }

    /// hide() drops the session, so read the screen before the panel closes.
    private func hideAndFocus(_ window: WindowInfo) {
        let screen = session?.screen
        hide()
        focus(window, panelScreen: screen)
    }

    /// Switch focus but keep the session alive: the target app takes key
    /// status when it activates, so reclaim it for the panel (nonactivating
    /// panels may hold key while another app stays active) unless the leader
    /// modifiers were released in the gap.
    private func flick(to row: SwitcherRow) {
        guard let session else { return }

        session.isFlicking = true
        focus(row.window, panelScreen: session.screen)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let panel = self.session?.panel else { return }
            if NSEvent.modifierFlags.contains(effectiveLeaderKey().cocoaModifiers) {
                panel.makeKey()
            } else {
                self.hide()
            }
        }
    }

    private func focus(_ window: WindowInfo, panelScreen: NSScreen?) {
        usageHistory.record(window.key)
        let moveTarget = AppPreferences.bringToCurrentScreen() ? panelScreen : nil
        let maximize = AppPreferences.maximizeOnFocus()
        WindowManager.focus(window, movingTo: moveTarget, maximizing: maximize)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard let session else { return false }

        if let search = session.search {
            return handleSearchKey(event, search: search)
        }
        if event.isARepeat {
            return true
        }
        if event.keyCode == UInt16(kVK_Escape) {
            hide()
            return true
        }
        guard let letter = event.charactersIgnoringModifiers?.lowercased().first else { return false }
        // Letters pressed with the leader modifiers still held flick between
        // windows without closing; a plain letter selects and closes.
        let leaderFlags = effectiveLeaderKey().cocoaModifiers
        let holdingLeader = !leaderFlags.isEmpty && event.modifierFlags.contains(leaderFlags)
        guard holdingLeader || !event.modifierFlags.contains(.command) else { return false }

        if let row = session.rows.first(where: { $0.letter == letter }) {
            holdingLeader ? flick(to: row) : select(row)
            return true
        }
        if let binding = session.closedApps.first(where: { $0.letter == letter }) {
            launch(binding)
            return true
        }
        return false
    }

    /// Search takes every key, so keys such as Tab do not beep. It ignores
    /// Command and Option: the user can still hold the leader modifiers
    /// when they start to type, and Option types special letters.
    private func handleSearchKey(_ event: NSEvent, search: SearchState) -> Bool {
        let flags = event.modifierFlags
        let plainKey = event.charactersIgnoringModifiers?.lowercased()

        switch Int(event.keyCode) {
        case kVK_Escape:
            search.query.isEmpty ? hide() : setSearchQuery("")
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let result = search.results.first(where: { $0.id == search.selectedID }) {
                open(result)
            }
        case kVK_DownArrow:
            moveSelection(by: 1)
        case kVK_UpArrow:
            moveSelection(by: -1)
        case kVK_Delete:
            if search.query.isEmpty {
                stopSearch()
            } else if flags.contains(.option) {
                setSearchQuery(SearchText.deletingLastWord(search.query))
            } else {
                setSearchQuery(String(search.query.dropLast()))
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

            let ignoresModifiers = !flags.isDisjoint(with: [.command, .option])
            let characters = ignoresModifiers ? event.charactersIgnoringModifiers : event.characters
            guard let text = SearchText.typedText(characters) else { return true }

            setSearchQuery(search.query + text)
        }
        return true
    }

    private func handleFlags(_ event: NSEvent) {
        guard let session, !event.modifierFlags.contains(effectiveLeaderKey().cocoaModifiers) else { return }

        if session.isFlicking {
            hide()
        } else if session.revealPending {
            reveal()
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // During a flick the focused app steals key; take it back rather than
        // closing, as long as the leader modifiers are still held.
        if let session, session.isFlicking, NSEvent.modifierFlags.contains(effectiveLeaderKey().cocoaModifiers) {
            DispatchQueue.main.async { [weak self] in self?.session?.panel.makeKey() }
            return
        }
        hide()
    }
}

/// The state that exists only while the panel is open. The controller
/// drops it when the panel closes, so no value stays from one session
/// to the next.
private final class SwitcherSession {
    let panel: SwitcherPanel
    let screen: NSScreen?
    let shownAt: TimeInterval
    var revealWork: DispatchWorkItem?
    // True once a window was selected with the leader modifiers still held:
    // the panel stays up so further letters keep switching, until release.
    var isFlicking = false
    // The reveal delay elapsed while the leader modifiers were still held;
    // show the panel when they're released instead.
    var revealPending = false
    var hostingView: NSHostingView<SwitcherView>?
    var windows: [WindowInfo] = []
    var rows: [SwitcherRow] = []
    var closedApps: [CustomBinding] = []
    // Nil when the panel shows the letter list.
    var search: SearchState?

    init(panel: SwitcherPanel, screen: NSScreen?, shownAt: TimeInterval) {
        self.panel = panel
        self.screen = screen
        self.shownAt = shownAt
    }
}

private struct SearchState {
    let panelSize: CGSize
    var query = ""
    var results: [SearchResult] = []
    var selectedID: SearchResultID?
    var hostingView: NSHostingView<SwitcherSearchView>?
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
