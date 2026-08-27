//
//  BoardCardCreationRequest.swift
//  Pinboard
//

import Foundation

struct BoardCardCreationRequest {
    let id: UUID
    let kind: CardKind
    let title: String?
    let content: String
    let position: CGPoint?
    let theme: CardTheme?

    init(
        id: UUID = UUID(),
        kind: CardKind,
        title: String? = nil,
        content: String,
        position: CGPoint? = nil,
        theme: CardTheme? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.position = position
        self.theme = theme
    }
}

