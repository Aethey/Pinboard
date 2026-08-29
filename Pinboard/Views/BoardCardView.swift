//
//  BoardCardView.swift
//  Pinboard
//

import AppKit
import SwiftUI

struct BoardCardView: View {
    @Environment(AttachmentLibrary.self) private var attachmentLibrary

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
            .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
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
            .onHover { isHovering = $0 }
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
            .onAppear {
                normalizeMinimumSize()
            }
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
                    if canOpenExternalContent {
                        Button("Open", action: openExternalContent)
                        Divider()
                    }
                    Button(card.isLocked ? "Unlock" : "Lock", action: toggleLock)
                    if card.kind != .image {
                        Button(card.isCollapsed ? "Expand" : "Collapse", action: toggleCollapsed)
                    }
                    if (card.kind == .markdown || card.kind == .chat),
                       !card.isCollapsed,
                       !card.isLocked {
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
            cardKindBadge

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
                            if canOpenExternalContent {
                                PinboardIconButton(
                                    systemImage: "arrow.up.forward.app",
                                    accessibilityLabel: externalContentOpenLabel,
                                    help: externalContentOpenHelp,
                                    action: openExternalContent
                                )
                            }

                            if card.kind == .markdown || card.kind == .chat {
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

                            if card.kind != .link, card.kind != .chat {
                                PinboardIconButton(
                                    systemImage: "paintpalette",
                                    accessibilityLabel: "Next color",
                                    help: "Next color",
                                    action: cycleTheme
                                )
                            }

                            if card.kind != .link {
                                PinboardIconButton(
                                    systemImage: "textformat.size",
                                    accessibilityLabel: card.fontSize.title,
                                    help: "Next font size",
                                    action: cycleFontSize
                                )
                            }
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
        .background(cardHeaderBackground)
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture)
        .animation(.snappy(duration: 0.22), value: card.isCollapsed)
    }

    @ViewBuilder
    private var cardKindBadge: some View {
        if card.kind == .chat {
            ChatProviderBadge(provider: card.chatProvider)
                .help(card.isLocked ? "Card locked" : "Drag chat summary")
        } else {
            CardKindIcon(
                kind: card.kind,
                size: PinboardTheme.Controls.cardIconSize,
                backgroundColor: kindIconBackground,
                foregroundColor: kindIconForeground,
                borderColor: kindIconForeground.opacity(0.24)
            )
            .help(card.isLocked ? "Card locked" : "Drag card")
        }
    }

    private var cardHeaderBackground: Color {
        if card.kind == .chat {
            return card.chatProvider.primaryColor.opacity(mode == .board ? 0.075 : 0.10)
        }
        return .white.opacity(mode == .board ? 0.028 : 0.016)
    }

