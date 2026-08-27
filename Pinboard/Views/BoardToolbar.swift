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
        HStack(spacing: 8) {
            brand

            Divider()
                .frame(height: 22)

            toolbarButton("Text", action: onAddText) {
                CardKindIcon(kind: .text)
            }
            toolbarButton("Markdown", action: onAddMarkdown) {
                CardKindIcon(kind: .markdown)
            }
            toolbarButton("Image", action: onImportImage) {
                Image(systemName: "photo.badge.plus")
                    .frame(width: 18, height: 18)
            }

            Divider()
                .frame(height: 22)

            Button(action: onToggleGrid) {
                Image(systemName: snapToGrid ? "grid.circle.fill" : "grid.circle")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .foregroundStyle(snapToGrid ? PinboardTheme.selection : .secondary)
            .help(snapToGrid ? "Disable grid snapping" : "Enable grid snapping")

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

    private func toolbarButton<Icon: View>(
        _ title: String,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        Button(action: action) {
            icon()
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help("New \(title) card")
    }
}
