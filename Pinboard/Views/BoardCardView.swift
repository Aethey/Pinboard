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
    @State private var showsQuickControls = false
    @FocusState private var focusedField: FocusedField?
    @GestureState private var dragTranslation = CGSize.zero
    @GestureState private var resizeTranslation = CGSize.zero
    @GestureState private var isDraggingCard = false
    @GestureState private var isResizingCard = false

    private let noteMinimumWidth: Double = 300
    private let noteMinimumHeight: Double = 120
    private let imageMinimumWidth: Double = 80
    private let quickThemes: [CardTheme] = [.indigo, .teal, .amber, .rose]
    private let opacitySteps: [Double] = [1.0, 0.85, 0.70, 0.55]

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
                   card.kind == .image ? isHovering : (isSelected || isHovering) {
                    resizeHandle
                }
            }
            .shadow(
                color: .black.opacity(mode == .board ? 0.30 : 0.18),
                radius: card.kind == .image ? 12 : (mode == .board ? 16 : 10),
                y: card.kind == .image ? 6 : (mode == .board ? 8 : 5)
            )
            .opacity(card.opacity)
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
                    showsQuickControls = false
                    focusedField = nil
                }
            }
            .onChange(of: focusedField) { _, focusedField in
                guard focusedField != nil else { return }
                activateCard()
            }
            .onChange(of: isSelected) { _, isSelected in
                if !isSelected {
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
                    Button("Duplicate", action: onDuplicate)
                    Divider()
                    Button("Delete", role: .destructive, action: onDelete)
                }
            }
            .animation(.snappy(duration: 0.22), value: isSelected)
            .animation(.snappy(duration: 0.18), value: isHovering)
            .animation(.easeInOut(duration: 0.25), value: mode)
    }

    @ViewBuilder
    private var cardSurface: some View {
        if card.kind == .image {
            imageCardSurface
        } else {
            VStack(spacing: 0) {
                cardHeader
                cardContent
                    .contentShape(Rectangle())
            }
        }
    }

    private var cardHeader: some View {
        HStack(spacing: 6) {
            CardKindIcon(kind: card.kind, size: 14)
                .foregroundStyle(card.theme.color)

            if mode == .board, !card.isLocked {
                TextField("Card title", text: binding(for: \BoardCard.title))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .focused($focusedField, equals: .title)
            } else {
                Text(card.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            if card.kind == .markdown,
               mode == .board,
               !card.isLocked,
               !showsQuickControls {
                Button {
                    activateCard()
                    showsMarkdownPreview.toggle()
                } label: {
                    Image(
                        systemName: showsMarkdownPreview
                            ? "chevron.left.forwardslash.chevron.right"
                            : "doc.richtext"
                    )
                }
                .buttonStyle(.plain)
                .help(showsMarkdownPreview ? "Edit Markdown" : "Preview Markdown")
            }

            if mode == .board {
                if showsQuickControls {
                    HStack(spacing: 6) {
                        Button(action: cycleTheme) {
                            Image(systemName: "paintpalette.fill")
                        }
                        .help("Next color")

                        Button(action: cycleOpacity) {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(.primary.opacity(opacityIndicatorStrength))
                                .frame(width: 14)
                        }
                        .accessibilityLabel("Opacity level \(opacityLevel) of 4")
                        .help("Next opacity")

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.primary.opacity(0.52))
                        .help("Delete card")
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Button {
                    activateCard()
                    showsQuickControls.toggle()
                } label: {
                    Image(systemName: showsQuickControls ? "xmark.circle.fill" : "pencil.circle")
                }
                .buttonStyle(.plain)
                .help(showsQuickControls ? "Hide card controls" : "Show card controls")

                Button(action: toggleLock) {
                    Image(systemName: card.isLocked ? "lock.fill" : "lock.open")
                }
                .buttonStyle(.plain)
                .help(card.isLocked ? "Unlock card" : "Lock card")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.primary.opacity(0.84))
        .padding(.horizontal, 9)
        .frame(height: mode == .board ? 30 : 26)
        .background(.white.opacity(mode == .board ? 0.028 : 0.016))
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .animation(.snappy(duration: 0.22), value: showsQuickControls)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch card.kind {
        case .text:
            if mode == .board, !card.isLocked {
                TextEditor(text: binding(for: \BoardCard.content))
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            } else {
                ScrollView {
                    Text(card.content.isEmpty ? "Empty note" : card.content)
                        .font(.system(size: 14))
                        .foregroundStyle(card.content.isEmpty ? .tertiary : .primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
                .contentMargins(10)
            }

        case .markdown:
            if mode == .board, !card.isLocked, !showsMarkdownPreview {
                TextEditor(text: binding(for: \BoardCard.content))
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            } else {
                ScrollView {
                    MarkdownContentView(markdown: card.content)
                        .textSelection(.enabled)
                }
                .contentMargins(10)
            }

        case .image:
            imageContent
        }
    }

    private var imageCardSurface: some View {
        ZStack(alignment: .top) {
            imageContent

            if mode == .board, isHovering {
                HStack(spacing: 6) {
                    Image(systemName: card.isLocked ? "lock.fill" : "line.3.horizontal")
                        .frame(width: 24, height: 20)
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                        .help(card.isLocked ? "Card locked" : "Drag image")

                    Spacer(minLength: 8)

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 22, height: 20)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary.opacity(0.52))
                    .help("Delete image")
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
        if mode == .board {
            if card.kind == .image {
                if isHovering {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            isSelected ? PinboardTheme.selection : .white.opacity(0.32),
                            lineWidth: isSelected ? 1.25 : 0.75
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .stroke(
                        isSelected
                            ? PinboardTheme.selection
                            : .white.opacity(isHovering ? 0.17 : 0.09),
                        lineWidth: isSelected ? 1.25 : 1
                    )
            }
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
            height: max(noteMinimumHeight, card.height + Double(resizeTranslation.height))
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
                let halfWidth = card.width / 2
                let halfHeight = card.height / 2
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

    private var opacityLevel: Int {
        let closestIndex = opacitySteps.indices.min {
            abs(opacitySteps[$0] - card.opacity) < abs(opacitySteps[$1] - card.opacity)
        } ?? 0
        return closestIndex + 1
    }

    private var opacityIndicatorStrength: Double {
        [1.0, 0.82, 0.64, 0.46][opacityLevel - 1]
    }

    private func cycleOpacity() {
        activateCard()
        let currentIndex = opacitySteps.indices.min {
            abs(opacitySteps[$0] - card.opacity) < abs(opacitySteps[$1] - card.opacity)
        } ?? 0
        card.opacity = opacitySteps[(currentIndex + 1) % opacitySteps.count]
        card.updatedAt = .now
    }

    private func toggleLock() {
        activateCard()
        card.isLocked.toggle()
        if card.isLocked {
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

        guard card.width < noteMinimumWidth || card.height < noteMinimumHeight else { return }

        card.width = max(noteMinimumWidth, card.width)
        card.height = max(noteMinimumHeight, card.height)
        clampCardPosition(width: card.width, height: card.height)
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
