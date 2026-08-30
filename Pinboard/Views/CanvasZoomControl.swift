//
//  CanvasZoomControl.swift
//  Pinboard
//

import SwiftUI

struct CanvasZoomControl: View {
    let scale: CGFloat
    let onZoomOut: () -> Void
    let onReset: () -> Void
    let onZoomIn: () -> Void

    var body: some View {
        surface
            .font(.system(size: 12, weight: .semibold))
    }

    @ViewBuilder
    private var surface: some View {
        let content = HStack(spacing: 2) {
            zoomButton(
                systemImage: "minus",
                label: "Zoom out",
                isEnabled: scale > CanvasViewport.minimumScale + 0.001,
                action: onZoomOut
            )
            .keyboardShortcut("-", modifiers: .command)

            Button(action: onReset) {
                Text(percentage)
                    .monospacedDigit()
                    .frame(width: 48, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary.opacity(0.76))
            .accessibilityLabel("Reset zoom to 100 percent")
            .accessibilityIdentifier("canvas-zoom-reset")
            .help("Reset zoom (⌘0)")
            .keyboardShortcut("0", modifiers: .command)

            zoomButton(
                systemImage: "plus",
                label: "Zoom in",
                isEnabled: scale < CanvasViewport.maximumScale - 0.001,
                action: onZoomIn
            )
            .keyboardShortcut("+", modifiers: .command)
        }
        .padding(4)

        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
    }

    private func zoomButton(
        systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(isEnabled ? 0.76 : 0.28))
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(
            label == "Zoom out" ? "canvas-zoom-out" : "canvas-zoom-in"
        )
        .help(label)
    }

    private var percentage: String {
        "\(Int((scale * 100).rounded()))%"
    }
}
