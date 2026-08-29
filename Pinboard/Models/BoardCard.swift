//
//  BoardCard.swift
//  Pinboard
//

import AppKit
import Foundation
import SwiftData

enum CardKind: String, CaseIterable, Identifiable {
    case text
    case markdown
    case chat
    case image
    case pdf
    case link

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            "Text"
        case .markdown:
            "Markdown"
        case .chat:
            "Chat"
        case .image:
            "Image"
        case .pdf:
            "PDF"
        case .link:
            "Link"
        }
    }

}

enum ChatProvider: String, CaseIterable, Identifiable {
    case chatGPT = "chatgpt"
    case claude
    case gemini
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chatGPT:
            "ChatGPT"
        case .claude:
            "Claude"
        case .gemini:
            "Gemini"
        case .other:
            "AI"
        }
    }

    static func inferred(from url: URL?) -> ChatProvider {
        guard let host = url?.host(percentEncoded: false)?.lowercased() else {
            return .other
        }

        if host == "chatgpt.com"
            || host.hasSuffix(".chatgpt.com")
            || host == "openai.com"
            || host.hasSuffix(".openai.com") {
            return .chatGPT
        }
        if host == "claude.ai" || host.hasSuffix(".claude.ai") {
            return .claude
        }
        if host == "gemini.google.com" || host == "g.co" || host.hasSuffix(".google.com") {
            return .gemini
        }
        return .other
    }
}

enum LinkMetadataState: String {
    case loading
    case ready
}

enum CardTheme: String, CaseIterable, Identifiable {
    case graphite
    case indigo
    case teal
    case amber
    case rose

    var id: String { rawValue }
}

enum CardFontSize: Int, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Int { rawValue }

    var pointSize: CGFloat {
        switch self {
        case .small:
            12
        case .medium:
            18
        case .large:
            24
        }
    }

    var title: String {
        switch self {
        case .small:
            "Small font"
        case .medium:
            "Medium font"
        case .large:
            "Large font"
        }
    }
}

@Model
final class BoardCard {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var title: String
    var content: String
    var boardID: UUID?
    // Kept only to migrate images saved by earlier builds. New attachments use
    // file references and lightweight previews; this value is then cleared.
    @Attribute(.externalStorage) var imageData: Data?
    var imagePixelWidth: Double?
    var imagePixelHeight: Double?
    var attachmentRelativePath: String?
    var sourceFileBookmark: Data?
    var previewImageRelativePath: String?
    var sourceURLString: String?
    var chatProviderRawValue: String = ChatProvider.other.rawValue
    var linkIsVideo: Bool = false
    var linkMetadataStateRawValue: String = LinkMetadataState.ready.rawValue
    var sourceFileName: String?
    var fileSize: Int64?
    var pageCount: Int?
    var positionX: Double
    var positionY: Double
    var width: Double
    var height: Double
    var opacity: Double
    var themeRawValue: String
    var fontSizeRawValue: Int = CardFontSize.medium.rawValue
    var isCollapsed: Bool = false
    var zIndex: Int
    var isLocked: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: CardKind,
        title: String? = nil,
        content: String = "",
        boardID: UUID? = nil,
        imageData: Data? = nil,
        imagePixelWidth: Double? = nil,
        imagePixelHeight: Double? = nil,
        attachmentRelativePath: String? = nil,
        sourceFileBookmark: Data? = nil,
        previewImageRelativePath: String? = nil,
        sourceURLString: String? = nil,
        chatProvider: ChatProvider = .other,
        linkIsVideo: Bool = false,
        linkMetadataState: LinkMetadataState = .ready,
        sourceFileName: String? = nil,
        fileSize: Int64? = nil,
        pageCount: Int? = nil,
        positionX: Double = 320,
        positionY: Double = 260,
        width: Double = 390,
        height: Double = 240,
        opacity: Double = 1,
        theme: CardTheme = .graphite,
        fontSize: CardFontSize = .medium,
        isCollapsed: Bool = false,
        zIndex: Int = 0,
        isLocked: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title ?? kind.title
        self.content = content
        self.boardID = boardID
        self.imageData = imageData
        self.imagePixelWidth = imagePixelWidth
        self.imagePixelHeight = imagePixelHeight
        self.attachmentRelativePath = attachmentRelativePath
        self.sourceFileBookmark = sourceFileBookmark
        self.previewImageRelativePath = previewImageRelativePath
        self.sourceURLString = sourceURLString
        self.chatProviderRawValue = chatProvider.rawValue
        self.linkIsVideo = linkIsVideo
        self.linkMetadataStateRawValue = linkMetadataState.rawValue
        self.sourceFileName = sourceFileName
        self.fileSize = fileSize
        self.pageCount = pageCount
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.opacity = opacity
        self.themeRawValue = theme.rawValue
        self.fontSizeRawValue = fontSize.rawValue
        self.isCollapsed = isCollapsed
        self.zIndex = zIndex
        self.isLocked = isLocked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: CardKind {
        get { CardKind(rawValue: kindRawValue) ?? .text }
        set { kindRawValue = newValue.rawValue }
    }

    var theme: CardTheme {
        get { CardTheme(rawValue: themeRawValue) ?? .graphite }
        set { themeRawValue = newValue.rawValue }
    }

    var fontSize: CardFontSize {
        get { CardFontSize(rawValue: fontSizeRawValue) ?? .medium }
        set { fontSizeRawValue = newValue.rawValue }
    }

    var chatProvider: ChatProvider {
        get { ChatProvider(rawValue: chatProviderRawValue) ?? .other }
        set { chatProviderRawValue = newValue.rawValue }
    }

    var linkMetadataState: LinkMetadataState {
        get { LinkMetadataState(rawValue: linkMetadataStateRawValue) ?? .ready }
        set { linkMetadataStateRawValue = newValue.rawValue }
    }

    var image: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }

    var imageHeightToWidthRatio: Double? {
        if let imagePixelWidth,
           let imagePixelHeight,
           imagePixelWidth > 0,
           imagePixelHeight > 0 {
            return imagePixelHeight / imagePixelWidth
        }

        guard let image, image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size.height / image.size.width
    }
}

extension BoardCard {
    static func welcomeCards(boardID: UUID? = nil) -> [BoardCard] {
        [
            BoardCard(
                kind: .markdown,
                title: "Welcome to Pinboard",
                content: """
                # Spread ideas across space

                Create cards, drag them anywhere, and resize from the lower-right corner.

                Press **⌥ Space** to switch between Board and Desktop modes.
                """,
                boardID: boardID,
                positionX: 300,
                positionY: 245,
                width: 390,
                height: 300,
                theme: .indigo,
                zIndex: 0
            ),
            BoardCard(
                kind: .text,
                title: "Interview notes",
                content: "Keep the facts you need in sight.\n\n• Key numbers\n• Questions to ask\n• Short examples",
                boardID: boardID,
                positionX: 730,
                positionY: 260,
                width: 390,
                height: 260,
                theme: .teal,
                zIndex: 1
            ),
            BoardCard(
                kind: .markdown,
                title: "Desktop mode",
                content: "Cards stay visible while the canvas becomes transparent. The window becomes click-through so it never blocks the app underneath.",
                boardID: boardID,
                positionX: 520,
                positionY: 560,
                width: 420,
                height: 230,
                theme: .amber,
                zIndex: 2
            ),
        ]
    }
}
