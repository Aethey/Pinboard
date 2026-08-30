//
//  PinboardTheme.swift
//  Pinboard
//

import SwiftUI

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
    static let canvasTop = Color(red: 0.075, green: 0.082, blue: 0.11)
    static let canvasBottom = Color(red: 0.035, green: 0.039, blue: 0.055)
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
