//
//  WindowPlacement.swift
//  Oriel
//

import CoreGraphics

nonisolated enum WindowPlacement {
    enum Target: Equatable {
        case maximize
        case left
        case right
        case top
        case bottom
        case center
        case nextDisplay
        case previousDisplay
    }

    /// The part of the screen that a side target fills. Each
    /// repeat of the same target moves to the next part.
    private static let sideFractions: [CGFloat] = [1 / 2, 1 / 3, 2 / 3]

    /// Frames use Accessibility coordinates, where y increases downward.
    /// The result is nil only when there are no screens.
    static func frame(
        for target: Target,
        repeatCount: Int,
        windowFrame: CGRect,
        screens: [CGRect]
    ) -> (frame: CGRect, screen: CGRect)? {
        let ordered = screens.sorted { ($0.minX, $0.minY) < ($1.minX, $1.minY) }
        guard !ordered.isEmpty else { return nil }

        let windowCenter = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        let index = ordered.firstIndex { $0.contains(windowCenter) } ?? 0
        let screen = ordered[index]
        let fraction = sideFractions[repeatCount % sideFractions.count]
        let sideWidth = screen.width * fraction
        let sideHeight = screen.height * fraction

        switch target {
        case .maximize:
            return (screen, screen)
        case .left:
            return (CGRect(x: screen.minX, y: screen.minY, width: sideWidth, height: screen.height), screen)
        case .right:
            return (CGRect(x: screen.maxX - sideWidth, y: screen.minY, width: sideWidth, height: screen.height), screen)
        case .top:
            return (CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: sideHeight), screen)
        case .bottom:
            return (CGRect(x: screen.minX, y: screen.maxY - sideHeight, width: screen.width, height: sideHeight), screen)
        case .center:
            let width = min(windowFrame.width, screen.width)
            let height = min(windowFrame.height, screen.height)
            return (CGRect(x: screen.midX - width / 2, y: screen.midY - height / 2, width: width, height: height), screen)
        case .nextDisplay, .previousDisplay:
            let step = target == .nextDisplay ? 1 : ordered.count - 1
            let destination = ordered[(index + step) % ordered.count]
            return (destinationFrame(windowFrame: windowFrame, sourceFrame: screen, destinationFrame: destination), destination)
        }
    }

    /// Moves a frame the shortest distance that puts it fully on the screen.
    static func frame(_ frame: CGRect, keptInside screen: CGRect) -> CGRect {
        let x = max(screen.minX, min(frame.minX, screen.maxX - frame.width))
        let y = max(screen.minY, min(frame.minY, screen.maxY - frame.height))
        return CGRect(x: x, y: y, width: frame.width, height: frame.height)
    }

    static func destinationFrame(
        windowFrame: CGRect,
        sourceFrame: CGRect,
        destinationFrame: CGRect
    ) -> CGRect {
        var size = windowFrame.size
        size.width = min(size.width, destinationFrame.width)
        size.height = min(size.height, destinationFrame.height)

        let horizontalPosition = fraction(
            position: windowFrame.minX,
            minimum: sourceFrame.minX,
            freeSpace: sourceFrame.width - windowFrame.width
        )
        let verticalPosition = fraction(
            position: windowFrame.minY,
            minimum: sourceFrame.minY,
            freeSpace: sourceFrame.height - windowFrame.height
        )
        let origin = CGPoint(
            x: destinationFrame.minX + horizontalPosition * (destinationFrame.width - size.width),
            y: destinationFrame.minY + verticalPosition * (destinationFrame.height - size.height)
        )
        return CGRect(origin: origin, size: size)
    }

    private static func fraction(position: CGFloat, minimum: CGFloat, freeSpace: CGFloat) -> CGFloat {
        guard freeSpace > 0 else { return 0 }
        return max(0, min(1, (position - minimum) / freeSpace))
    }
}
