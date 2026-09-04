//
//  BoardToolbar.swift
//  Pinboard
//

import AppKit
import SwiftUI

extension HorizontalAlignment {
    private enum BoardCreationControlsAlignment: AlignmentID {
        static func defaultValue(in dimensions: ViewDimensions) -> CGFloat {
            dimensions[.leading]
        }
    }

    static let boardCreationControls = HorizontalAlignment(BoardCreationControlsAlignment.self)
}

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
    let onImportPDF: () -> Void
    let onAddLink: (URL) -> Void
    let onToggleGrid: () -> Void
    let onResetZoom: () -> Void
    let onArrangeCards: () -> Void
    let onToggleMode: () -> Void

    @State private var isEditingBoardName = false
    @State private var boardNameDraft = ""
    @State private var isAddingLink = false
    @State private var linkDraft = ""
    @FocusState private var isBoardNameFocused: Bool
    @FocusState private var isLinkFieldFocused: Bool

    var body: some View {
        primaryToolbar
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

    private var primaryToolbar: some View {
        HStack(spacing: 10) {
            brand

            Divider()
                .frame(height: 22)

            HStack(spacing: 2) {
                kindButton(.text, action: onAddText)
                kindButton(.markdown, action: onAddMarkdown)
                kindButton(.image, action: onImportImage)
                kindButton(.pdf, action: onImportPDF)
                kindButton(.link, action: beginLinkEntry)
                    .popover(isPresented: $isAddingLink, arrowEdge: .top) {
                        linkEntryPopover
                    }
            }
            .alignmentGuide(.boardCreationControls) { dimensions in
                dimensions[.leading]
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

            PinboardIconButton(
                systemImage: "1.magnifyingglass",
                accessibilityLabel: "Reset zoom to 100%",
                help: "Reset zoom to 100% (⌘0)",
                size: PinboardTheme.Controls.toolbarButtonSize,
                glyphSize: PinboardTheme.Controls.toolbarGlyphSize,
                action: onResetZoom
            )

            PinboardIconButton(
                systemImage: "rectangle.grid.2x2",
                accessibilityLabel: "Arrange cards",
                help: "Arrange all cards",
                size: PinboardTheme.Controls.toolbarButtonSize,
                glyphSize: PinboardTheme.Controls.toolbarGlyphSize,
                action: onArrangeCards
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
                    .accessibilityIdentifier("board-\(board.id.uuidString)")
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
            .accessibilityIdentifier("board-switcher")
            .help("Switch Board")
        }
    }

    private func beginBoardNameEditing() {
        guard let activeBoard else { return }
        boardNameDraft = activeBoard.name
        isEditingBoardName = true
        isBoardNameFocused = true
    }

    private var linkEntryPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Link")
                .font(.system(size: 13, weight: .semibold))

            TextField("https://example.com", text: $linkDraft)
                .textFieldStyle(.roundedBorder)
                .focused($isLinkFieldFocused)
                .onSubmit(commitLink)
                .onExitCommand {
                    isAddingLink = false
                }

            HStack {
                Text("Paste any public webpage or video URL.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    isAddingLink = false
                }

                Button("Add", action: commitLink)
                    .keyboardShortcut(.defaultAction)
                    .disabled(preparedLinkURL == nil)
            }
        }
        .padding(14)
        .frame(width: 380)
    }

    private func beginLinkEntry() {
        if let clipboardText = NSPasteboard.general.string(forType: .string),
           normalizedWebURL(from: clipboardText) != nil {
            linkDraft = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            linkDraft = ""
        }
        isAddingLink = true
        Task { @MainActor in
            isLinkFieldFocused = true
        }
    }

    private var preparedLinkURL: URL? {
        normalizedWebURL(from: linkDraft)
    }

    private func commitLink() {
        guard let url = preparedLinkURL else { return }
        onAddLink(url)
        isAddingLink = false
        linkDraft = ""
    }

    private func normalizedWebURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else {
            return nil
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host() != nil
        else { return nil }
        return url
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
        .accessibilityIdentifier("toolbar-add-\(kind.rawValue)")
        .help("New \(kind.title) card")
    }
}

struct BoardSelectionToolbar: View {
    let selectionCount: Int
    let editableSelectionCount: Int
    let selectedFontSize: CardFontSize?
    let onSetFontSize: (CardFontSize) -> Void
    let onFitSelectionToContent: () -> Void

    var body: some View {
        if #available(macOS 26.0, *) {
            controls
                .glassEffect(.regular, in: .capsule)
        } else {
            controls
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
    }

    private var controls: some View {
        HStack(spacing: 7) {
            Text("\(selectionCount) selected")
                .foregroundStyle(.secondary)

            Divider()
                .frame(height: 12)

            Menu {
                ForEach(CardFontSize.allCases) { fontSize in
                    Button {
                        onSetFontSize(fontSize)
                    } label: {
                        if selectedFontSize == fontSize {
                            Label(fontSize.title, systemImage: "checkmark")
                        } else {
                            Text(fontSize.title)
                        }
                    }
                }
            } label: {
                Label(selectedFontSize?.title ?? "Font size", systemImage: "textformat.size")
                    .font(.system(size: 10.5, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(editableSelectionCount == 0)
            .help(
                editableSelectionCount == 0
                    ? "The selection has no editable text cards"
                    : "Change font size for \(editableSelectionCount) selected text cards"
            )

            Divider()
                .frame(height: 12)

            Button(action: onFitSelectionToContent) {
                Label("Fit content", systemImage: "rectangle.expand.vertical")
                    .font(.system(size: 10.5, weight: .medium))
                    .padding(.horizontal, 3)
                    .frame(height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(editableSelectionCount == 0)
            .accessibilityIdentifier("selection-fit-content")
            .help(
                editableSelectionCount == 0
                    ? "The selection has no resizable text cards"
                    : "Resize \(editableSelectionCount) selected text cards to show all content"
            )
        }
        .font(.system(size: 10.5, weight: .medium))
        .padding(.horizontal, 10)
        .frame(height: 22)
    }
}
