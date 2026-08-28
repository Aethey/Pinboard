//
//  BoardCardView.swift
//  Pinboard
//

import SwiftUI

struct BoardCardView: View {
    private enum FocusedField: Hashable {
        case title
        case content
    }

    let card: BoardCard
    let mode: BoardMode
    let isSelected: Bool
    let snapToGrid: Bool
    let gridSize: Double
    let canvasSize: CGSize
    let onActivate: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var showsMarkdownPreview = true
    @State private var isEditingTitle = false
    @FocusState private var focusedField: FocusedField?
    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var resizeTranslation = CGSize.zero
    @GestureState private var isDraggingCard = false
    @GestureState private var isResizingCard = false

    private let noteMinimumWidth: Double = 300
    private let noteMinimumHeight: Double = 120
    private let noteTitleBarHeight = PinboardTheme.Controls.cardHeaderHeight
    private let imageMinimumWidth: Double = 80
    private let quickThemes: [CardTheme] = [.indigo, .teal, .amber, .rose]

    var body: some View {
        let displayedSize = displayedCardSize

        cardSurface
            .frame(width: displayedSize.width, height: displayedSize.height)
            .background(cardSurfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay(selectionOutline)
            .overlay(alignment: .bottomTrailing) {
                if mode == .board,
                   !card.isLocked,
                   card.kind == .image
                       ? isHovering
                       : (!card.isCollapsed && (isSelected || isHovering)) {
                    resizeHandle
                }
            }
            .shadow(
                color: .black.opacity(mode == .board ? 0.30 : 0.18),
                radius: card.kind == .image ? 12 : 16,
                y: card.kind == .image ? 6 : 8
            )
            .position(
                x: CGFloat(card.positionX) + dragTranslation.width,
                y: CGFloat(card.positionY) + dragTranslation.height
            )
            .simultaneousGesture(selectionGesture)
            .zIndex(Double(card.zIndex))
            .transaction { transaction in
                if isDraggingCard || isResizingCard {
                    transaction.animation = nil
                }
            }
            .onHover { isHovering = $0 }
            .onAppear(perform: normalizeMinimumSize)
            .onChange(of: mode) { _, mode in
                if mode != .board {
                    isEditingTitle = false
                    focusedField = nil
                }
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if oldValue == .title, newValue != .title {
                    isEditingTitle = false
                }
                if newValue != nil {
                    activateCard()
                }
            }
            .onChange(of: isSelected) { _, isSelected in
                if !isSelected {
                    isEditingTitle = false
                    focusedField = nil
                }
            }
            .onChange(of: isDraggingCard) { _, isDragging in
                guard isDragging else { return }
                activateCard()
            }
            .onChange(of: isResizingCard) { _, isResizing in
                guard isResizing else { return }
                activateCard()
            }
            .contextMenu {
                if mode == .board {
                    Button(card.isLocked ? "Unlock" : "Lock", action: toggleLock)
                    if card.kind != .image {
                        Button(card.isCollapsed ? "Expand" : "Collapse", action: toggleCollapsed)
                    }
                    if card.kind == .markdown, !card.isCollapsed, !card.isLocked {
                        Button(
                            showsMarkdownPreview ? "Edit Markdown Source" : "Preview Markdown",
                            action: toggleMarkdownPreview
                        )
                    }
                    Button("Duplicate", action: onDuplicate)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
            .animation(.snappy(duration: 0.18), value: isHovering)
            .animation(.snappy(duration: 0.22), value: card.isCollapsed)
    }

    @ViewBuilder
    private var cardSurface: some View {
        if card.kind == .image {
            imageCardSurface
        } else {
            VStack(spacing: 0) {
                cardHeader
                if !card.isCollapsed {
                    cardContent
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 7) {
            CardKindIcon(
                kind: card.kind,
                size: PinboardTheme.Controls.cardIconSize,
                backgroundColor: card.theme.color,
                foregroundColor: card.theme.highContrastForeground,
                borderColor: card.theme.highContrastForeground.opacity(0.24)
            )
            .help(card.isLocked ? "Card locked" : "Drag card")

            if mode == .board, !card.isLocked, isEditingTitle {
                TextField("Card title", text: binding(for: \BoardCard.title))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .focused($focusedField, equals: .title)
                    .onSubmit {
                        finishTitleEditing()
                    }
            } else {
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: beginTitleEditing)
                    .help(card.isLocked ? "Card locked" : "Double-click to edit title")
            }

            Spacer(minLength: 2)

            if mode == .board {
                HStack(spacing: 4) {
                    if !card.isCollapsed, !card.isLocked {
                        HStack(spacing: 0) {
                            if card.kind == .markdown {
                                PinboardIconButton(
                                    systemImage: showsMarkdownPreview ? "pencil" : "eye",
                                    accessibilityLabel: showsMarkdownPreview
                                        ? "Edit Markdown"
                                        : "Show Markdown preview",
                                    help: showsMarkdownPreview
                                        ? "Edit Markdown"
                                        : "Show Markdown preview",
                                    emphasis: showsMarkdownPreview ? .standard : .active,
                                    action: toggleMarkdownPreview
                                )
                            }

                            PinboardIconButton(
                                systemImage: "paintpalette",
                                accessibilityLabel: "Next color",
                                help: "Next color",
                                action: cycleTheme
                            )

                            PinboardIconButton(
                                systemImage: card.fontSize.systemImage,
                                accessibilityLabel: card.fontSize.title,
                                help: "Next font size",
                                action: cycleFontSize
                            )
                        }
                    }

                    HStack(spacing: 0) {
                        PinboardIconButton(
                            systemImage: card.isLocked ? "lock" : "lock.open",
                            accessibilityLabel: card.isLocked ? "Unlock card" : "Lock card",
                            help: card.isLocked ? "Unlock card" : "Lock card",
                            emphasis: card.isLocked ? .active : .standard,
                            action: toggleLock
                        )

                        PinboardIconButton(
                            systemImage: "trash",
                            accessibilityLabel: "Delete card",
                            help: "Delete card",
                            emphasis: .destructive,
                            action: onDelete
                        )

                        PinboardIconButton(
                            systemImage: card.isCollapsed ? "chevron.down" : "chevron.up",
                            accessibilityLabel: card.isCollapsed ? "Expand card" : "Collapse card",
                            help: card.isCollapsed ? "Expand card" : "Collapse card",
                            action: toggleCollapsed
                        )
                    }
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.primary.opacity(0.84))
        .padding(.horizontal, 9)
        .frame(height: noteTitleBarHeight)
        .background(.white.opacity(mode == .board ? 0.028 : 0.016))
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .animation(.snappy(duration: 0.22), value: card.isCollapsed)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch card.kind {
        case .text:
            textCardContent

        case .markdown:
            if !showsMarkdownPreview {
                TextEditor(text: binding(for: \BoardCard.content))
                    .font(.system(size: card.fontSize.pointSize, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .allowsHitTesting(mode == .board && !card.isLocked)
            } else {
                ScrollView {
                    MarkdownContentView(
                        markdown: card.content,
                        baseFontSize: card.fontSize.pointSize
                    )
                        .textSelection(.enabled)
                }
                .contentMargins(10)
            }

        case .image:
            imageContent
        }
    }

    private var textCardContent: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: binding(for: \BoardCard.content))
                .font(.system(size: card.fontSize.pointSize))
                .scrollContentBackground(.hidden)
                .focused($focusedField, equals: .content)
                .allowsHitTesting(mode == .board && !card.isLocked)

            if card.content.isEmpty {
                Text("Empty note")
                    .font(.system(size: card.fontSize.pointSize))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 5)
                    .padding(.top, 1)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    private var imageCardSurface: some View {
        ZStack(alignment: .top) {
            imageContent

            if mode == .board, isHovering {
                HStack(spacing: 6) {
                    Image(
                        systemName: card.isLocked
                            ? "lock"
                            : "arrow.up.and.down.and.arrow.left.and.right"
                    )
                        .symbolRenderingMode(.monochrome)
                        .font(.system(size: 11, weight: .medium))
                        .frame(
                            width: PinboardTheme.Controls.cardButtonSize,
                            height: PinboardTheme.Controls.cardButtonSize
                        )
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                        .help(card.isLocked ? "Card locked" : "Drag image")

                    Spacer(minLength: 8)

                    PinboardIconButton(
                        systemImage: "trash",
                        accessibilityLabel: "Delete image",
                        help: "Delete image",
                        emphasis: .destructive,
                        action: onDelete
                    )
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.88))
                .padding(.horizontal, 5)
                .frame(height: 24)
                .background(.ultraThinMaterial.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.75)
                }
                .shadow(color: .black.opacity(0.24), radius: 6, y: 2)
                .padding(6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image = card.image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "Image unavailable",
                systemImage: "photo.badge.exclamationmark"
            )
        }
    }

    @ViewBuilder
    private var cardSurfaceBackground: some View {
        if card.kind == .image {
            Color.black.opacity(0.025)
        } else {
            cardBackground
        }
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(card.theme.color.opacity(mode == .board ? 0.12 : 0.18))
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.black.opacity(mode == .board ? 0.05 : 0.10))
        }
    }

    @ViewBuilder
    private var selectionOutline: some View {
        if card.kind == .image {
            if mode == .board, isHovering {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? PinboardTheme.selection : .white.opacity(0.32),
                        lineWidth: isSelected ? 1.25 : 0.75
                    )
            }
        } else {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(
                    mode == .board && isSelected
                        ? PinboardTheme.selection
                        : .white.opacity(mode == .board && isHovering ? 0.17 : 0.09),
                    lineWidth: mode == .board && isSelected ? 1.25 : 1
                )
        }
    }

    private var resizeHandle: some View {
        let size: CGFloat = card.kind == .image ? 9 : 11

        return ZStack {
            Circle()
                .fill(PinboardTheme.selection)
                .frame(width: size, height: size)
            Circle()
                .stroke(.white.opacity(0.8), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .padding(card.kind == .image ? 5 : 7)
        .contentShape(Rectangle())
        .gesture(resizeGesture)
        .help("Resize card")
    }

    private var cardCornerRadius: CGFloat {
        card.kind == .image ? 12 : 14
    }

    private var imageHeightToWidthRatio: Double {
        max(0.01, card.imageHeightToWidthRatio ?? (card.height / max(1, card.width)))
    }

    private var displayedCardSize: CGSize {
        if card.kind == .image {
            let ratio = imageHeightToWidthRatio
            let widthChange: Double
            if abs(resizeTranslation.width) >= abs(resizeTranslation.height) {
                widthChange = Double(resizeTranslation.width)
            } else {
                widthChange = Double(resizeTranslation.height) / ratio
            }

            let width = max(imageMinimumWidth, card.width + widthChange)
            return CGSize(width: width, height: width * ratio)
        }

        return CGSize(
            width: max(noteMinimumWidth, card.width + Double(resizeTranslation.width)),
            height: card.isCollapsed
                ? noteTitleBarHeight
                : max(noteMinimumHeight, card.height + Double(resizeTranslation.height))
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                guard mode == .board, !card.isLocked else { return }
                state = value.translation
            }
            .updating($isDraggingCard) { _, state, _ in
                guard mode == .board, !card.isLocked else { return }
                state = true
            }
            .onEnded { value in
                guard mode == .board, !card.isLocked else { return }

                let proposedX = card.positionX + Double(value.translation.width)
                let proposedY = card.positionY + Double(value.translation.height)
                let displayedSize = displayedCardSize
                let halfWidth = Double(displayedSize.width) / 2
                let halfHeight = Double(displayedSize.height) / 2
                let maximumX = max(halfWidth, Double(canvasSize.width) - halfWidth)
                let maximumY = max(halfHeight, Double(canvasSize.height) - halfHeight)

                card.positionX = min(max(snapped(proposedX), halfWidth), maximumX)
                card.positionY = min(max(snapped(proposedY), halfHeight), maximumY)
                card.updatedAt = .now
            }
    }

    private var selectionGesture: some Gesture {
        TapGesture()
            .onEnded {
                activateCard()
            }
    }

    private func activateCard() {
        guard mode == .board else { return }
        onActivate()
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($resizeTranslation) { value, state, _ in
                state = value.translation
            }
            .updating($isResizingCard) { _, state, _ in
                state = true
            }
            .onEnded { value in
                if card.kind == .image {
                    let ratio = imageHeightToWidthRatio
                    let widthChange: Double
                    if abs(value.translation.width) >= abs(value.translation.height) {
                        widthChange = Double(value.translation.width)
                    } else {
                        widthChange = Double(value.translation.height) / ratio
                    }

                    let width = max(imageMinimumWidth, snapped(card.width + widthChange))
                    card.width = width
                    card.height = width * ratio
                } else {
                    card.width = max(
                        noteMinimumWidth,
                        snapped(card.width + Double(value.translation.width))
                    )
                    card.height = max(
                        noteMinimumHeight,
                        snapped(card.height + Double(value.translation.height))
                    )
                }
                clampCardPosition(width: card.width, height: card.height)
                card.updatedAt = .now
            }
    }

    private func snapped(_ value: Double) -> Double {
        guard snapToGrid else { return value }
        return (value / gridSize).rounded() * gridSize
    }

    private func cycleTheme() {
        activateCard()
        if let index = quickThemes.firstIndex(of: card.theme) {
            card.theme = quickThemes[(index + 1) % quickThemes.count]
        } else {
            card.theme = quickThemes[0]
        }
        card.updatedAt = .now
    }

    private func cycleFontSize() {
        activateCard()
        let sizes = CardFontSize.allCases
        let currentIndex = sizes.firstIndex(of: card.fontSize) ?? 0
        card.fontSize = sizes[(currentIndex + 1) % sizes.count]
        card.updatedAt = .now
    }

    private func toggleCollapsed() {
        activateCard()
        guard card.kind != .image else { return }

        isEditingTitle = false
        focusedField = nil

        let heightDifference = max(0, card.height - Double(noteTitleBarHeight)) / 2
        if card.isCollapsed {
            card.positionY += heightDifference
            card.isCollapsed = false
            clampCardPosition(width: card.width, height: card.height)
        } else {
            card.positionY -= heightDifference
            card.isCollapsed = true
            clampCardPosition(width: card.width, height: Double(noteTitleBarHeight))
        }
        card.updatedAt = .now
    }

    private func toggleMarkdownPreview() {
        activateCard()
        showsMarkdownPreview.toggle()
        if showsMarkdownPreview {
            focusedField = nil
        } else {
            focusedField = .content
        }
    }

    private func beginTitleEditing() {
        guard mode == .board, !card.isLocked else { return }
        activateCard()
        isEditingTitle = true
        Task { @MainActor in
            focusedField = .title
        }
    }

    private func finishTitleEditing() {
        isEditingTitle = false
        focusedField = nil
    }

    private func toggleLock() {
        activateCard()
        card.isLocked.toggle()
        if card.isLocked {
            isEditingTitle = false
            focusedField = nil
        }
        card.updatedAt = .now
    }

    private func normalizeMinimumSize() {
        if card.kind == .image {
            let ratio = imageHeightToWidthRatio
            var width = max(imageMinimumWidth, card.width)
            var height = width * ratio
            let maximumWidth = max(imageMinimumWidth, Double(canvasSize.width) - 24)
            let maximumHeight = max(48, Double(canvasSize.height) - 24)

            if width > maximumWidth {
                width = maximumWidth
                height = width * ratio
            }
            if height > maximumHeight {
                height = maximumHeight
                width = height / ratio
            }

            guard abs(card.width - width) > 0.5 || abs(card.height - height) > 0.5 else {
                return
            }

            card.width = width
            card.height = height
            clampCardPosition(width: width, height: height)
            card.updatedAt = .now
            return
        }

        let needsSizeUpdate = card.width < noteMinimumWidth || card.height < noteMinimumHeight
        let needsOpacityReset = card.opacity != 1
        guard needsSizeUpdate || needsOpacityReset else { return }

        card.width = max(noteMinimumWidth, card.width)
        card.height = max(noteMinimumHeight, card.height)
        card.opacity = 1
        clampCardPosition(
            width: card.width,
            height: card.isCollapsed ? Double(noteTitleBarHeight) : card.height
        )
        card.updatedAt = .now
    }

    private func clampCardPosition(width: Double, height: Double) {
        let halfWidth = width / 2
        let halfHeight = height / 2
        let maximumX = max(halfWidth, Double(canvasSize.width) - halfWidth)
        let maximumY = max(halfHeight, Double(canvasSize.height) - halfHeight)
        card.positionX = min(max(card.positionX, halfWidth), maximumX)
        card.positionY = min(max(card.positionY, halfHeight), maximumY)
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<BoardCard, String>) -> Binding<String> {
        Binding(
            get: { card[keyPath: keyPath] },
            set: { newValue in
                card[keyPath: keyPath] = newValue
                card.updatedAt = .now
            }
        )
    }
}
