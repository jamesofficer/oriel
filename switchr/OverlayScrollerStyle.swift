//
//  OverlayScrollerStyle.swift
//  switchr
//

import AppKit
import SwiftUI

struct OverlayScrollerStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ScrollerStyler()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollerStyler)?.applyOverlayStyle()
    }
}

private final class ScrollerStyler: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyOverlayStyle()
        DispatchQueue.main.async { [weak self] in self?.applyOverlayStyle() }
    }

    func applyOverlayStyle() {
        guard let root = window?.contentView else { return }
        Self.overlayScrollers(in: root)
    }

    private static func overlayScrollers(in view: NSView) {
        if let scrollView = view as? NSScrollView {
            scrollView.scrollerStyle = .overlay
        }
        for subview in view.subviews {
            overlayScrollers(in: subview)
        }
    }
}
