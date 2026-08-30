//
//  PerformanceTestConfiguration.swift
//  Pinboard
//

import Foundation
import SwiftData

enum PerformanceFixtureProfile: String, CaseIterable {
    case normal
    case heavy
    case stress

    var cardCount: Int {
        switch self {
        case .normal:
            24
        case .heavy:
            150
        case .stress:
            500
        }
    }

    var viewportScale: Double {
        switch self {
        case .normal:
            0.82
        case .heavy:
            0.50
        case .stress:
            0.30
        }
    }
}

struct PerformanceTestConfiguration {
    private static let environment = ProcessInfo.processInfo.environment

    static let isEnabled =
        environment["PINBOARD_PERFORMANCE_TESTING"] == "1"
        || ProcessInfo.processInfo.arguments.contains("--performance-testing")

    static let fixtureProfile: PerformanceFixtureProfile? = {
        guard isEnabled else { return nil }
        if let rawProfile = environment["PINBOARD_PERFORMANCE_FIXTURE"],
           let profile = PerformanceFixtureProfile(rawValue: rawProfile) {
            return profile
        }
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let flagIndex = arguments.firstIndex(of: "--performance-fixture"),
            arguments.indices.contains(flagIndex + 1),
            let profile = PerformanceFixtureProfile(rawValue: arguments[flagIndex + 1])
        else { return .normal }
        return profile
    }()
}

@MainActor
enum PerformanceFixture {
    static let primaryBoardID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let secondaryBoardID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let primaryCardID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!

    static func install(
        profile: PerformanceFixtureProfile,
        in modelContext: ModelContext
    ) -> PinboardBoard {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let primary = PinboardBoard(
            id: primaryBoardID,
            name: "Benchmark A",
            sortOrder: 0,
            viewportScale: profile.viewportScale,
            createdAt: now,
            updatedAt: now
        )
        let secondary = PinboardBoard(
            id: secondaryBoardID,
            name: "Benchmark B",
            sortOrder: 1,
            viewportScale: profile.viewportScale,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(primary)
        modelContext.insert(secondary)

        for board in [primary, secondary] {
            for index in 0..<profile.cardCount {
                modelContext.insert(makeCard(index: index, boardID: board.id, timestamp: now))
            }
        }

        try? modelContext.save()
        return primary
    }

    private static func makeCard(index: Int, boardID: UUID, timestamp: Date) -> BoardCard {
        let kind = benchmarkKinds[index % benchmarkKinds.count]
        let size = size(for: kind)
        let columnCount = 20
        let column = index % columnCount
        let row = index / columnCount
        let x = 180 + Double(column) * 350
        let y = 150 + Double(row) * 280
        let provider = ChatProvider.allCases[index % ChatProvider.allCases.count]

        return BoardCard(
            id: index == 0 && boardID == primaryBoardID
                ? primaryCardID
                : deterministicCardID(index: index, boardID: boardID),
            kind: kind,
            title: "Benchmark \(kind.title) \(index + 1)",
            content: content(for: kind, index: index),
            boardID: boardID,
            imagePixelWidth: kind == .image ? 1600 : nil,
            imagePixelHeight: kind == .image ? 1000 : nil,
            sourceURLString: sourceURL(for: kind, index: index),
            chatProvider: provider,
            linkMetadataState: .ready,
            sourceFileName: kind == .pdf ? "benchmark-\(index + 1).pdf" : nil,
            fileSize: kind == .pdf ? 1_024_000 : nil,
            pageCount: kind == .pdf ? 12 : nil,
            positionX: x,
            positionY: y,
            width: size.width,
            height: size.height,
            theme: CardTheme.allCases[index % CardTheme.allCases.count],
            fontSize: CardFontSize.allCases[index % CardFontSize.allCases.count],
            zIndex: index,
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private static let benchmarkKinds: [CardKind] = [
        .text,
        .markdown,
        .link,
        .chat,
        .pdf,
        .image,
    ]

    private static func size(for kind: CardKind) -> (width: Double, height: Double) {
        switch kind {
        case .text:
            (320, 210)
        case .markdown:
            (320, 240)
        case .chat:
            (440, 340)
        case .image:
            (320, 200)
        case .pdf:
            (360, 220)
        case .link:
            (420, 210)
        }
    }

    private static func content(for kind: CardKind, index: Int) -> String {
        switch kind {
        case .markdown, .chat:
            """
            ## Performance sample \(index + 1)

            - Stable, deterministic content
            - Multiple lines exercise text layout
            - **Bold text** and `inline code`
            """
        case .link:
            "A cached link summary used by the performance fixture."
        case .pdf:
            "benchmark-\(index + 1).pdf\n12 pages"
        case .image:
            ""
        case .text:
            "A deterministic note used to compare Pinboard before and after motion changes.\n\nLine two keeps text layout realistic."
        }
    }

    private static func sourceURL(for kind: CardKind, index: Int) -> String? {
        switch kind {
        case .link:
            "https://example.com/benchmark/\(index + 1)"
        case .chat:
            "https://chatgpt.com/share/benchmark-\(index + 1)"
        default:
            nil
        }
    }

    private static func deterministicCardID(index: Int, boardID: UUID) -> UUID {
        let boardOffset = boardID == primaryBoardID ? 0 : 500_000
        let suffix = String(format: "%012X", boardOffset + index + 1)
        return UUID(uuidString: "20000000-0000-0000-0000-\(suffix)")!
    }
}
