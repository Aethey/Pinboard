//
//  InfiniteBoardCanvas.swift
//  Pinboard
//

import SwiftUI

struct InfiniteBoardCanvas: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let board: PinboardBoard
    let activeCards: [BoardCard]
    let mode: BoardMode
    let selectedCardID: UUID?
    let snapToGrid: Bool
    let gridSize: Double
    let backgroundStyle: BoardBackgroundStyle
    let canvasSize: CGSize
    let search: BoardSearchController
    let focusRequest: BoardFocusRequest?
    let zoomResetRequest: BoardZoomResetRequest?
    let onClearSelection: () -> Void
    let onViewportCommitted: (UUID, CanvasViewport) -> Void
    let onCreateTextAtScreenPoint: (CGPoint, CanvasViewport) -> Void
    let onCardsChanged: ([BoardCard]) -> Void
    let onActivate: (BoardCard) -> Void
    let onDuplicate: (BoardCard) -> Void
    let onDelete: (BoardCard) -> Void

    @State private var viewport: CanvasViewport
    @State private var panStartViewport: CanvasViewport?
    @State private var magnifyStartViewport: CanvasViewport?
    @State private var isScrollNavigating = false
    @State private var isDirectlyNavigating = false
    @State private var persistenceTask: Task<Void, Never>?
    @State private var interactionEndTask: Task<Void, Never>?

    init(
        board: PinboardBoard,
        activeCards: [BoardCard],
        mode: BoardMode,
        selectedCardID: UUID?,
        snapToGrid: Bool,
        gridSize: Double,
        backgroundStyle: BoardBackgroundStyle,
        canvasSize: CGSize,
        search: BoardSearchController,
        focusRequest: BoardFocusRequest?,
        zoomResetRequest: BoardZoomResetRequest?,
        onClearSelection: @escaping () -> Void,
        onViewportCommitted: @escaping (UUID, CanvasViewport) -> Void,
        onCreateTextAtScreenPoint: @escaping (CGPoint, CanvasViewport) -> Void,
        onCardsChanged: @escaping ([BoardCard]) -> Void,
        onActivate: @escaping (BoardCard) -> Void,
        onDuplicate: @escaping (BoardCard) -> Void,
        onDelete: @escaping (BoardCard) -> Void
    ) {
        self.board = board
        self.activeCards = activeCards
        self.mode = mode
        self.selectedCardID = selectedCardID
        self.snapToGrid = snapToGrid
        self.gridSize = gridSize
        self.backgroundStyle = backgroundStyle
        self.canvasSize = canvasSize
        self.search = search
        self.focusRequest = focusRequest
        self.zoomResetRequest = zoomResetRequest
        self.onClearSelection = onClearSelection
        self.onViewportCommitted = onViewportCommitted
        self.onCreateTextAtScreenPoint = onCreateTextAtScreenPoint
        self.onCardsChanged = onCardsChanged
        self.onActivate = onActivate
        self.onDuplicate = onDuplicate
        self.onDelete = onDelete
        _viewport = State(initialValue: CanvasViewport(board: board))
    }

    var body: some View {
        ZStack {
            BoardBackgroundView(
                mode: mode,
                showsGrid: snapToGrid,
                gridSize: gridSize,
                backgroundStyle: backgroundStyle,
                viewport: effectiveViewport
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard mode == .board else { return }
                onClearSelection()
            }
            .simultaneousGesture(doubleClickGesture)
            .simultaneousGesture(panGesture)

            CanvasScrollMonitor(
                isEnabled: mode == .board,
                topExclusion: 86,
                excludedRects: visibleCardRects,
                onInteractionChanged: { isScrollNavigating = $0 },
                onScroll: handleScroll
            )
            .frame(width: canvasSize.width, height: canvasSize.height)
            .allowsHitTesting(false)

            BoardCardsLayer(
                boardID: board.id,
                boardName: board.name,
                mode: mode,
                selectedCardID: selectedCardID,
                snapToGrid: snapToGrid,
                gridSize: gridSize,
                canvasSize: canvasSize,
                canvasViewport: effectiveViewport,
                isCanvasNavigating: isCanvasNavigating,
                search: search,
                onCardsChanged: onCardsChanged,
                onActivate: onActivate,
                onDuplicate: onDuplicate,
                onDelete: onDelete,
                onCreateFirstCard: {
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    onCreateTextAtScreenPoint(center, viewport)
                }
            )

            if mode == .board {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        CanvasZoomControl(
                            scale: viewport.scale,
                            onZoomOut: { zoom(by: 0.8) },
                            onReset: resetZoom,
                            onZoomIn: { zoom(by: 1.25) }
                        )
                    }
                }
                .padding(18)
                .zIndex(9_000_000)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
        .simultaneousGesture(magnifyGesture, including: .all)
        .onChange(of: focusRequest) { _, request in
            guard let request, request.boardID == board.id else { return }
            focus(on: request.worldPoint)
        }
        .onChange(of: zoomResetRequest) { _, request in
            guard let request, request.boardID == board.id else { return }
            resetZoom()
        }
        .onDisappear {
            persistenceTask?.cancel()
            interactionEndTask?.cancel()
        }
    }

    private var effectiveViewport: CanvasViewport {
        viewport
    }

    private var isCanvasNavigating: Bool {
        isScrollNavigating || isDirectlyNavigating
    }

    private var doubleClickGesture: some Gesture {
        SpatialTapGesture(count: 2, coordinateSpace: .local)
            .onEnded { value in
                guard mode == .board else { return }
                onCreateTextAtScreenPoint(value.location, viewport)
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .local)
            .onChanged { value in
                guard mode == .board else { return }
                if panStartViewport == nil {
                    panStartViewport = viewport
                    beginDirectNavigation()
                }
                guard let panStartViewport else { return }
                viewport = panStartViewport.translated(by: value.translation)
            }
            .onEnded { _ in
                guard mode == .board else { return }
                panStartViewport = nil
                endDirectNavigation()
                commitViewport()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { value in
                guard mode == .board else { return }
                if magnifyStartViewport == nil {
                    magnifyStartViewport = viewport
                    beginDirectNavigation()
                }
                guard let magnifyStartViewport else { return }
                viewport = magnifyStartViewport.zoomed(
                    to: magnifyStartViewport.scale * value.magnification,
                    around: value.startLocation,
                    in: canvasSize
                )
            }
            .onEnded { _ in
                guard mode == .board else { return }
                magnifyStartViewport = nil
                endDirectNavigation()
                commitViewport()
            }
    }

    private func handleScroll(_ event: CanvasScrollEvent) {
        guard mode == .board else { return }
        if event.zoomsCanvas {
            let factor = exp(event.translation.height * 0.012)
            viewport = viewport.zoomed(
                to: viewport.scale * factor,
                around: event.location,
                in: canvasSize
            )
        } else {
            viewport = viewport.translated(by: event.translation)
        }
        scheduleViewportCommit()
    }

    private func beginDirectNavigation() {
        interactionEndTask?.cancel()
        interactionEndTask = nil
        isDirectlyNavigating = true
    }

    private func endDirectNavigation() {
        interactionEndTask?.cancel()
        interactionEndTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            isDirectlyNavigating = false
        }
    }

    private func zoom(by factor: CGFloat) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        withAnimation(PinboardMotion.canvas(reduceMotion: reduceMotion)) {
            viewport = viewport.zoomed(
                to: viewport.scale * factor,
                around: center,
                in: canvasSize
            )
        }
        commitViewport()
    }

    private func resetZoom() {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        withAnimation(PinboardMotion.canvas(reduceMotion: reduceMotion)) {
            viewport = viewport.zoomed(to: 1, around: center, in: canvasSize)
        }
        commitViewport()
    }

    private func focus(on worldPoint: CGPoint) {
        withAnimation(PinboardMotion.canvas(reduceMotion: reduceMotion)) {
            viewport = viewport.centered(on: worldPoint, in: canvasSize)
        }
        commitViewport()
    }

    private func scheduleViewportCommit() {
        persistenceTask?.cancel()
        persistenceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            commitViewport()
        }
    }

    private func commitViewport() {
        persistenceTask?.cancel()
        persistenceTask = nil
        onViewportCommitted(board.id, viewport)
    }

    private var visibleCardRects: [CGRect] {
        let viewportBounds = CGRect(origin: .zero, size: canvasSize)
        return activeCards.compactMap { card in
            let height = card.isCollapsed && card.kind != .image
                ? PinboardTheme.Controls.cardHeaderHeight
                : CGFloat(card.height)
            let worldRect = CGRect(
                x: CGFloat(card.positionX) - CGFloat(card.width) / 2,
                y: CGFloat(card.positionY) - height / 2,
                width: CGFloat(card.width),
                height: height
            )
            let screenRect = effectiveViewport
                .screenRect(for: worldRect, in: canvasSize)
                .insetBy(dx: -4, dy: -4)
            return screenRect.intersects(viewportBounds) ? screenRect : nil
        }
    }
}
