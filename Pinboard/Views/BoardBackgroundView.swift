//
//  BoardBackgroundView.swift
//  Pinboard
//

import SwiftUI

struct BoardBackgroundView: View {
    let mode: BoardMode
    let showsGrid: Bool
    let gridSize: Double
    let backgroundStyle: BoardBackgroundStyle
    let viewport: CanvasViewport

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [backgroundStyle.topColor, backgroundStyle.bottomColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [backgroundStyle.glowColor.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 720
            )

            if showsGrid {
                GridPattern(
                    spacing: gridSize,
                    color: backgroundStyle.gridColor,
                    viewport: viewport
                )
            }
        }
        .opacity(mode == .board ? 1 : 0)
        .animation(.easeInOut(duration: 0.28), value: mode)
        .animation(.easeInOut(duration: 0.24), value: backgroundStyle)
        .ignoresSafeArea()
    }
}

private struct GridPattern: View {
    let spacing: Double
    let color: Color
    let viewport: CanvasViewport

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let worldStep = max(CGFloat(spacing), 8)
            let scaledStep = worldStep * viewport.scale
            let skippedLines = max(1, ceil(10 / scaledStep))
            let step = scaledStep * skippedLines
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let worldOrigin = CGPoint(
                x: center.x + viewport.offset.width - center.x * viewport.scale,
                y: center.y + viewport.offset.height - center.y * viewport.scale
            )
            let startX = positiveRemainder(worldOrigin.x, divisor: step)
            let startY = positiveRemainder(worldOrigin.y, divisor: step)

            stride(from: startX, through: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: startY, through: size.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(color), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private func positiveRemainder(_ value: CGFloat, divisor: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
