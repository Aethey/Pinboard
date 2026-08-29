//
//  PinboardBoard.swift
//  Pinboard
//

import Foundation
import SwiftData

@Model
final class PinboardBoard {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var viewportScale: Double = 1
    var viewportOffsetX: Double = 0
    var viewportOffsetY: Double = 0
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "Pinboard",
        sortOrder: Int = 0,
        viewportScale: Double = 1,
        viewportOffsetX: Double = 0,
        viewportOffsetY: Double = 0,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.viewportScale = viewportScale
        self.viewportOffsetX = viewportOffsetX
        self.viewportOffsetY = viewportOffsetY
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
