//
//  BoardCreationRequest.swift
//  Pinboard
//

import Foundation

struct BoardCreationRequest {
    let id: UUID
    let name: String
    let cards: [BoardCardCreationRequest]
}
