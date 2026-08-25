//
//  SwitcherPanelController.swift
//  switchr
//
//  A Spotlight-style non-activating panel: it takes key presses without
//  activating this app, so dismissing returns you to where you were.
//

import AppKit
import SwiftUI

final class SwitcherPanelController: NSObject, NSWindowDelegate {
    private var panel: SwitcherPanel?
    private var panelScreen: NSScreen?
    private var revealWork: DispatchWorkItem?
    // True once a window was selected with the leader modifiers still held:
    // the panel stays up so further letters keep switching, until release.
    private var isFlicking = false
    // The reveal delay elapsed while the leader modifiers were still held;
    // show the panel when they're released instead.
    private var revealPending = false
    private var rows: [SwitcherRow] = []
    private var closedApps: [CustomBinding] = []
    private let letterAssigner = LetterAssigner()

    func toggle() {
        if panel != nil {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let targetScreen = NSScreen.main
        let panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 1),
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

        panelScreen = targetScreen
        self.panel = panel

        // Take keyboard focus before listing windows. Key events from a fast
        // leader roll then wait for Switchr instead of reaching the old app.
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        let windows = WindowManager.listWindows()
        rows = letterAssigner.assign(to: windows)

        // Bound apps with no open windows appear in the closed pinned section.
        // Their key launches or reactivates the app.
        let showClosed = UserDefaults.standard.object(forKey: PrefKey.showClosedApps) as? Bool ?? true
        if showClosed {
            let openBundleIDs = Set(windows.compactMap { $0.app.bundleIdentifier })
            closedApps = CustomBindingsStore.shared.bindings.filter { !openBundleIDs.contains($0.bundleID) }
        } else {
            closedApps = []
        }

        let boundBundleIDs = Set(CustomBindingsStore.shared.bindings.map(\.bundleID))
        let pinnedRows = rows.filter {
            guard let bundleID = $0.window.app.bundleIdentifier else { return false }
            return boundBundleIDs.contains(bundleID)
        }
        let otherRows = rows.filter {
            guard let bundleID = $0.window.app.bundleIdentifier else { return true }
            return !boundBundleIDs.contains(bundleID)
        }

        let view = SwitcherView(
            pinnedRows: pinnedRows,
            otherRows: otherRows,
            closedApps: closedApps,
            hasPermission: WindowManager.hasAccessibilityPermission,
            onSelect: { [weak self] row in self?.select(row) },
            onLaunch: { [weak self] binding in self?.launch(binding) }
        )
        let hosting = NSHostingView(rootView: view)
        let contentSize = hosting.fittingSize
        panel.setContentSize(contentSize)
        hosting.frame.size = contentSize
        panel.contentView = hosting

        if let targetScreen {
            let origin = NSPoint(
                x: targetScreen.visibleFrame.midX - contentSize.width / 2,
                y: targetScreen.visibleFrame.midY - contentSize.height / 2
            )
            panel.setFrameOrigin(origin)
        }

        // The panel stays invisible for a beat. A fast leader and letter
        // switches without showing it; it appears only after a short pause.
        let defaults = UserDefaults.standard
        let configuredDelay = defaults.object(forKey: PrefKey.revealDelayMilliseconds) == nil
            ? 100
            : defaults.integer(forKey: PrefKey.revealDelayMilliseconds)
        let revealDelay = Double(min(max(configuredDelay, 0), 1_000)) / 1_000
        let work = DispatchWorkItem { [weak self] in self?.reveal() }
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay, execute: work)
    }

    private func reveal() {
        guard let panel else { return }
        // While the leader modifiers are held down the user is flicking, not
        // browsing: stay hidden and reveal on release instead.
        if NSEvent.modifierFlags.contains(LeaderKey.current.cocoaModifiers) {
            revealPending = true
            return
        }
        revealPending = false
        let animate = UserDefaults.standard.object(forKey: PrefKey.animatePanel) as? Bool ?? true
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
        panel?.orderOut(nil)
        panel = nil
        panelScreen = nil
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
        focus(row)
    }

    /// Switch focus but keep the session alive: the target app takes key
    /// status when it activates, so reclaim it for the panel (nonactivating
    /// panels may hold key while another app stays active) unless the leader
    /// modifiers were released in the gap.
    private func flick(to row: SwitcherRow) {
        isFlicking = true
        focus(row)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let panel = self.panel else { return }
            if NSEvent.modifierFlags.contains(LeaderKey.current.cocoaModifiers) {
                panel.makeKey()
            } else {
                self.hide()
            }
        }
    }

    private func focus(_ row: SwitcherRow) {
        let moveTarget = UserDefaults.standard.bool(forKey: PrefKey.bringToCurrentScreen)
            ? panelScreen
            : nil
        let maximize = UserDefaults.standard.bool(forKey: PrefKey.maximizeOnFocus)
        WindowManager.focus(row.window, movingTo: moveTarget, maximizing: maximize)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
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
