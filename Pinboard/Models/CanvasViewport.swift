//
//  CanvasViewport.swift
//  Pinboard
//

import CoreGraphics
import Foundation

struct CanvasViewport: Equatable {
    static let minimumScale: CGFloat = 0.25
    static let maximumScale: CGFloat = 2.5
    static let defaultValue = CanvasViewport(scale: 1, offset: .zero)

    var scale: CGFloat
    var offset: CGSize

    init(scale: CGFloat, offset: CGSize) {
        self.scale = Self.clampedScale(scale)
        self.offset = offset
    }

    init(board: PinboardBoard) {
        self.init(
            scale: CGFloat(board.viewportScale),
            offset: CGSize(
                width: CGFloat(board.viewportOffsetX),
                height: CGFloat(board.viewportOffsetY)
            )
        )
    }

    func worldPoint(for screenPoint: CGPoint, in viewportSize: CGSize) -> CGPoint {
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        return CGPoint(
            x: center.x + (screenPoint.x - center.x - offset.width) / scale,
            y: center.y + (screenPoint.y - center.y - offset.height) / scale
        )
    }

    func screenPoint(for worldPoint: CGPoint, in viewportSize: CGSize) -> CGPoint {
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        return CGPoint(
            x: center.x + offset.width + (worldPoint.x - center.x) * scale,
            y: center.y + offset.height + (worldPoint.y - center.y) * scale
        )
    }

    func visibleWorldRect(in viewportSize: CGSize, overscan: CGFloat = 0) -> CGRect {
        let topLeft = worldPoint(
            for: CGPoint(x: -overscan, y: -overscan),
            in: viewportSize
        )
        let bottomRight = worldPoint(
            for: CGPoint(
                x: viewportSize.width + overscan,
                y: viewportSize.height + overscan
            ),
            in: viewportSize
        )
        return CGRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: abs(bottomRight.x - topLeft.x),
            height: abs(bottomRight.y - topLeft.y)
        )
    }

    func screenRect(for worldRect: CGRect, in viewportSize: CGSize) -> CGRect {
        let origin = screenPoint(for: worldRect.origin, in: viewportSize)
        return CGRect(
            x: origin.x,
            y: origin.y,
            width: worldRect.width * scale,
            height: worldRect.height * scale
        )
    }

    func translated(by translation: CGSize) -> CanvasViewport {
        CanvasViewport(
            scale: scale,
            offset: CGSize(
                width: offset.width + translation.width,
                height: offset.height + translation.height
            )
        )
    }

    func centered(on worldPoint: CGPoint, in viewportSize: CGSize) -> CanvasViewport {
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        return CanvasViewport(
            scale: scale,
            offset: CGSize(
                width: -(worldPoint.x - center.x) * scale,
                height: -(worldPoint.y - center.y) * scale
            )
        )
    }

    func zoomed(
        to proposedScale: CGFloat,
        around screenPoint: CGPoint,
        in viewportSize: CGSize
    ) -> CanvasViewport {
        let newScale = Self.clampedScale(proposedScale)
        guard abs(newScale - scale) > 0.0001 else { return self }

        let worldAnchor = worldPoint(for: screenPoint, in: viewportSize)
        let center = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let newOffset = CGSize(
            width: screenPoint.x - center.x - (worldAnchor.x - center.x) * newScale,
            height: screenPoint.y - center.y - (worldAnchor.y - center.y) * newScale
        )
        return CanvasViewport(scale: newScale, offset: newOffset)
    }

    private static func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumScale), maximumScale)
    }
}

struct BoardFocusRequest: Equatable {
    let id: UUID
    let boardID: UUID
    let worldPoint: CGPoint
}