    @ViewBuilder
    private var cardContent: some View {
        switch card.kind {
        case .text:
            textCardContent

        case .markdown, .chat:
            if !showsMarkdownPreview {
                TextEditor(text: binding(for: \BoardCard.content))
                    .font(.system(size: card.fontSize.pointSize, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                    .allowsHitTesting(mode == .board && !card.isLocked)
            } else {
                GeometryReader { geometry in
                    let contentWidth = max(0, geometry.size.width - 20)

                    ScrollView([.horizontal, .vertical]) {
                        MarkdownContentView(
                            markdown: card.content,
                            baseFontSize: card.fontSize.pointSize,
                            textWidth: contentWidth
                        )
                        .textSelection(.enabled)
                        .padding(10)
                    }
                    .scrollIndicators(.visible)
                }
            }

        case .image:
            imageContent

        case .pdf:
            pdfContent

        case .link:
            ZStack {
                if card.linkMetadataState == .loading {
                    linkLoadingContent
                        .transition(.opacity)
                } else {
                    linkContent
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.24), value: card.linkMetadataStateRawValue)
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
                ZStack {
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

                    Group {
                        if !card.isLocked, isEditingTitle {
                            TextField("Image title", text: binding(for: \BoardCard.title))
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .title)
                                .onSubmit {
                                    finishTitleEditing()
                                }
                        } else {
                            Text(card.title)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2, perform: beginTitleEditing)
                                .help(
                                    card.isLocked
                                        ? "Card locked"
                                        : "Double-click to edit title"
                                )
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 34)
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
        if let image = resolvedPreviewImage ?? card.image {
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

    private var pdfContent: some View {
        HStack(spacing: 14) {
            Group {
                if let resolvedPreviewImage {
                    Image(nsImage: resolvedPreviewImage)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 132)
            .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 7) {
                Text(card.sourceFileName ?? "PDF document")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)

                if let pageCount = card.pageCount {
                    Label(
                        "\(pageCount) \(pageCount == 1 ? "page" : "pages")",
                        systemImage: "doc.on.doc"
                    )
                }

                if let fileSize = card.fileSize, fileSize > 0 {
                    Label(formattedFileSize(fileSize), systemImage: "internaldrive")
                }

                Spacer(minLength: 2)

                Label("Double-click to open", systemImage: "arrow.up.forward.app")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 11))

            Spacer(minLength: 0)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: openExternalContent)
        .help("Double-click to open in the default PDF app")
    }

    private var linkContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let resolvedPreviewImage {
                    linkPreview(resolvedPreviewImage, in: geometry.size)

                    Divider()
                        .opacity(0.45)
                }

                linkDetails
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: openExternalContent)
        .help("Double-click to open in the browser")
    }

    private var linkLoadingContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.black.opacity(0.08))

                    linkLoadingShimmer

