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
    @Query(sort: \BoardCard.zIndex) private var allCards: [BoardCard]
    @Query(sort: \PinboardBoard.sortOrder) private var boards: [PinboardBoard]

    @AppStorage("didCreateWelcomeCards") private var didCreateWelcomeCards = false
    @AppStorage("activeBoardID") private var activeBoardIDString = ""
    @State private var search = BoardSearchController()
    @FocusState private var isBoardFocused: Bool

    private var activeBoardID: UUID? {
        UUID(uuidString: activeBoardIDString)
    }

    private var activeBoard: PinboardBoard? {
        guard let activeBoardID else { return boards.first }
        return boards.first { $0.id == activeBoardID } ?? boards.first
    }

    private var cards: [BoardCard] {
        guard let activeBoard else { return [] }
        return allCards.filter { $0.boardID == activeBoard.id }
    }

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
                    isBoardFocused = true
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
                    .opacity(search.opacity(for: card.id))
                    .animation(.easeOut(duration: 0.16), value: search.resolvedQuery)
                }

                if cards.isEmpty, session.mode == .board {
                    EmptyBoardView {
                        addCard(kind: .text, canvasSize: geometry.size)
                    }
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
        .onChange(of: cards.map(\.updatedAt), initial: true) {
            search.updateDocuments(from: cards)
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
        return cards.first { $0.id == selectedCardID }
    }

    private func preparePersistentBoards() {
        let board = resolvedInitialBoard()

        for card in allCards where card.boardID == nil {
            card.boardID = board.id
        }

        if !didCreateWelcomeCards, allCards.isEmpty {
            BoardCard.welcomeCards(boardID: board.id).forEach(modelContext.insert)
            didCreateWelcomeCards = true
        }

        activeBoardIDString = board.id.uuidString
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
        activeBoardIDString = board.id.uuidString
        session.selectedCardID = nil
    }

    private func openSearchResult(_ result: BoardSearchResult) {
        guard let card = cards.first(where: { $0.id == result.id }) else { return }
        search.close()
        activate(card)
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
        if let existingCard = allCards.first(where: { $0.id == request.id }) {
            if let boardID = existingCard.boardID,
               let board = boards.first(where: { $0.id == boardID }) {
                selectBoard(board)
            }
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
        let position = clampedCenter(
            corner ?? nextPosition(in: canvasSize),
            cardSize: cardSize,
            canvasSize: canvasSize
        )

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
        let position = clampedCenter(
            corner ?? nextPosition(in: canvasSize),
            cardSize: cardSize,
            canvasSize: canvasSize
        )
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
        session.selectedCardID = card.id
        saveNow()
    }

    private func addLink(_ url: URL, canvasSize: CGSize, corner: CGPoint? = nil) {
        guard let webURL = normalizedWebURL(url) else { return }
        let id = UUID()
        let cardSize = defaultSize(for: .link)
        let position = clampedCenter(
            corner ?? nextPosition(in: canvasSize),
            cardSize: cardSize,
            canvasSize: canvasSize
        )
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
        session.selectedCardID = card.id
        saveNow()

        Task {
            await enrichLinkCard(id: id, originalURL: webURL, canvasSize: canvasSize)
        }
    }

    private func enrichLinkCard(id: UUID, originalURL: URL, canvasSize: CGSize) async {
        let metadata = await LinkMetadataService.fetch(for: originalURL)
        guard let currentCard = allCards.first(where: { $0.id == id }) else {
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
                guard let card = allCards.first(where: { $0.id == id }) else {
                    await attachmentLibrary.remove(relativePaths: [preview.relativePath])
                    return
                }
                card.previewImageRelativePath = preview.relativePath
                card.imagePixelWidth = preview.pixelSize.width
                card.imagePixelHeight = preview.pixelSize.height

                let cardSize = linkCardSize(for: preview.pixelSize, canvasSize: canvasSize)
                card.width = cardSize.width
                card.height = cardSize.height
                let center = clampedCenter(
                    CGPoint(x: card.positionX, y: card.positionY),
                    cardSize: cardSize,
                    canvasSize: canvasSize
                )
                card.positionX = center.x
                card.positionY = center.y
            }
        }

        currentCard.linkMetadataState = .ready
        currentCard.updatedAt = .now
        saveNow()
    }

    private func resumePendingLinkMetadata(canvasSize: CGSize) async {
        let pendingLinks = allCards.compactMap { card -> (UUID, URL)? in
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
        for card in allCards where card.kind == .image
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
            boardID: card.boardID,
            imageData: card.imageData,
            imagePixelWidth: card.imagePixelWidth,
            imagePixelHeight: card.imagePixelHeight,
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
        let paths = [card.attachmentRelativePath, card.previewImageRelativePath].compactMap { $0 }
        let pathsUsedElsewhere = Set(allCards.lazy.filter { $0.id != card.id }.flatMap {
            [$0.attachmentRelativePath, $0.previewImageRelativePath].compactMap { $0 }
        })
        let orphanedPaths = paths.filter { !pathsUsedElsewhere.contains($0) }

        modelContext.delete(card)
        saveNow()
        Task {
            await attachmentLibrary.remove(relativePaths: orphanedPaths)
        }
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

#Preview {
    ContentView()
        .environment(BoardSession())
        .environment(AttachmentLibrary())
        .modelContainer(for: [BoardCard.self, PinboardBoard.self], inMemory: true)
        .frame(width: 1120, height: 760)
}
