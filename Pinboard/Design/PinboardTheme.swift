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

    var highContrastForeground: Color {
        switch self {
        case .teal, .amber:
            .black.opacity(0.88)
        case .graphite, .indigo, .rose:
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
