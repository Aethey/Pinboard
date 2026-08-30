//
//  PinboardDeepLink.swift
//  Pinboard
//

import Foundation

enum PinboardDeepLink {
    static let scheme = "pinboard"
    static let createNoteHost = "create-note"
    static let createBoardHost = "create-board"

    private static let maximumPayloadBytes = 64 * 1_024
    private static let maximumTitleLength = 200
    private static let maximumContentLength = 20_000
    private static let maximumSourceURLLength = 2_048

    static func request(from url: URL) throws -> PinboardCreationRequest {
        guard url.scheme?.lowercased() == scheme else {
            throw PinboardDeepLinkError.unsupportedURL
        }

        switch url.host?.lowercased() {
        case createNoteHost:
            return .card(try cardRequest(from: payloadData(from: url)))
        case createBoardHost:
            return .board(try boardRequest(from: payloadData(from: url)))
        default:
            throw PinboardDeepLinkError.unsupportedURL
        }
    }

    private static func payloadData(from url: URL) throws -> Data {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let encodedPayload = components.queryItems?.first(where: { $0.name == "payload" })?.value,
            let payloadData = Data(base64URLEncoded: encodedPayload),
            payloadData.count <= maximumPayloadBytes
        else {
            throw PinboardDeepLinkError.invalidPayload
        }
        return payloadData
    }

    private static func cardRequest(from payloadData: Data) throws -> BoardCardCreationRequest {
        let payload: CreateNotePayload
        do {
            payload = try JSONDecoder().decode(CreateNotePayload.self, from: payloadData)
        } catch {
            throw PinboardDeepLinkError.invalidPayload
        }

        return try cardRequest(from: payload)
    }

    private static func cardRequest(
        from payload: CreateNotePayload
    ) throws -> BoardCardCreationRequest {
        guard
            let kind = CardKind(rawValue: payload.kind),
            kind == .text || kind == .markdown || kind == .chat,
            payload.title?.count ?? 0 <= maximumTitleLength,
            payload.content.count <= maximumContentLength
        else {
            throw PinboardDeepLinkError.invalidNote
        }

        let position: CGPoint?
        switch (payload.x, payload.y) {
        case let (.some(x), .some(y)) where x.isFinite && y.isFinite:
            position = CGPoint(x: x, y: y)
        case (nil, nil):
            position = nil
        default:
            throw PinboardDeepLinkError.invalidPosition
        }

        let theme: CardTheme?
        if let rawTheme = payload.theme {
            guard let parsedTheme = CardTheme(rawValue: rawTheme) else {
                throw PinboardDeepLinkError.invalidNote
            }
            theme = parsedTheme
        } else {
            theme = nil
        }

        let sourceURL: URL?
        if let sourceURLString = payload.sourceURL {
            guard
                sourceURLString.count <= maximumSourceURLLength,
                let parsedURL = URL(string: sourceURLString),
                let scheme = parsedURL.scheme?.lowercased(),
                scheme == "https" || scheme == "http",
                parsedURL.host() != nil
            else {
                throw PinboardDeepLinkError.invalidNote
            }
            sourceURL = parsedURL
        } else {
            sourceURL = nil
        }

        let chatProvider: ChatProvider?
        if kind == .chat {
            if let rawProvider = payload.chatProvider {
                guard let parsedProvider = ChatProvider(rawValue: rawProvider) else {
                    throw PinboardDeepLinkError.invalidNote
                }
                chatProvider = parsedProvider
            } else {
                chatProvider = ChatProvider.inferred(from: sourceURL)
            }
        } else {
            chatProvider = nil
        }

        return BoardCardCreationRequest(
            id: payload.id,
            kind: kind,
            title: payload.title,
            content: payload.content,
            position: position,
            theme: theme,
            chatProvider: chatProvider,
            sourceURL: sourceURL
        )
    }

    private static func boardRequest(from payloadData: Data) throws -> BoardCreationRequest {
        let payload: CreateBoardPayload
        do {
            payload = try JSONDecoder().decode(CreateBoardPayload.self, from: payloadData)
        } catch {
            throw PinboardDeepLinkError.invalidPayload
        }

        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            name.count <= 80,
            payload.notes.count >= 2,
            payload.notes.count <= 24,
            Set(payload.notes.map(\.id)).count == payload.notes.count
        else {
            throw PinboardDeepLinkError.invalidBoard
        }

        let cards = try payload.notes.map { note -> BoardCardCreationRequest in
            let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !content.isEmpty else {
                throw PinboardDeepLinkError.invalidNote
            }

            return try cardRequest(
                from: CreateNotePayload(
                    id: note.id,
                    kind: note.kind,
                    title: title,
                    content: content,
                    x: nil,
                    y: nil,
                    theme: note.theme,
                    chatProvider: nil,
                    sourceURL: nil
                )
            )
        }

        return BoardCreationRequest(id: payload.id, name: name, cards: cards)
    }
}

enum PinboardCreationRequest {
    case card(BoardCardCreationRequest)
    case board(BoardCreationRequest)
}

private struct CreateNotePayload: Decodable {
    let id: UUID
    let kind: String
    let title: String?
    let content: String
    let x: Double?
    let y: Double?
    let theme: String?
    let chatProvider: String?
    let sourceURL: String?
}

private struct CreateBoardPayload: Decodable {
    let id: UUID
    let name: String
    let notes: [CreateBoardNotePayload]
}

private struct CreateBoardNotePayload: Decodable {
    let id: UUID
    let kind: String
    let title: String
    let content: String
    let theme: String?
}

private enum PinboardDeepLinkError: Error {
    case unsupportedURL
    case invalidPayload
    case invalidNote
    case invalidBoard
    case invalidPosition
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        self.init(base64Encoded: base64)
    }
}
