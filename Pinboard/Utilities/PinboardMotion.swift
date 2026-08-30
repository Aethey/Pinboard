//
//  PinboardMotion.swift
//  Pinboard
//

import SwiftUI

enum PinboardMotion {
    private static let environment = ProcessInfo.processInfo.environment

    static let isDisabled =
        environment["PINBOARD_MOTION"] == "disabled"
        || ProcessInfo.processInfo.arguments.contains("--disable-animations")

    static func hover(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: expressiveEaseOut(duration: 0.12),
            reduced: .easeOut(duration: 0.08)
        )
    }

    static func cardState(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: expressiveEaseOut(duration: 0.20),
            reduced: .easeOut(duration: 0.12)
        )
    }

    static func cardPickup(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: expressiveEaseOut(duration: 0.14),
            reduced: .easeOut(duration: 0.08)
        )
    }

    static func searchMorph(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: expressiveEaseOut(duration: 0.26),
            reduced: .easeOut(duration: 0.12)
        )
    }

    static func contentChange(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: .easeOut(duration: 0.14),
            reduced: .easeOut(duration: 0.10)
        )
    }

    static func canvas(reduceMotion: Bool) -> Animation? {
        animation(
            reduceMotion: reduceMotion,
            standard: .easeOut(duration: 0.16),
            reduced: .easeOut(duration: 0.10)
        )
    }

    private static func animation(
        reduceMotion: Bool,
        standard: Animation,
        reduced: Animation
    ) -> Animation? {
        guard !isDisabled else { return nil }
        return reduceMotion ? reduced : standard
    }

    private static func expressiveEaseOut(duration: TimeInterval) -> Animation {
        .timingCurve(0.16, 1, 0.30, 1, duration: duration)
    }
}
