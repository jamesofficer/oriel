//
//  WindowManager.swift
//  Oriel
//
//  Enumerates and focuses other apps' windows via the Accessibility API.
//  Requires the Accessibility permission and a non-sandboxed build.
//

import AppKit
import ApplicationServices

nonisolated struct WindowInfo: Identifiable {
    let id = UUID()
    let app: NSRunningApplication
    let axWindow: AXUIElement
    let title: String
    let isMinimized: Bool

    var appName: String { app.localizedName ?? "Unknown" }
    var displayTitle: String { title.isEmpty ? appName : title }
    var key: WindowKey { WindowKey(element: axWindow) }
}

/// Identifies the same real window across window lists, as each list
/// gives every WindowInfo a new id.
nonisolated struct WindowKey: Hashable {
    let element: AXUIElement

    static func == (lhs: WindowKey, rhs: WindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}

enum WindowManager {
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// All standard windows of regular apps, grouped per app, apps sorted by
    /// name so the list order is stable across invocations.
    nonisolated static func listWindows() -> [WindowInfo] {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != NSRunningApplication.current.processIdentifier }
            .sorted { ($0.localizedName ?? "") .localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }

        // Some apps take hundreds of milliseconds to answer each request
        // (an unfocused Godot editor sleeps between frames). Ask all
        // apps at the same time, so the slowest app sets the wait.
        var windowsPerApp = [[WindowInfo]](repeating: [], count: apps.count)
        windowsPerApp.withUnsafeMutableBufferPointer { buffer in
            // Safe: each index is written by exactly one iteration.
            nonisolated(unsafe) let buffer = buffer
            DispatchQueue.concurrentPerform(iterations: apps.count) { index in
                buffer[index] = standardWindows(of: apps[index])
            }
        }
        return windowsPerApp.flatMap { $0 }
    }

    /// Reads every window attribute in one request, as each request is a
    /// round trip to the app and slow apps make each one costly.
    nonisolated private static func standardWindows(of app: NSRunningApplication) -> [WindowInfo] {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }

        let attributes = [kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute] as CFArray
        return windows.compactMap { window in
            var valuesRef: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(window, attributes, [], &valuesRef) == .success,
                  let values = valuesRef as? [Any],
                  values.count == 3,
                  values[0] as? String == kAXStandardWindowSubrole else { return nil }

            return WindowInfo(
                app: app,
                axWindow: window,
                title: values[1] as? String ?? "",
                isMinimized: values[2] as? Bool ?? false
            )
        }
    }

    static func focus(_ window: WindowInfo, movingTo screen: NSScreen? = nil, maximizing: Bool = false) {
        // The window list can be out of date, so do not trust isMinimized.
        AXUIElementSetAttributeValue(window.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)

        if maximizing {
            maximize(window, on: screen)
        } else if let screen {
            move(window, to: screen)
        }
        AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(window.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

        // Setting AXFrontmost works from a background app where cooperative
        // activation can be refused; NSRunningApplication.activate is a backup.
        let axApp = AXUIElementCreateApplication(window.app.processIdentifier)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        window.app.activate()
    }

    /// Resizes a window to fill the visible frame (edge to edge, below the
    /// menu bar and above the Dock) of the given screen, or of the screen the
    /// window is currently on. This is a plain resize, not macOS full screen.
    private static func maximize(_ window: WindowInfo, on screen: NSScreen?) {
        guard let frame = axFrame(of: window.axWindow) else { return }
        let targetScreen = screen
            ?? NSScreen.screens.first { axRect(from: $0.visibleFrame).contains(CGPoint(x: frame.midX, y: frame.midY)) }
            ?? NSScreen.main
        guard let targetScreen else { return }

        let destination = axRect(from: targetScreen.visibleFrame)
        guard !roughlyEqual(frame, destination) else { return }

        // When the window is crossing screens, apps clamp the size request to
        // the screen the window is still on, so one position+size pass lands
        // the move but keeps the old screen's size. Reapply until the frame
        // settles (or the app refuses, e.g. a window with a maximum size).
        for _ in 0..<3 {
            setFrame(window.axWindow, destination)
            guard let current = axFrame(of: window.axWindow),
                  !roughlyEqual(current, destination) else { return }
        }
    }

    private static func setFrame(_ element: AXUIElement, _ rect: CGRect) {
        var origin = rect.origin
        var size = rect.size
        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    /// Apps report frames with sub-point offsets; treat anything within a
    /// point as arrived so the reapply loop doesn't fight over rounding.
    private static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1
            && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }

    /// Moves a window onto the given screen, preserving its position relative
    /// to its current screen's visible area (a window in the top-right corner
    /// of one monitor lands in the top-right of the target monitor).
    private static func move(_ window: WindowInfo, to screen: NSScreen) {
        guard let frame = axFrame(of: window.axWindow) else { return }
        let destination = axRect(from: screen.visibleFrame)
        guard !destination.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return }

        let source = NSScreen.screens
            .map { axRect(from: $0.visibleFrame) }
            .first { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }
            ?? frame

        let movedFrame = WindowPlacement.destinationFrame(
            windowFrame: frame,
            sourceFrame: source,
            destinationFrame: destination
        )
        var origin = movedFrame.origin
        var size = movedFrame.size

        if let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, positionValue)
        }
        if size != frame.size, let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    /// AX uses global coordinates with the origin at the primary screen's
    /// top-left, y increasing downward; Cocoa's origin is the bottom-left.
    private static func axRect(from cocoaRect: NSRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(
            x: cocoaRect.minX,
            y: primaryHeight - cocoaRect.maxY,
            width: cocoaRect.width,
            height: cocoaRect.height
        )
    }

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
}
