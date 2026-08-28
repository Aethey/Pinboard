//
//  BoardToolbar.swift
//  Pinboard
//

import SwiftUI

struct BoardToolbar: View {
    let mode: BoardMode
    let snapToGrid: Bool
    let activeBoard: PinboardBoard?
    let boards: [PinboardBoard]
    let onCreateBoard: () -> Void
    let onSelectBoard: (PinboardBoard) -> Void
    let onRenameBoard: (String) -> Void
    let onAddText: () -> Void
    let onAddMarkdown: () -> Void
    let onImportImage: () -> Void
    let onToggleGrid: () -> Void
    let onToggleMode: () -> Void

    @State private var isEditingBoardName = false
    @State private var boardNameDraft = ""
    @FocusState private var isBoardNameFocused: Bool

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
        .onChange(of: activeBoard?.id) {
            isEditingBoardName = false
            isBoardNameFocused = false
            boardNameDraft = activeBoard?.name ?? "Pinboard"
        }
        .onChange(of: isBoardNameFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                commitBoardName()
            }
        }
    }

    private var brand: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .foregroundStyle(PinboardTheme.selection)

            HStack(spacing: 2) {
                boardName

                if activeBoard != nil {
                    boardControl
                }
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var boardName: some View {
        if isEditingBoardName {
            TextField("Board name", text: $boardNameDraft)
                .textFieldStyle(.plain)
                .fontWeight(.semibold)
                .focused($isBoardNameFocused)
                .onSubmit(commitBoardName)
                .onExitCommand(perform: cancelBoardNameEditing)
                .frame(width: 104, alignment: .leading)
        } else {
            Text(activeBoard?.name ?? "Pinboard")
                .fontWeight(.semibold)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: beginBoardNameEditing)
                .help("Double-click to rename Board")
        }
    }

    @ViewBuilder
    private var boardControl: some View {
        if boards.count <= 1 {
            PinboardIconButton(
                systemImage: "rectangle.stack.badge.plus",
                accessibilityLabel: "New Board",
                help: "New Board",
                size: PinboardTheme.Controls.toolbarButtonSize,
                glyphSize: PinboardTheme.Controls.toolbarGlyphSize,
                action: onCreateBoard
            )
        } else {
            Menu {
                ForEach(boards) { board in
                    Button {
                        onSelectBoard(board)
                    } label: {
                        if board.id == activeBoard?.id {
                            Label(board.name, systemImage: "checkmark")
                        } else {
                            Text(board.name)
                        }
                    }
                }

                Divider()

                Button(action: onCreateBoard) {
                    Label("New Board", systemImage: "plus")
                }
            } label: {
                Image(systemName: "rectangle.stack")
                    .symbolRenderingMode(.monochrome)
                    .font(.system(
                        size: PinboardTheme.Controls.toolbarGlyphSize,
                        weight: .medium
                    ))
                    .frame(
                        width: PinboardTheme.Controls.toolbarButtonSize,
                        height: PinboardTheme.Controls.toolbarButtonSize
                    )
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .foregroundStyle(.primary.opacity(0.72))
            .accessibilityLabel("Switch Board")
            .help("Switch Board")
        }
    }

    private func beginBoardNameEditing() {
        guard let activeBoard else { return }
        boardNameDraft = activeBoard.name
        isEditingBoardName = true
        isBoardNameFocused = true
    }

    private func commitBoardName() {
        guard isEditingBoardName else { return }
        onRenameBoard(boardNameDraft)
        isEditingBoardName = false
        isBoardNameFocused = false
    }

    private func cancelBoardNameEditing() {
        isEditingBoardName = false
        isBoardNameFocused = false
        boardNameDraft = activeBoard?.name ?? "Pinboard"
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
