//
//  PinboardTheme.swift
//  Pinboard
//

import SwiftUI

enum BoardBackgroundStyle: String, CaseIterable, Identifiable {
    case midnight
    case graphite
    case indigo
    case forest
    case umber

    static let storageKey = "boardBackgroundStyle"

    var id: Self { self }

    var title: String {
        switch self {
        case .midnight: "Midnight"
        case .graphite: "Graphite"
        case .indigo: "Indigo"
        case .forest: "Forest"
        case .umber: "Umber"
        }
    }

    var topColor: Color {
        switch self {
        case .midnight: Color(red: 0.075, green: 0.082, blue: 0.11)
        case .graphite: Color(red: 0.12, green: 0.125, blue: 0.14)
        case .indigo: Color(red: 0.105, green: 0.10, blue: 0.19)
        case .forest: Color(red: 0.07, green: 0.135, blue: 0.12)
        case .umber: Color(red: 0.16, green: 0.105, blue: 0.075)
        }
    }

    var bottomColor: Color {
        switch self {
        case .midnight: Color(red: 0.035, green: 0.039, blue: 0.055)
        case .graphite: Color(red: 0.055, green: 0.058, blue: 0.07)
        case .indigo: Color(red: 0.045, green: 0.04, blue: 0.09)
        case .forest: Color(red: 0.025, green: 0.07, blue: 0.06)
        case .umber: Color(red: 0.075, green: 0.045, blue: 0.035)
        }
    }

    var glowColor: Color {
        switch self {
        case .midnight, .indigo: .indigo
        case .graphite: .white
        case .forest: .teal
        case .umber: .orange
        }
    }

    var gridColor: Color {
        .white.opacity(0.055)
    }
}

extension CardTheme {
    var color: Color {
        switch self {
        case .graphite:
            Color(red: 0.48, green: 0.51, blue: 0.58)
        case .indigo:
            Color(red: 0.42, green: 0.45, blue: 0.98)
        case .teal:
            Color(red: 0.12, green: 0.73, blue: 0.67)
        case .amber:
            Color(red: 0.96, green: 0.64, blue: 0.20)
        case .rose:
            Color(red: 0.94, green: 0.35, blue: 0.50)
        }
    }

}

extension ChatProvider {
    var primaryColor: Color {
        switch self {
        case .chatGPT:
            Color(red: 0.06, green: 0.64, blue: 0.49)
        case .claude:
            Color(red: 0.84, green: 0.39, blue: 0.25)
        case .gemini:
            Color(red: 0.27, green: 0.49, blue: 0.96)
        case .cursor:
            Color(red: 0.36, green: 0.38, blue: 0.42)
        case .codex:
            Color(red: 0.29, green: 0.36, blue: 0.96)
        case .other:
            PinboardTheme.selection
        }
    }

    var secondaryColor: Color {
        switch self {
        case .gemini:
            Color(red: 0.66, green: 0.36, blue: 0.91)
        case .codex:
            Color(red: 0.67, green: 0.61, blue: 1.0)
        default:
            primaryColor
        }
    }
}

extension CardKind {
    var badgeBackgroundColor: Color {
        switch self {
        case .text:
            Color(red: 0.94, green: 0.35, blue: 0.50)
        case .markdown:
            Color(red: 0.96, green: 0.64, blue: 0.20)
        case .chat:
            PinboardTheme.selection
        case .image:
            Color(red: 0.12, green: 0.73, blue: 0.67)
        case .pdf:
            Color(red: 0.91, green: 0.29, blue: 0.28)
        case .link:
            Color(red: 0.29, green: 0.52, blue: 0.96)
        }
    }

    var badgeForegroundColor: Color {
        switch self {
        case .markdown, .image:
            .black.opacity(0.88)
        case .text, .chat, .pdf, .link:
            .white
        }
    }
}

enum PinboardTheme {
    static let canvasTop = BoardBackgroundStyle.midnight.topColor
    static let canvasBottom = BoardBackgroundStyle.midnight.bottomColor
    static let selection = Color(red: 0.54, green: 0.58, blue: 1.0)

    enum Controls {
        static let cardHeaderHeight: CGFloat = 32
        static let cardIconSize: CGFloat = 18
        static let cardButtonSize: CGFloat = 22
        static let cardGlyphSize: CGFloat = 11
        static let toolbarKindIconSize: CGFloat = 20
        static let toolbarButtonSize: CGFloat = 26
        static let toolbarGlyphSize: CGFloat = 12
    }
}
