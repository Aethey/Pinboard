//
//  ContentView.swift
//  Pinboard
//
//  Created by Ry@ on 2026/08/27.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private enum AttachmentImportKind {
        case image
        case pdf

        var allowedContentTypes: [UTType] {
            switch self {
            case .image:
                [.image]
            case .pdf:
                [.pdf]
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(BoardSession.self) private var session
    @Environment(AttachmentLibrary.self) private var attachmentLibrary
    @Query(sort: \PinboardBoard.sortOrder) private var boards: [PinboardBoard]

    @AppStorage("didCreateWelcomeCards") private var didCreateWelcomeCards = false
    @AppStorage("activeBoardID") private var activeBoardIDString = ""
    @State private var search = BoardSearchController()
    @State private var activeCards: [BoardCard] = []
    @State private var activeViewport = CanvasViewport.defaultValue
    @State private var focusRequest: BoardFocusRequest?
    @State private var zoomResetRequest: BoardZoomResetRequest?
    @FocusState private var isBoardFocused: Bool

    private var activeBoardID: UUID? {
        UUID(uuidString: activeBoardIDString)
    }

    private var activeBoard: PinboardBoard? {
        guard let activeBoardID else { return boards.first }
        return boards.first { $0.id == activeBoardID } ?? boards.first
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let activeBoard {
                    InfiniteBoardCanvas(
                        board: activeBoard,
                        activeCards: activeCards,
                        mode: session.mode,
                        selectedCardID: session.selectedCardID,
                        snapToGrid: session.snapToGrid,
                        gridSize: session.gridSize,
                        canvasSize: geometry.size,
                        search: search,
                        focusRequest: focusRequest,
                        zoomResetRequest: zoomResetRequest,
                        onClearSelection: {
                            session.selectedCardID = nil
                            isBoardFocused = true
                        },
                        onViewportCommitted: commitViewport,
                        onCreateTextAtScreenPoint: { point, viewport in
                            addCard(
                                kind: .text,
                                canvasSize: geometry.size,
                                screenCorner: point,
                                viewport: viewport
                            )
                        },
                        onCardsChanged: updateActiveCards,
                        onActivate: activate,
                        onDuplicate: duplicate,
                        onDelete: delete
                    )
                    .id(activeBoard.id)
                }

                if session.mode == .board {
                    VStack {
                        BoardSearchToolbar(
                            search: search,
                            onSelectResult: openSearchResult
                        ) {
                            BoardToolbar(
                                mode: session.mode,
                                snapToGrid: session.snapToGrid,
                                activeBoard: activeBoard,
                                boards: boards,
                                onCreateBoard: createBoard,
                                onSelectBoard: selectBoard,
                                onRenameBoard: renameActiveBoard,
                                onAddText: { addCard(kind: .text, canvasSize: geometry.size) },
                                onAddMarkdown: { addCard(kind: .markdown, canvasSize: geometry.size) },
                                onImportImage: {
                                    presentFileImporter(for: .image, canvasSize: geometry.size)
                                },
                                onImportPDF: {
                                    presentFileImporter(for: .pdf, canvasSize: geometry.size)
                                },
                                onAddLink: { addLink($0, canvasSize: geometry.size) },
                                onToggleGrid: { session.snapToGrid.toggle() },
                                onResetZoom: resetActiveBoardZoom,
                                onToggleMode: session.toggleMode
                            )
                        }

                        Spacer()
                    }
                    .padding(.top, 18)
                    .zIndex(10_000_000)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable()
            .focusEffectDisabled()
            .focused($isBoardFocused)
            .onKeyPress(.init("v"), phases: .down) { keyPress in
                guard
                    session.mode == .board,
                    keyPress.modifiers.contains(.command)
                else { return .ignored }
                return pasteFromGeneralPasteboard(canvasSize: geometry.size)
                    ? .handled
                    : .ignored
            }
            .dropDestination(for: URL.self, isEnabled: session.mode == .board) { urls, session in
                importDroppedURLs(
                    urls,
                    at: session.location,
                    canvasSize: geometry.size
                )
            }
            .onPasteCommand(of: [.fileURL, .url, .plainText]) { providers in
                importPastedItems(providers, canvasSize: geometry.size)
            }
            .onOpenURL { url in
                handleOpenURL(url, canvasSize: geometry.size)
            }
            .onReceive(NotificationCenter.default.publisher(for: .pinboardOpenDeepLink)) {
                notification in
                guard let url = notification.object as? URL else { return }
                handleOpenURL(url, canvasSize: geometry.size)
            }
            .task {
                await resumePendingLinkMetadata(canvasSize: geometry.size)
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .background(WindowConfigurator(mode: session.mode))
        .onAppear {
            session.installGlobalHotKeyIfNeeded()
            preparePersistentBoards()
            Task { @MainActor in
                isBoardFocused = true
            }
        }
        .task(id: attachmentLibrary.locationIdentifier) {
            await migrateLegacyImagesIfNeeded()
        }
        .onChange(of: session.mode) { _, mode in
            if mode != .board {
                search.close()
            }
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
        return activeCards.first { $0.id == selectedCardID }
    }

    private func preparePersistentBoards() {
        let board = resolvedInitialBoard()
        let storedCards = fetchAllCards()

        for card in storedCards where card.boardID == nil {
            card.boardID = board.id
        }

        if !didCreateWelcomeCards, storedCards.isEmpty {
            BoardCard.welcomeCards(boardID: board.id).forEach(modelContext.insert)
            didCreateWelcomeCards = true
        }

        activeBoardIDString = board.id.uuidString
        activeViewport = CanvasViewport(board: board)
        saveNow()
    }

    private func resolvedInitialBoard() -> PinboardBoard {
        if let activeBoardID,
           let board = boards.first(where: { $0.id == activeBoardID }) {
            return board
        }

        if let board = boards.first {
            return board
        }

        let board = PinboardBoard()
        modelContext.insert(board)
        return board
    }

    private func createBoard() {
        let board = PinboardBoard(
            name: nextBoardName,
            sortOrder: (boards.map(\.sortOrder).max() ?? -1) + 1
        )
        modelContext.insert(board)
        selectBoard(board)
        saveNow()
    }

    private func selectBoard(_ board: PinboardBoard) {
        search.close()
        activeCards = []
        activeViewport = CanvasViewport(board: board)
        focusRequest = nil
        zoomResetRequest = nil
        activeBoardIDString = board.id.uuidString
        session.selectedCardID = nil
    }

    private func openSearchResult(_ result: BoardSearchResult) {
        guard
            let card = activeCards.first(where: { $0.id == result.id }),
            let boardID = card.boardID ?? activeBoard?.id
        else { return }
        search.close()
        activate(card)
        focusRequest = BoardFocusRequest(
            id: UUID(),
            boardID: boardID,
            worldPoint: CGPoint(x: card.positionX, y: card.positionY)
        )
    }

    private func renameActiveBoard(_ proposedName: String) {
        guard let activeBoard else { return }

        let trimmedName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        activeBoard.name = trimmedName.isEmpty
            ? "Pinboard"
            : String(trimmedName.prefix(80))
        activeBoard.updatedAt = .now
        saveNow()
    }

    private var nextBoardName: String {
        let names = Set(boards.map { $0.name.lowercased() })
        guard names.contains("pinboard") else { return "Pinboard" }

        var number = 2
        while names.contains("pinboard \(number)") {
            number += 1
        }
        return "Pinboard \(number)"
    }

    private func addCard(
        kind: CardKind,
        canvasSize: CGSize,
        screenCorner: CGPoint? = nil,
        viewport: CanvasViewport? = nil
    ) {
        let cardSize = defaultSize(for: kind)
        let viewport = viewport ?? activeViewport
        let position = screenCorner.map {
            fittedWorldCenter(
                for: $0,
                cardSize: cardSize,
                canvasSize: canvasSize,
                viewport: viewport
            )
        } ?? nextPosition(in: canvasSize, viewport: viewport)
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
        guard let request = try? PinboardDeepLink.request(from: url) else { return }

        switch request {
        case let .card(card):
            insertCard(card, canvasSize: canvasSize)
        case let .board(board):
            insertBoard(board, canvasSize: canvasSize)
        }
    }

    private func insertBoard(
        _ request: BoardCreationRequest,
        canvasSize: CGSize
    ) {
        if let existingBoard = fetchBoard(id: request.id) {
            if session.mode != .board {
                session.mode = .board
            }
            selectBoard(existingBoard)
            return
        }

        let layout = generatedBoardLayout(
            for: request.cards,
            canvasSize: canvasSize
        )
        let board = PinboardBoard(
            id: request.id,
            name: request.name,
            sortOrder: (boards.map(\.sortOrder).max() ?? -1) + 1,
            viewportScale: Double(layout.scale)
        )
        modelContext.insert(board)

        let themes = CardTheme.allCases
        for (index, cardRequest) in request.cards.enumerated() {
            let cardSize = defaultSize(for: cardRequest.kind)
            let position = cardRequest.position ?? layout.positions[index]
            let card = BoardCard(
                id: cardRequest.id,
                kind: cardRequest.kind,
                title: cardRequest.title,
                content: cardRequest.content,
                boardID: board.id,
                sourceURLString: cardRequest.sourceURL?.absoluteString,
                chatProvider: cardRequest.chatProvider
                    ?? ChatProvider.inferred(from: cardRequest.sourceURL),
                positionX: position.x,
                positionY: position.y,
                width: cardSize.width,
                height: cardSize.height,
                theme: cardRequest.theme ?? themes[index % themes.count],
                zIndex: index
            )
            modelContext.insert(card)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            return
        }

        if session.mode != .board {
            session.mode = .board
        }
        selectBoard(board)
    }

    private func insertCard(
        _ request: BoardCardCreationRequest,
        canvasSize: CGSize
    ) {
        if let existingCard = fetchCard(id: request.id) {
            if let boardID = existingCard.boardID,
               let board = boards.first(where: { $0.id == boardID }) {
                selectBoard(board)
            }
            activate(existingCard)
            return
        }

        let cardSize = defaultSize(for: request.kind)
        let position = request.position
            ?? nextPosition(in: canvasSize, viewport: activeViewport)
        let card = BoardCard(
            id: request.id,
            kind: request.kind,
            title: request.title,
            content: request.content,
            boardID: activeBoard?.id,
            sourceURLString: request.sourceURL?.absoluteString,
            chatProvider: request.chatProvider
                ?? ChatProvider.inferred(from: request.sourceURL),
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: request.theme ?? nextTheme,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        trackActiveCard(card)
        session.selectedCardID = card.id
        saveNow()
    }

    private func addImage(
        _ stored: StoredAttachment,
        id: UUID,
        canvasSize: CGSize,
        corner: CGPoint? = nil
    ) {
        guard let pixelSize = stored.pixelSize else { return }
        let cardSize = imageCardSize(for: pixelSize, canvasSize: canvasSize)
        let position = corner.map {
            activeViewport.worldPoint(for: $0, in: canvasSize)
        } ?? nextPosition(in: canvasSize, viewport: activeViewport)

        let card = BoardCard(
            id: id,
            kind: .image,
            title: "Image",
            boardID: activeBoard?.id,
            imagePixelWidth: pixelSize.width,
            imagePixelHeight: pixelSize.height,
            attachmentRelativePath: stored.attachmentRelativePath,
            sourceFileBookmark: stored.sourceFileBookmark,
            previewImageRelativePath: stored.previewImageRelativePath,
            sourceFileName: stored.sourceFileName,
            fileSize: stored.fileSize,
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: nextTheme,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        trackActiveCard(card)
        session.selectedCardID = card.id
        saveNow()
    }

    private func presentFileImporter(
        for kind: AttachmentImportKind,
        canvasSize: CGSize
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = kind.allowedContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"

        let completion: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                importIncomingURL(url, canvasSize: canvasSize)
                isBoardFocused = true
            }
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }

    private func importImageFile(
        _ url: URL,
        canvasSize: CGSize,
        corner: CGPoint? = nil
    ) {
        let id = UUID()
        Task {
            guard let stored = try? await attachmentLibrary.importImage(from: url, id: id) else {
                return
            }
            addImage(stored, id: id, canvasSize: canvasSize, corner: corner)
        }
    }

    private func importPDFFile(
        _ url: URL,
        canvasSize: CGSize,
        corner: CGPoint? = nil
    ) {
        let id = UUID()
        Task {
            guard let stored = try? await attachmentLibrary.importPDF(from: url, id: id) else {
                return
            }
            addPDF(stored, id: id, canvasSize: canvasSize, corner: corner)
        }
    }

    private func addPDF(
        _ stored: StoredAttachment,
        id: UUID,
        canvasSize: CGSize,
        corner: CGPoint?
    ) {
        let cardSize = defaultSize(for: .pdf)
        let position = corner.map {
            activeViewport.worldPoint(for: $0, in: canvasSize)
        } ?? nextPosition(in: canvasSize, viewport: activeViewport)
        let fileTitle = URL(fileURLWithPath: stored.sourceFileName)
            .deletingPathExtension()
            .lastPathComponent
        let pageDescription = stored.pageCount.map {
            "\($0) \($0 == 1 ? "page" : "pages")"
        } ?? "PDF document"
        let card = BoardCard(
            id: id,
            kind: .pdf,
            title: fileTitle.isEmpty ? "PDF" : fileTitle,
            content: "\(stored.sourceFileName)\n\(pageDescription)",
            boardID: activeBoard?.id,
            imagePixelWidth: stored.pixelSize.map { Double($0.width) },
            imagePixelHeight: stored.pixelSize.map { Double($0.height) },
            attachmentRelativePath: stored.attachmentRelativePath,
            sourceFileBookmark: stored.sourceFileBookmark,
            previewImageRelativePath: stored.previewImageRelativePath,
            sourceFileName: stored.sourceFileName,
            fileSize: stored.fileSize,
            pageCount: stored.pageCount,
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: nextTheme,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        trackActiveCard(card)
        session.selectedCardID = card.id
        saveNow()
    }

    private func addLink(_ url: URL, canvasSize: CGSize, corner: CGPoint? = nil) {
        guard let webURL = normalizedWebURL(url) else { return }
        let id = UUID()
        let cardSize = defaultSize(for: .link)
        let position = corner.map {
            activeViewport.worldPoint(for: $0, in: canvasSize)
        } ?? nextPosition(in: canvasSize, viewport: activeViewport)
        let card = BoardCard(
            id: id,
            kind: .link,
            title: "Loading link",
            content: webURL.absoluteString,
            boardID: activeBoard?.id,
            sourceURLString: webURL.absoluteString,
            linkMetadataState: .loading,
            positionX: position.x,
            positionY: position.y,
            width: cardSize.width,
            height: cardSize.height,
            theme: .graphite,
            zIndex: nextZIndex
        )

        modelContext.insert(card)
        trackActiveCard(card)
        session.selectedCardID = card.id
        saveNow()

        Task {
            await enrichLinkCard(id: id, originalURL: webURL, canvasSize: canvasSize)
        }
    }

    private func enrichLinkCard(id: UUID, originalURL: URL, canvasSize: CGSize) async {
        let metadata = await LinkMetadataService.fetch(for: originalURL)
        guard let currentCard = fetchCard(id: id) else {
            if let temporaryURL = metadata.temporaryImageURL {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            return
        }

        if let title = metadata.title,
           currentCard.title == "Link" || currentCard.title == "Loading link" {
            currentCard.title = String(title.prefix(200))
        } else if currentCard.title == "Loading link" {
            currentCard.title = metadata.resolvedURL.host(percentEncoded: false) ?? "Link"
        }
        currentCard.sourceURLString = metadata.resolvedURL.absoluteString
        currentCard.content = metadata.summary.map { String($0.prefix(2_000)) }
            ?? metadata.resolvedURL.absoluteString
        currentCard.linkIsVideo = metadata.isVideo

        if let temporaryURL = metadata.temporaryImageURL {
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            if let preview = try? await attachmentLibrary.storeLinkPreview(
                from: temporaryURL,
                id: id
            ) {
                guard let card = fetchCard(id: id) else {
                    await attachmentLibrary.remove(relativePaths: [preview.relativePath])
                    return
                }
                card.previewImageRelativePath = preview.relativePath
                card.imagePixelWidth = preview.pixelSize.width
                card.imagePixelHeight = preview.pixelSize.height

                let cardSize = linkCardSize(for: preview.pixelSize, canvasSize: canvasSize)
                card.width = cardSize.width
                card.height = cardSize.height
            }
        }

        currentCard.linkMetadataState = .ready
        currentCard.updatedAt = .now
        saveNow()
    }

    private func resumePendingLinkMetadata(canvasSize: CGSize) async {
        let pendingLinks = fetchAllCards().compactMap { card -> (UUID, URL)? in
            guard
                card.kind == .link,
                card.linkMetadataState == .loading,
                let sourceURLString = card.sourceURLString,
                let sourceURL = URL(string: sourceURLString)
            else { return nil }
            return (card.id, sourceURL)
        }

        for (id, sourceURL) in pendingLinks {
            await enrichLinkCard(id: id, originalURL: sourceURL, canvasSize: canvasSize)
        }
    }

    private func importDroppedURLs(_ urls: [URL], at location: CGPoint, canvasSize: CGSize) {
        for (index, url) in urls.prefix(12).enumerated() {
            let offset = CGFloat(index * 18)
            importIncomingURL(
                url,
                canvasSize: canvasSize,
                corner: CGPoint(x: location.x + offset, y: location.y + offset)
            )
        }
    }

    private func importPastedItems(_ providers: [NSItemProvider], canvasSize: CGSize) {
        for provider in providers.prefix(12) {
            let preferredType: UTType?
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                preferredType = .fileURL
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                preferredType = .url
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                preferredType = .plainText
            } else {
                preferredType = nil
            }

            guard let preferredType else { continue }
            provider.loadItem(forTypeIdentifier: preferredType.identifier, options: nil) { item, _ in
                guard let url = Self.decodeURL(from: item) else { return }
                Task { @MainActor in
                    importIncomingURL(url, canvasSize: canvasSize)
                }
            }
        }
    }

    private func pasteFromGeneralPasteboard(canvasSize: CGSize) -> Bool {
        let pasteboard = NSPasteboard.general

        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ),
           let fileURL = objects.compactMap({ $0 as? NSURL }).first as URL? {
            importIncomingURL(fileURL, canvasSize: canvasSize)
            return true
        }

        let candidate = pasteboard.string(forType: .URL)
            ?? pasteboard.string(forType: .string)
        guard let candidate, let url = normalizedPastedWebURL(candidate) else {
            return false
        }
        addLink(url, canvasSize: canvasSize)
        return true
    }

    private func normalizedPastedWebURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else {
            return nil
        }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate) else { return nil }
        return normalizedWebURL(url)
    }

    private func importIncomingURL(_ url: URL, canvasSize: CGSize, corner: CGPoint? = nil) {
        if url.isFileURL {
            let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType
                ?? UTType(filenameExtension: url.pathExtension)
            if contentType?.conforms(to: .image) == true {
                importImageFile(url, canvasSize: canvasSize, corner: corner)
            } else if contentType?.conforms(to: .pdf) == true {
                importPDFFile(url, canvasSize: canvasSize, corner: corner)
            }
            return
        }

        addLink(url, canvasSize: canvasSize, corner: corner)
    }

    private func normalizedWebURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    private static func decodeURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let url = item as? NSURL { return url as URL }
        if let string = item as? String { return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) { return url }
            if let string = String(data: data, encoding: .utf8) {
                return URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return nil
    }

    private func migrateLegacyImagesIfNeeded() async {
        for card in fetchAllCards() where card.kind == .image
            && card.attachmentRelativePath == nil
            && card.imageData != nil {
            guard let legacyData = card.imageData else { continue }
            guard let stored = try? await attachmentLibrary.migrateLegacyImage(
                legacyData,
                id: card.id
            ) else { continue }

            card.attachmentRelativePath = stored.attachmentRelativePath
            card.sourceFileBookmark = stored.sourceFileBookmark
            card.previewImageRelativePath = stored.previewImageRelativePath
            card.sourceFileName = stored.sourceFileName
            card.fileSize = stored.fileSize
            card.imagePixelWidth = stored.pixelSize.map { Double($0.width) }
            card.imagePixelHeight = stored.pixelSize.map { Double($0.height) }
            card.imageData = nil
            saveNow()
        }
    }

    private func activate(_ card: BoardCard) {
        session.selectedCardID = card.id

        let highestZIndex = activeCards.map(\.zIndex).max() ?? 0
        guard card.zIndex < highestZIndex else { return }
        card.zIndex = highestZIndex + 1
        card.updatedAt = .now
    }

    private func duplicate(_ card: BoardCard) {
        let copy = BoardCard(
            kind: card.kind,
            title: card.title,
            content: card.content,
            boardID: card.boardID,
            imageData: card.imageData,
            imagePixelWidth: card.imagePixelWidth,
            imagePixelHeight: card.imagePixelHeight,
            imageOCRText: card.imageOCRText,
            showsImageOCRSplit: card.showsImageOCRSplit,
            attachmentRelativePath: card.attachmentRelativePath,
            sourceFileBookmark: card.sourceFileBookmark,
            previewImageRelativePath: card.previewImageRelativePath,
            sourceURLString: card.sourceURLString,
            chatProvider: card.chatProvider,
            linkIsVideo: card.linkIsVideo,
            linkMetadataState: .ready,
            sourceFileName: card.sourceFileName,
            fileSize: card.fileSize,
            pageCount: card.pageCount,
            positionX: card.positionX + 28,
            positionY: card.positionY + 28,
            width: card.width,
            height: card.height,
            opacity: 1,
            theme: card.theme,
            fontSize: card.fontSize,
            isCollapsed: card.isCollapsed,
            zIndex: nextZIndex
        )

        modelContext.insert(copy)
        trackActiveCard(copy)
        session.selectedCardID = copy.id
        saveNow()
    }

    private func delete(_ card: BoardCard) {
        if session.selectedCardID == card.id {
            session.selectedCardID = nil
        }
        let paths = [card.attachmentRelativePath, card.previewImageRelativePath].compactMap { $0 }
        let pathsUsedElsewhere = Set(fetchAllCards().lazy.filter { $0.id != card.id }.flatMap {
            [$0.attachmentRelativePath, $0.previewImageRelativePath].compactMap { $0 }
        })
        let orphanedPaths = paths.filter { !pathsUsedElsewhere.contains($0) }

        modelContext.delete(card)
        activeCards.removeAll { $0.id == card.id }
        saveNow()
        Task {
            await attachmentLibrary.remove(relativePaths: orphanedPaths)
        }
    }

    private func nextPosition(
        in canvasSize: CGSize,
        viewport: CanvasViewport
    ) -> CGPoint {
        let cascade = CGFloat((activeCards.count % 6) * 24)
        let screenPoint = CGPoint(
            x: canvasSize.width * 0.5 - 48 + cascade,
            y: canvasSize.height * 0.5 - 36 + cascade
        )
        return viewport.worldPoint(for: screenPoint, in: canvasSize)
    }

    private func generatedBoardLayout(
        for cards: [BoardCardCreationRequest],
        canvasSize: CGSize
    ) -> (positions: [CGPoint], scale: CGFloat) {
        guard !cards.isEmpty else { return ([], 1) }

        let columnCount = min(
            4,
            max(1, Int(ceil(sqrt(Double(cards.count)))))
        )
        let rowCount = Int(ceil(Double(cards.count) / Double(columnCount)))
        let sizes = cards.map { defaultSize(for: $0.kind) }
        var columnWidths = [CGFloat](repeating: 0, count: columnCount)
        var rowHeights = [CGFloat](repeating: 0, count: rowCount)

        for (index, size) in sizes.enumerated() {
            columnWidths[index % columnCount] = max(
                columnWidths[index % columnCount],
                size.width
            )
            rowHeights[index / columnCount] = max(
                rowHeights[index / columnCount],
                size.height
            )
        }

        let gap: CGFloat = 32
        let totalWidth = columnWidths.reduce(0, +)
            + gap * CGFloat(max(0, columnCount - 1))
        let totalHeight = rowHeights.reduce(0, +)
            + gap * CGFloat(max(0, rowCount - 1))
        let originX = canvasSize.width / 2 - totalWidth / 2
        let originY = canvasSize.height / 2 - totalHeight / 2

        var columnCenters: [CGFloat] = []
        var cursorX = originX
        for width in columnWidths {
            columnCenters.append(cursorX + width / 2)
            cursorX += width + gap
        }

        var rowCenters: [CGFloat] = []
        var cursorY = originY
        for height in rowHeights {
            rowCenters.append(cursorY + height / 2)
            cursorY += height + gap
        }

        let positions = cards.indices.map { index in
            CGPoint(
                x: columnCenters[index % columnCount],
                y: rowCenters[index / columnCount]
            )
        }
        let availableWidth = max(320, canvasSize.width - 96)
        let availableHeight = max(240, canvasSize.height - 160)
        let fittedScale = min(
            1,
            availableWidth / max(1, totalWidth),
            availableHeight / max(1, totalHeight)
        )
        let scale = min(
            CanvasViewport.maximumScale,
            max(CanvasViewport.minimumScale, fittedScale)
        )
        return (positions, scale)
    }

    private func defaultSize(for kind: CardKind) -> CGSize {
        switch kind {
        case .text:
            CGSize(width: 320, height: 210)
        case .markdown:
            CGSize(width: 320, height: 240)
        case .chat:
            CGSize(width: 440, height: 340)
        case .image:
            CGSize(width: 320, height: 200)
        case .pdf:
            CGSize(width: 360, height: 220)
        case .link:
            CGSize(width: 420, height: 210)
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

    private func linkCardSize(for pixelSize: CGSize, canvasSize: CGSize) -> CGSize {
        let maximumWidth = max(320, min(480, canvasSize.width - 48))
        let width = min(420, maximumWidth)
        let ratio = max(0.1, pixelSize.height / max(1, pixelSize.width))
        let previewHeight = min(max(width * ratio, 120), 210)
        let desiredHeight = PinboardTheme.Controls.cardHeaderHeight + previewHeight + 88
        let maximumHeight = max(180, canvasSize.height - 48)
        return CGSize(width: width, height: min(desiredHeight, maximumHeight))
    }

    private func fittedWorldCenter(
        for corner: CGPoint,
        cardSize: CGSize,
        canvasSize: CGSize,
        viewport: CanvasViewport
    ) -> CGPoint {
        let scaledSize = CGSize(
            width: cardSize.width * viewport.scale,
            height: cardSize.height * viewport.scale
        )
        let halfWidth = scaledSize.width / 2
        let halfHeight = scaledSize.height / 2
        let fitsToRight = corner.x + scaledSize.width <= canvasSize.width
        let fitsBelow = corner.y + scaledSize.height <= canvasSize.height

        let proposedX = fitsToRight ? corner.x + halfWidth : corner.x - halfWidth
        let proposedY = fitsBelow ? corner.y + halfHeight : corner.y - halfHeight
        let maximumX = max(halfWidth, canvasSize.width - halfWidth)
        let maximumY = max(halfHeight, canvasSize.height - halfHeight)

        let fittedScreenCenter = CGPoint(
            x: min(max(proposedX, halfWidth), maximumX),
            y: min(max(proposedY, halfHeight), maximumY)
        )
        return viewport.worldPoint(for: fittedScreenCenter, in: canvasSize)
    }

    private func updateActiveCards(_ cards: [BoardCard]) {
        activeCards = cards
    }

    private func commitViewport(boardID: UUID, viewport: CanvasViewport) {
        guard let board = boards.first(where: { $0.id == boardID }) else { return }

        if activeBoard?.id == boardID {
            activeViewport = viewport
        }

        let scale = Double(viewport.scale)
        let offsetX = Double(viewport.offset.width)
        let offsetY = Double(viewport.offset.height)
        guard
            abs(board.viewportScale - scale) > 0.0001
                || abs(board.viewportOffsetX - offsetX) > 0.01
                || abs(board.viewportOffsetY - offsetY) > 0.01
        else { return }

        board.viewportScale = scale
        board.viewportOffsetX = offsetX
        board.viewportOffsetY = offsetY
        board.updatedAt = .now
        saveNow()
    }

    private func resetActiveBoardZoom() {
        guard let activeBoard else { return }
        zoomResetRequest = BoardZoomResetRequest(
            id: UUID(),
            boardID: activeBoard.id
        )
    }

    private func trackActiveCard(_ card: BoardCard) {
        guard card.boardID == activeBoard?.id else { return }
        guard !activeCards.contains(where: { $0.id == card.id }) else { return }
        activeCards.append(card)
        activeCards.sort { $0.zIndex < $1.zIndex }
    }

    private func fetchAllCards() -> [BoardCard] {
        (try? modelContext.fetch(FetchDescriptor<BoardCard>())) ?? []
    }

    private func fetchCard(id: UUID) -> BoardCard? {
        let cardID = id
        var descriptor = FetchDescriptor<BoardCard>(
            predicate: #Predicate { card in
                card.id == cardID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchBoard(id: UUID) -> PinboardBoard? {
        let boardID = id
        var descriptor = FetchDescriptor<PinboardBoard>(
            predicate: #Predicate { board in
                board.id == boardID
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private var nextZIndex: Int {
        (activeCards.map(\.zIndex).max() ?? -1) + 1
    }

    private var nextTheme: CardTheme {
        let themes = CardTheme.allCases
        return themes[activeCards.count % themes.count]
    }

    private func saveNow() {
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .environment(BoardSession())
        .environment(AttachmentLibrary())
        .modelContainer(for: [BoardCard.self, PinboardBoard.self], inMemory: true)
        .frame(width: 1120, height: 760)
}