                    VStack(spacing: 9) {
                        Image(systemName: "link")
                            .symbolRenderingMode(.hierarchical)
                            .font(.system(size: 24, weight: .medium))
                            .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))

                        Text("Preparing preview")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PinboardTheme.selection.opacity(0.82))
                }
                .frame(height: linkLoadingPreviewHeight(in: geometry.size))
                .clipped()

                Divider()
                    .opacity(0.35)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(linkHost ?? "Link")
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        ProgressView()
                            .controlSize(.mini)
                    }

                    loadingLine(width: geometry.size.width * 0.64)
                    loadingLine(width: geometry.size.width * 0.42)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading link preview")
    }

    private var linkLoadingShimmer: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            GeometryReader { geometry in
                let duration = 1.6
                let phase = CGFloat(
                    timeline.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: duration) / duration
                )
                let shimmerWidth = max(80, geometry.size.width * 0.42)

                LinearGradient(
                    colors: [
                        .clear,
                        PinboardTheme.selection.opacity(0.04),
                        .white.opacity(0.16),
                        PinboardTheme.selection.opacity(0.04),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: shimmerWidth, height: geometry.size.height * 1.6)
                .rotationEffect(.degrees(12))
                .offset(
                    x: -shimmerWidth + (geometry.size.width + shimmerWidth * 2) * phase,
                    y: -geometry.size.height * 0.3
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func loadingLine(width: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(.primary.opacity(0.08))
            .frame(width: max(44, width), height: 6)
    }

    private func linkLoadingPreviewHeight(in availableSize: CGSize) -> CGFloat {
        min(118, max(88, availableSize.height - 76))
    }

    private func linkPreview(_ image: NSImage, in availableSize: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.12)

            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if card.linkIsVideo {
                Image(systemName: "play.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.38), radius: 7, y: 2)
            }
        }
        .frame(height: linkPreviewHeight(in: availableSize))
        .clipped()
    }

    private var linkDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: card.linkIsVideo ? "play.rectangle" : "globe")
                    .foregroundStyle(.secondary)

                Text(linkHost ?? "Link")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if !card.content.isEmpty,
               card.content != card.sourceURLString {
                Text(card.content)
                    .font(.system(size: 13))
                    .lineLimit(3)
            } else if let sourceURLString = card.sourceURLString {
                Text(sourceURLString)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 2)

            Text(card.createdAt, format: .dateTime.year().month().day().hour().minute())
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func linkPreviewHeight(in availableSize: CGSize) -> CGFloat {
        let ratio = max(0.1, card.imageHeightToWidthRatio ?? (9.0 / 16.0))
        let naturalHeight = availableSize.width * ratio
        let maximumHeight = max(80, availableSize.height - 88)
        return min(max(96, naturalHeight), min(210, maximumHeight))
    }

    @ViewBuilder
    private var cardSurfaceBackground: some View {
        if card.kind == .image {
            Color.black.opacity(0.025)
        } else if card.kind == .link {
            linkCardBackground
        } else if card.kind == .chat {
            chatCardBackground
        } else {
            cardBackground
        }
    }

    private var linkCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            linkThemeColor.opacity(mode == .board ? 0.22 : 0.27),
                            linkThemeColor.opacity(mode == .board ? 0.08 : 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.black.opacity(mode == .board ? 0.08 : 0.12))
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

    private var chatCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            card.chatProvider.primaryColor.opacity(mode == .board ? 0.14 : 0.18),
                            card.chatProvider.secondaryColor.opacity(mode == .board ? 0.06 : 0.10),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(.black.opacity(mode == .board ? 0.06 : 0.10))
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

    private var kindIconBackground: Color {
        switch card.kind {
        case .link:
            linkThemeColor
        case .chat:
            card.chatProvider.primaryColor
        default:
            card.theme.color
        }
    }

    private var kindIconForeground: Color {
        card.kind == .link || card.kind == .chat ? .white : card.theme.highContrastForeground
    }

    private var linkThemeColor: Color {
        guard
            card.kind == .link,
            let color = attachmentLibrary.previewThemeColor(
                relativePath: card.previewImageRelativePath
            )
        else { return PinboardTheme.selection }
        return Color(nsColor: color)
    }

    private var imageHeightToWidthRatio: Double {
        max(0.01, card.imageHeightToWidthRatio ?? (card.height / max(1, card.width)))
    }

    private var linkHost: String? {
        guard
            let sourceURLString = card.sourceURLString,
            let url = URL(string: sourceURLString)
        else { return nil }
        return url.host(percentEncoded: false)
    }

    private var chatShareURL: URL? {
        guard
            card.kind == .chat,
            let sourceURLString = card.sourceURLString,
            let url = URL(string: sourceURLString),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host() != nil
        else { return nil }
        return url
    }

    private var canOpenExternalContent: Bool {
        switch card.kind {
        case .pdf, .link:
            true
        case .chat:
            chatShareURL != nil
        case .text, .markdown, .image:
            false
        }
    }

    private var externalContentOpenLabel: String {
        switch card.kind {
        case .pdf:
            "Open PDF"
        case .chat:
            "Open shared chat"
        default:
            "Open link"
        }
    }

    private var externalContentOpenHelp: String {
        switch card.kind {
        case .pdf:
            "Open PDF in the default app"
        case .chat:
            "Open the original shared conversation"
        default:
            "Open link in the browser"
        }
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

    private func openExternalContent() {
        activateCard()
        switch card.kind {
        case .pdf:
            if let refreshedBookmark = attachmentLibrary.openAttachment(
                relativePath: card.attachmentRelativePath,
                sourceBookmark: card.sourceFileBookmark
            ) {
                card.sourceFileBookmark = refreshedBookmark
                card.updatedAt = .now
            }
        case .link:
            attachmentLibrary.openWebURL(card.sourceURLString.flatMap(URL.init(string:)))
        case .chat:
            attachmentLibrary.openWebURL(chatShareURL)
        case .text, .markdown, .image:
            break
        }
    }

    private var resolvedPreviewImage: NSImage? {
        attachmentLibrary.previewImage(relativePath: card.previewImageRelativePath)
    }

    private func formattedFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
