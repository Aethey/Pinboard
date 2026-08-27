//
//  BoardBackgroundView.swift
//  Pinboard
//

import SwiftUI

struct BoardBackgroundView: View {
    let mode: BoardMode
    let showsGrid: Bool
    let gridSize: Double

    var body: some View {
        ZStack {
            if mode == .board {
                LinearGradient(
                    colors: [PinboardTheme.canvasTop, PinboardTheme.canvasBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color.indigo.opacity(0.10), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 720
                )

                if showsGrid {
                    GridPattern(spacing: gridSize)
                }
            } else {
                Color.clear
            }
        }
        .ignoresSafeArea()
    }
}

private struct GridPattern: View {
    let spacing: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let step = max(CGFloat(spacing), 8)

            stride(from: CGFloat.zero, through: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }

            stride(from: CGFloat.zero, through: size.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            context.stroke(path, with: .color(.white.opacity(0.045)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

