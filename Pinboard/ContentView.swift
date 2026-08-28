//
//  ContentView.swift
//  Pinboard
//
//  Created by Ry@ on 2026/08/27.
//

import AppKit
import ImageIO
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BoardSession.self) private var session
    @Query(sort: \BoardCard.zIndex) private var cards: [BoardCard]

    @AppStorage("didCreateWelcomeCards") private var didCreateWelcomeCards = false
    @State private var isImportingImage = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BoardBackgroundView(
                    mode: session.mode,
                    showsGrid: session.snapToGrid,
                    gridSize: session.gridSize
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard session.mode == .board else { return }
                    session.selectedCardID = nil
                }
                .simultaneousGesture(
                    SpatialTapGesture(count: 2, coordinateSpace: .local)
                        .onEnded { value in
                            guard session.mode == .board else { return }
                            addCard(
                                kind: .text,
                                canvasSize: geometry.size,
                                corner: value.location
                            )
                        }
                )

                ForEach(cards) { card in
                    BoardCardView(
                        card: card,
                        mode: session.mode,
                        isSelected: session.selectedCardID == card.id,
                        snapToGrid: session.snapToGrid,
                        gridSize: session.gridSize,
                        canvasSize: geometry.size,
                        onActivate: { activate(card) },
                        onDuplicate: { duplicate(card, canvasSize: geometry.size) },
                        onDelete: { delete(card) }
                    )
                }

                if cards.isEmpty, session.mode == .board {
                    EmptyBoardView {
                        addCard(kind: .text, canvasSize: geometry.size)
                    }
                }

                if session.mode == .board {
                    VStack {
                        BoardToolbar(
                            mode: session.mode,
                            snapToGrid: session.snapToGrid,
                            onAddText: { addCard(kind: .text, canvasSize: geometry.size) },
                            onAddMarkdown: { addCard(kind: .markdown, canvasSize: geometry.size) },
                            onImportImage: { isImportingImage = true },
                            onToggleGrid: { session.snapToGrid.toggle() },
                            onToggleMode: session.toggleMode
                        )

                        Spacer()
                    }
                    .padding(.top, 18)
                    .zIndex(10_000_000)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .fileImporter(
                isPresented: $isImportingImage,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                importImage(result, canvasSize: geometry.size)
            }
            .onOpenURL { url in
                handleOpenURL(url, canvasSize: geometry.size)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(WindowConfigurator(mode: session.mode))
        .onAppear {
            session.installGlobalHotKeyIfNeeded()
            seedWelcomeCardsIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pinboardToggleMode)) { _ in
            session.toggleMode()
        }
        .onDeleteCommand {
            guard let selectedCard else { return }
            delete(selectedCard)
        }
    }

    private var selectedCard: BoardCard? {
        guard let selectedCardID = session.selectedCardID else { return nil }
        return cards.first { $0.id == selectedCardID }
    }

    private func seedWelcomeCardsIfNeeded() {
        guard !didCreateWelcomeCards, cards.isEmpty else { return }

        BoardCard.welcomeCards().forEach(modelContext.insert)
        didCreateWelcomeCards = true
        saveNow()
    }

    private func addCard(
        kind: CardKind,
        canvasSize: CGSize,
        corner: CGPoint? = nil
    ) {
        let cardSize = defaultSize(for: kind)
        let position = corner.map {
            fittedCenter(for: $0, cardSize: cardSize, canvasSize: canvasSize)
        } ?? nextPosition(in: canvasSize)
        let content = kind == .markdown ? "# New note\n\nStart writing…" : ""
        insertCard(
            BoardCardCreationRequest(
                kind: kind,
                content: content,
                position: position
            ),
            canvasSize: canvasSize
        )
    }

    private func handleOpenURL(_ url: URL, canvasSize: CGSize) {
        guard let request = try? PinboardDeepLink.creationRequest(from: url) else { return }
        insertCard(request, canvasSize: canvasSize)
    }

    private func insertCard(
        _ request: BoardCardCreationRequest,
        canvasSize: CGSize
    ) {
        if let existingCard = cards.first(where: { $0.id == request.id }) {
            activate(existingCard)
            return
        }

        let cardSize = defaultSize(for: request.kind)
        let position = clampedCenter(
            request.position ?? nextPosition(in: canvasSize),
            cardSize: cardSize,
            canvasSize: canvasSize
        )
        let card = BoardCard(
            id: request.id,
            kind: request.kind,
            title: request.title,
            content: request.content,
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: request.theme ?? nextTheme,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        session.selectedCardID = card.id
        saveNow()
    }

    private func addImage(_ data: Data, pixelSize: CGSize, canvasSize: CGSize) {
        let cardSize = imageCardSize(for: pixelSize, canvasSize: canvasSize)
        let position = clampedCenter(
            nextPosition(in: canvasSize),
            cardSize: cardSize,
            canvasSize: canvasSize
        )

        let card = BoardCard(
            kind: .image,
            title: "Image",
            imageData: data,
            imagePixelWidth: pixelSize.width,
            imagePixelHeight: pixelSize.height,
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: nextTheme,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        session.selectedCardID = card.id
        saveNow()
    }

    private func importImage(_ result: Result<[URL], Error>, canvasSize: CGSize) {
        guard case let .success(urls) = result, let url = urls.first else { return }

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard
            let data = try? Data(contentsOf: url),
            NSImage(data: data) != nil,
            let metadata = ImageMetadata(data: data)
        else { return }

        addImage(data, pixelSize: metadata.pixelSize, canvasSize: canvasSize)
    }

    private func activate(_ card: BoardCard) {
        session.selectedCardID = card.id

        let highestZIndex = cards.map(\.zIndex).max() ?? 0
        guard card.zIndex < highestZIndex else { return }
        card.zIndex = highestZIndex + 1
        card.updatedAt = .now
    }

    private func duplicate(_ card: BoardCard, canvasSize: CGSize) {
        let width = max(Double(canvasSize.width), card.width)
        let height = max(Double(canvasSize.height), card.height)
        let copy = BoardCard(
            kind: card.kind,
            title: card.title,
            content: card.content,
            imageData: card.imageData,
            imagePixelWidth: card.imagePixelWidth,
            imagePixelHeight: card.imagePixelHeight,
            positionX: min(card.positionX + 28, width - card.width / 2),
            positionY: min(card.positionY + 28, height - card.height / 2),
            width: card.width,
            height: card.height,
            opacity: 1,
            theme: card.theme,
            fontSize: card.fontSize,
            isCollapsed: card.isCollapsed,
            zIndex: nextZIndex
        )

        modelContext.insert(copy)
        session.selectedCardID = copy.id
        saveNow()
    }

    private func delete(_ card: BoardCard) {
        if session.selectedCardID == card.id {
            session.selectedCardID = nil
        }
        modelContext.delete(card)
        saveNow()
    }

    private func nextPosition(in canvasSize: CGSize) -> CGPoint {
        let cascade = Double((cards.count % 6) * 24)
        let centerX = max(180, Double(canvasSize.width) * 0.5 - 48 + cascade)
        let centerY = max(160, Double(canvasSize.height) * 0.5 - 36 + cascade)
        return CGPoint(x: centerX, y: centerY)
    }

    private func defaultSize(for kind: CardKind) -> CGSize {
        switch kind {
        case .text:
            CGSize(width: 320, height: 210)
        case .markdown:
            CGSize(width: 320, height: 240)
        case .image:
            CGSize(width: 320, height: 200)
        }
    }

    private func imageCardSize(for pixelSize: CGSize, canvasSize: CGSize) -> CGSize {
        let pixelWidth = max(1, Double(pixelSize.width))
        let pixelHeight = max(1, Double(pixelSize.height))
        let ratio = pixelHeight / pixelWidth
        let maximumWidth = max(160, min(520, Double(canvasSize.width) - 48))
        let maximumHeight = max(120, min(520, Double(canvasSize.height) - 48))

        var width = min(max(pixelWidth, 180), maximumWidth)
        var height = width * ratio
        if height > maximumHeight {
            height = maximumHeight
            width = height / ratio
        }

        return CGSize(width: width, height: height)
    }

    private func clampedCenter(
        _ center: CGPoint,
        cardSize: CGSize,
        canvasSize: CGSize
    ) -> CGPoint {
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2
        let maximumX = max(halfWidth, canvasSize.width - halfWidth)
        let maximumY = max(halfHeight, canvasSize.height - halfHeight)

        return CGPoint(
            x: min(max(center.x, halfWidth), maximumX),
            y: min(max(center.y, halfHeight), maximumY)
        )
    }

    private func fittedCenter(
        for corner: CGPoint,
        cardSize: CGSize,
        canvasSize: CGSize
    ) -> CGPoint {
        let halfWidth = cardSize.width / 2
        let halfHeight = cardSize.height / 2
        let fitsToRight = corner.x + cardSize.width <= canvasSize.width
        let fitsBelow = corner.y + cardSize.height <= canvasSize.height

        let proposedX = fitsToRight ? corner.x + halfWidth : corner.x - halfWidth
        let proposedY = fitsBelow ? corner.y + halfHeight : corner.y - halfHeight
        let maximumX = max(halfWidth, canvasSize.width - halfWidth)
        let maximumY = max(halfHeight, canvasSize.height - halfHeight)

        return CGPoint(
            x: min(max(proposedX, halfWidth), maximumX),
            y: min(max(proposedY, halfHeight), maximumY)
        )
    }

    private var nextZIndex: Int {
        (cards.map(\.zIndex).max() ?? -1) + 1
    }

    private var nextTheme: CardTheme {
        let themes = CardTheme.allCases
        return themes[cards.count % themes.count]
    }

    private func saveNow() {
        try? modelContext.save()
    }
}

private extension NSImage {
    var pngData: Data? {
        guard
            let tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }
}

private struct ImageMetadata {
    let pixelSize: CGSize

    init?(data: Data) {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
            let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
            pixelWidth > 0,
            pixelHeight > 0
        else { return nil }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapsDimensions = [5, 6, 7, 8].contains(orientation)
        pixelSize = swapsDimensions
            ? CGSize(width: pixelHeight, height: pixelWidth)
            : CGSize(width: pixelWidth, height: pixelHeight)
    }
}

#Preview {
    ContentView()
        .environment(BoardSession())
        .modelContainer(for: BoardCard.self, inMemory: true)
        .frame(width: 1120, height: 760)
}
