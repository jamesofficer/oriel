//
//  WindowManager.swift
//  Oriel
//
//  Enumerates and focuses other apps' windows via the Accessibility API.
//  Requires the Accessibility permission and a non-sandboxed build.
//

import AppKit
import ApplicationServices

nonisolated struct WindowInfo {
    let app: NSRunningApplication
    let axWindow: AXUIElement
    let title: String
    let isMinimized: Bool

    var appName: String { app.localizedName ?? "Unknown" }
    var displayTitle: String { title.isEmpty ? appName : title }
    var key: WindowKey { WindowKey(element: axWindow) }
}

/// Identifies the same real window across window lists, as each
/// list makes a new WindowInfo for every window.
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
        let appAttributes = [kAXWindowsAttribute, kAXMainWindowAttribute] as CFArray
        var appValuesRef: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(axApp, appAttributes, [], &appValuesRef) == .success,
              let appValues = appValuesRef as? [Any],
              appValues.count == 2,
              var windows = appValues[0] as? [AXUIElement] else { return [] }

        // An app lists only its windows on the Spaces that show now, but
        // it gives its main window from all Spaces. Thus an app that is
        // full screen or on a different desktop stays in the list.
        let mainWindow = appValues[1] as CFTypeRef

        if CFGetTypeID(mainWindow) == AXUIElementGetTypeID(), !windows.contains(where: { CFEqual($0, mainWindow) }) {
            windows.append(mainWindow as! AXUIElement)
        }

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

    /// A busy app answers each request late. The requests run on this
    /// queue, in the order they were made, so Oriel does not wait.
    private static let requestQueue = DispatchQueue(label: "Oriel.WindowManager.requests", qos: .userInteractive)

    static func focus(_ window: WindowInfo, movingTo screen: NSScreen? = nil, maximizing: Bool = false) {
        // Read the screens here, on the main thread, in AX coordinates.
        let target = screen.map { axRect(from: $0.visibleFrame) }
        let screens = NSScreen.screens.map { axRect(from: $0.visibleFrame) }
        let mainScreen = NSScreen.main.map { axRect(from: $0.visibleFrame) }

        requestQueue.async {
            // The window list can be out of date, so do not trust isMinimized.
            AXUIElementSetAttributeValue(window.axWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)

            if maximizing {
                maximize(window, on: target, screens: screens, fallback: mainScreen)
            } else if let target {
                move(window, to: target, screens: screens)
            }
            AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(window.axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

            // Setting AXFrontmost works from a background app where cooperative
            // activation can be refused; NSRunningApplication.activate is a backup.
            let axApp = AXUIElementCreateApplication(window.app.processIdentifier)
            AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            window.app.activate()
        }
    }

    /// Moves the main window of the app, which is the window the user works
    /// in. The sound tells the user that the window cannot take the move.
    static func place(_ target: WindowPlacement.Target, repeatCount: Int, mainWindowOf app: NSRunningApplication) {
        let screens = NSScreen.screens.map { axRect(from: $0.visibleFrame) }

        requestQueue.async {
            guard let window = mainWindow(of: app),
                  !isFullScreen(window),
                  let frame = axFrame(of: window),
                  let placement = WindowPlacement.frame(
                      for: target,
                      repeatCount: repeatCount,
                      windowFrame: frame,
                      screens: screens
                  ) else {
                DispatchQueue.main.async { NSSound.beep() }
                return
            }

            setFrame(of: window, from: frame, to: placement.frame, on: placement.screen)
        }
    }

    nonisolated private static func mainWindow(of app: NSRunningApplication) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }

        return (value as! AXUIElement)
    }

    /// Resizes a window to fill the visible frame (edge to edge, below the
    /// menu bar and above the Dock) of the given screen, or of the screen the
    /// window is currently on. This is a plain resize, not macOS full screen.
    nonisolated private static func maximize(
        _ window: WindowInfo,
        on target: CGRect?,
        screens: [CGRect],
        fallback: CGRect?
    ) {
        guard !isFullScreen(window.axWindow), let frame = axFrame(of: window.axWindow) else { return }
        let destination = target
            ?? screens.first { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }
            ?? fallback
        guard let destination else { return }

        setFrame(of: window.axWindow, from: frame, to: destination, on: destination)
    }

    /// When the window is crossing screens, apps clamp the size request to
    /// the screen the window is still on, so one position+size pass lands
    /// the move but keeps the old screen's size. Reapply until the frame
    /// settles. An app can also refuse the size (a window with a minimum
    /// size), and the window is then moved to be fully on the screen.
    nonisolated private static func setFrame(
        of element: AXUIElement,
        from frame: CGRect,
        to destination: CGRect,
        on screen: CGRect
    ) {
        guard !roughlyEqual(frame, destination) else { return }

        var current = frame

        for _ in 0..<3 {
            setFrame(element, destination)
            guard let newFrame = axFrame(of: element) else { return }

            current = newFrame

            if roughlyEqual(current, destination) {
                return
            }
        }

        var origin = WindowPlacement.frame(current, keptInside: screen).origin

        if origin != current.origin, let positionValue = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        }
    }

    nonisolated private static func setFrame(_ element: AXUIElement, _ rect: CGRect) {
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
    nonisolated private static func roughlyEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1
            && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }

    /// Moves a window onto the given screen, preserving its position relative
    /// to its current screen's visible area (a window in the top-right corner
    /// of one monitor lands in the top-right of the target monitor).
    nonisolated private static func move(_ window: WindowInfo, to destination: CGRect, screens: [CGRect]) {
        guard !isFullScreen(window.axWindow), let frame = axFrame(of: window.axWindow) else { return }
        guard !destination.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return }

        let source = screens.first { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) } ?? frame

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

    /// A full-screen window fills its own Space, so it must keep its frame.
    nonisolated private static func isFullScreen(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value)
        return value as? Bool ?? false
    }

    nonisolated private static func axFrame(of element: AXUIElement) -> CGRect? {
        var position = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue = axValue(of: element, kAXPositionAttribute),
              let sizeValue = axValue(of: element, kAXSizeAttribute),
              AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Swift cannot check a cast to a Core Foundation type, so
    /// compare the type identifier before the forced cast.
    nonisolated private static func axValue(of element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }

        return (value as! AXValue)
    }
}
