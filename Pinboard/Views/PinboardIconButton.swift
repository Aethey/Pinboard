//
//  PinboardIconButton.swift
//  Pinboard
//

import SwiftUI

struct PinboardIconButton: View {
    enum Emphasis {
        case standard
        case active
        case destructive
    }

    let systemImage: String
    let accessibilityLabel: String
    let help: String
    var emphasis: Emphasis = .standard
    var size: CGFloat = PinboardTheme.Controls.cardButtonSize
    var glyphSize: CGFloat = PinboardTheme.Controls.cardGlyphSize
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(
            role: emphasis == .destructive ? .destructive : nil,
            action: action
        ) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: glyphSize, weight: .medium))
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }

    private var foregroundColor: Color {
        switch emphasis {
        case .standard:
            .primary.opacity(isHovering ? 0.96 : 0.72)
        case .active:
            PinboardTheme.selection.opacity(isHovering ? 1 : 0.88)
        case .destructive:
            isHovering ? .red.opacity(0.88) : .primary.opacity(0.52)
        }
    }
}
