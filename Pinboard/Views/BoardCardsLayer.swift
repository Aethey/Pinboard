//
//  BoardCardsLayer.swift
//  Pinboard
//

import SwiftData
import SwiftUI

struct BoardCardsLayer: View {
    @Query private var cards: [BoardCard]

    let boardID: UUID
    let boardName: String
    let mode: BoardMode
    let selectedCardID: UUID?
    let snapToGrid: Bool
    let gridSize: Double
    let canvasSize: CGSize
    let canvasViewport: CanvasViewport
    let isCanvasNavigating: Bool
    let search: BoardSearchController
    let onCardsChanged: ([BoardCard]) -> Void
    let onActivate: (BoardCard) -> Void
    let onDuplicate: (BoardCard) -> Void
    let onDelete: (BoardCard) -> Void
    let onCreateFirstCard: () -> Void

    @State private var renderedCardIDs: Set<UUID> = []
    @State private var isPreparingBoard = true

    private let renderBatchSize = 10

    init(
        boardID: UUID,
        boardName: String,
        mode: BoardMode,
        selectedCardID: UUID?,
        snapToGrid: Bool,
        gridSize: Double,
        canvasSize: CGSize,
        canvasViewport: CanvasViewport,
        isCanvasNavigating: Bool,
        search: BoardSearchController,
        onCardsChanged: @escaping ([BoardCard]) -> Void,
        onActivate: @escaping (BoardCard) -> Void,
        onDuplicate: @escaping (BoardCard) -> Void,
        onDelete: @escaping (BoardCard) -> Void,
        onCreateFirstCard: @escaping () -> Void
    ) {
        let selectedBoardID = boardID
        _cards = Query(
            filter: #Predicate<BoardCard> { card in
                card.boardID == selectedBoardID
            },
            sort: [SortDescriptor(\BoardCard.zIndex)]
        )
        self.boardID = boardID
        self.boardName = boardName
        self.mode = mode
        self.selectedCardID = selectedCardID
        self.snapToGrid = snapToGrid
        self.gridSize = gridSize
        self.canvasSize = canvasSize
        self.canvasViewport = canvasViewport
        self.isCanvasNavigating = isCanvasNavigating
        self.search = search
        self.onCardsChanged = onCardsChanged
        self.onActivate = onActivate
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        self.onCreateFirstCard = onCreateFirstCard
    }

    var body: some View {
        ZStack {
            ZStack {
                ForEach(renderedCards) { card in
                    renderedCard(card)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .scaleEffect(canvasViewport.scale, anchor: .center)
            .offset(canvasViewport.offset)

            if cards.isEmpty, !isPreparingBoard, mode == .board {
                EmptyBoardView(onAddText: onCreateFirstCard)
                    .transition(.opacity)
            }

            if isPreparingBoard {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                    .accessibilityLabel("Loading \(boardName)")
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .task(id: visibleCards.map(\.id)) {
            await stageMissingCards()
        }
        .onChange(of: cards.map(\.id), initial: true) {
            onCardsChanged(cards)
        }
        .onChange(of: cards.map(\.updatedAt), initial: true) {
            search.updateDocuments(from: cards)
        }
        .animation(.easeOut(duration: 0.16), value: isPreparingBoard)
    }

    private func renderedCard(_ card: BoardCard) -> some View {
        let isSelected = selectedCardID == card.id
        let opacity = search.opacity(for: card.id)

        return BoardCardView(
            card: card,
            mode: mode,
            isSelected: isSelected,
            snapToGrid: snapToGrid,
            gridSize: gridSize,
            canvasScale: canvasViewport.scale,
            isCanvasNavigating: isCanvasNavigating,
            onActivate: { onActivate(card) },
            onDuplicate: { onDuplicate(card) },
            onDelete: { onDelete(card) }
        )
        .opacity(opacity)
        .animation(.easeOut(duration: 0.16), value: search.resolvedQuery)
    }

    private var renderedCards: [BoardCard] {
        visibleCards.filter { renderedCardIDs.contains($0.id) }
    }

    private var visibleCards: [BoardCard] {
        let visibleRect = canvasViewport.visibleWorldRect(
            in: canvasSize,
            overscan: 360
        )
        return cards.filter { card in
            let displayedHeight = card.isCollapsed && card.kind != .image
                ? Double(PinboardTheme.Controls.cardHeaderHeight)
                : card.height
            let cardRect = CGRect(
                x: card.positionX - card.width / 2,
                y: card.positionY - displayedHeight / 2,
                width: card.width,
                height: displayedHeight
            )
            return visibleRect.intersects(cardRect)
        }
    }

    @MainActor
    private func stageMissingCards() async {
        let targetCards = visibleCards
        let validIDs = Set(targetCards.map(\.id))
        renderedCardIDs.formIntersection(validIDs)

        let missingIDs = targetCards
            .map(\.id)
            .filter { !renderedCardIDs.contains($0) }

        if renderedCardIDs.isEmpty {
            isPreparingBoard = true
            try? await Task.sleep(for: .milliseconds(36))
            guard !Task.isCancelled else { return }
        }

        if missingIDs.isEmpty {
            isPreparingBoard = false
            return
        }

        var batch: [UUID] = []
        batch.reserveCapacity(renderBatchSize)

        for cardID in missingIDs {
            guard !Task.isCancelled else { return }
            batch.append(cardID)

            if batch.count == renderBatchSize {
                renderedCardIDs.formUnion(batch)
                batch.removeAll(keepingCapacity: true)
                isPreparingBoard = false
                try? await Task.sleep(for: .milliseconds(12))
            }
        }

        renderedCardIDs.formUnion(batch)
        isPreparingBoard = false
    }
}
