//
//  WindowPlacement.swift
//  Oriel
//

import CoreGraphics

enum WindowPlacement {
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
