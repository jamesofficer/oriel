//
//  WindowCache.swift
//  Oriel
//
//  Keeps a recent window list, so the switcher opens without waiting
//  for slow apps. It lists again in the background when apps change.
//

import AppKit

final class WindowCache {
    private(set) var windows: [WindowInfo]?
    var onChange: (() -> Void)?

    private let listWindows: @Sendable () -> [WindowInfo]
    private var isRefreshing = false
    private var needsRefresh = false
    private var observers: [NSObjectProtocol] = []

    init(listWindows: @escaping @Sendable () -> [WindowInfo] = WindowManager.listWindows) {
        self.listWindows = listWindows
    }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        refresh()
    }

    /// A request that comes in while a listing runs is not lost. It
    /// starts one more listing after the current one is done.
    func refresh() {
        if isRefreshing {
            needsRefresh = true
            return
        }

        isRefreshing = true
        let listWindows = listWindows
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let windows = listWindows()
            DispatchQueue.main.async {
                self?.finishRefresh(with: windows)
            }
        }
    }

    private func finishRefresh(with windows: [WindowInfo]) {
        self.windows = windows
        isRefreshing = false
        onChange?()

        if needsRefresh {
            needsRefresh = false
            refresh()
        }
    }
}
