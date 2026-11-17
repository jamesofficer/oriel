//
//  WindowFrameHistory.swift
//  Oriel
//
//  Remembers the frames that one window had before each move, so
//  the moves can be undone. It keeps the last moved window only.
//

import CoreGraphics

nonisolated struct WindowFrameHistory<ID: Hashable> {
    private var window: ID?
    private var frames: [CGRect] = []

    mutating func record(_ frame: CGRect, for window: ID) {
        if self.window != window {
            self.window = window
            frames = []
        }

        frames.append(frame)
    }

    /// Nil means that there is no move of this window to undo.
    mutating func removeLastFrame(for window: ID) -> CGRect? {
        guard self.window == window else { return nil }

        return frames.popLast()
    }
}
