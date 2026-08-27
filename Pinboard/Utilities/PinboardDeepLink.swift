//
//  PinboardDeepLink.swift
//  Pinboard
//

import Foundation

enum PinboardDeepLink {
    static let scheme = "pinboard"
    static let createNoteHost = "create-note"

    private static let maximumPayloadBytes = 64 * 1_024
    private static let maximumTitleLength = 200
    private static let maximumContentLength = 20_000

    static func creationRequest(from url: URL) throws -> BoardCardCreationRequest {
        guard
            url.scheme?.lowercased() == scheme,
            url.host?.lowercased() == createNoteHost
        else {
            throw PinboardDeepLinkError.unsupportedURL
        }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let encodedPayload = components.queryItems?.first(where: { $0.name == "payload" })?.value,
            let payloadData = Data(base64URLEncoded: encodedPayload),
            payloadData.count <= maximumPayloadBytes
        else {
            throw PinboardDeepLinkError.invalidPayload
        }

        let payload: CreateNotePayload
        do {
            payload = try JSONDecoder().decode(CreateNotePayload.self, from: payloadData)
        } catch {
            throw PinboardDeepLinkError.invalidPayload
        }

        guard
            let kind = CardKind(rawValue: payload.kind),
            kind != .image,
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

        return BoardCardCreationRequest(
            id: payload.id,
            kind: kind,
            title: payload.title,
            content: payload.content,
            position: position,
            theme: theme
        )
    }
}

private struct CreateNotePayload: Decodable {
    let id: UUID
    let kind: String
    let title: String?
    let content: String
    let x: Double?
    let y: Double?
    let theme: String?
}

private enum PinboardDeepLinkError: Error {
    case unsupportedURL
    case invalidPayload
    case invalidNote
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

