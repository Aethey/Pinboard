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

enum PinboardTheme {
    static let canvasTop = Color(red: 0.075, green: 0.082, blue: 0.11)
    static let canvasBottom = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let selection = Color(red: 0.54, green: 0.58, blue: 1.0)
}

