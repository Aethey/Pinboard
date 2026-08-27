//
//  BoardSession.swift
//  Pinboard
//

import AppKit
import Foundation
import Observation

enum BoardMode: String, CaseIterable, Identifiable {
    case board
    case desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .board:
            "Board"
        case .desktop:
            "Desktop"
        }
    }

    var systemImage: String {
        switch self {
        case .board:
            "square.grid.2x2"
        case .desktop:
            "rectangle.on.rectangle"
        }
    }
}

@MainActor
@Observable
final class BoardSession {
    var mode: BoardMode = .board
    var selectedCardID: UUID?
    var snapToGrid = true
    var gridSize: Double = 16
    var hotKeyIsAvailable = false

    @ObservationIgnored private var hotKeyController: GlobalHotKeyController?

    func installGlobalHotKeyIfNeeded() {
        guard hotKeyController == nil else { return }

        let controller = GlobalHotKeyController()
        hotKeyController = controller
        hotKeyIsAvailable = controller.isRegistered
    }

    func toggleMode() {
        mode = mode == .board ? .desktop : .board
        selectedCardID = nil

        guard mode == .board else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
    }
}

