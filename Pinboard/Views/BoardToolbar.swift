//
//  BoardToolbar.swift
//  Pinboard
//

import SwiftUI

struct BoardToolbar: View {
    let mode: BoardMode
    let snapToGrid: Bool
    let onAddText: () -> Void
    let onAddMarkdown: () -> Void
    let onImportImage: () -> Void
    let onToggleGrid: () -> Void
    let onToggleMode: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            brand

            Divider()
                .frame(height: 22)

            HStack(spacing: 2) {
                kindButton(.text, action: onAddText)
                kindButton(.markdown, action: onAddMarkdown)
                kindButton(.image, action: onImportImage)
            }

            Divider()
                .frame(height: 22)

            PinboardIconButton(
                systemImage: "square.grid.3x3",
                accessibilityLabel: snapToGrid ? "Disable grid snapping" : "Enable grid snapping",
                help: snapToGrid ? "Disable grid snapping" : "Enable grid snapping",
                emphasis: snapToGrid ? .active : .standard,
                size: PinboardTheme.Controls.toolbarButtonSize,
                glyphSize: PinboardTheme.Controls.toolbarGlyphSize,
                action: onToggleGrid
            )

            Button(action: onToggleMode) {
                HStack(spacing: 7) {
                    Image(systemName: mode.systemImage)
                    Text(mode.title)
                    Text("⌥ Space")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(PinboardTheme.selection.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Switch to Desktop mode")
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 20, y: 10)
    }

    private var brand: some View {
        HStack(spacing: 7) {
            Image(systemName: "pin.fill")
                .foregroundStyle(PinboardTheme.selection)
            Text("Pinboard")
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 4)
    }

    private func kindButton(_ kind: CardKind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CardKindIcon(
                kind: kind,
                size: PinboardTheme.Controls.toolbarKindIconSize,
                backgroundColor: .primary.opacity(0.07),
                foregroundColor: .primary.opacity(0.82),
                borderColor: .primary.opacity(0.16)
            )
            .frame(
                width: PinboardTheme.Controls.toolbarButtonSize,
                height: PinboardTheme.Controls.toolbarButtonSize
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New \(kind.title) card")
        .help("New \(kind.title) card")
    }
}
