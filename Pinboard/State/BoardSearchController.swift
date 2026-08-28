//
//  BoardSearchController.swift
//  Pinboard
//

import Foundation
import Observation

struct BoardSearchResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let kindRawValue: String
    let title: String
    let snippet: String
}

@MainActor
@Observable
final class BoardSearchController {
    var isPresented = false
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }
    private(set) var results: [BoardSearchResult] = []
    private(set) var recentQueries: [String]
    private(set) var matchingCardIDs: Set<UUID> = []
    private(set) var resolvedQuery = ""
    private(set) var isSearching = false

    @ObservationIgnored private var documents: [IndexedSearchDocument] = []
    @ObservationIgnored private var indexTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var indexGeneration = UUID()
    @ObservationIgnored private var searchGeneration = UUID()

    private static let historyKey = "boardSearchHistory"
    private static let maximumHistoryCount = 10

    init() {
        recentQueries = Self.loadHistory()
    }

    var hasResolvedFilter: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && query == resolvedQuery
    }

    func open() {
        isPresented = true
    }

    func close() {
        isPresented = false
        query = ""
        results = []
        matchingCardIDs = []
        resolvedQuery = ""
        isSearching = false
        searchTask?.cancel()
    }

    func useRecentQuery(_ recentQuery: String) {
        query = recentQuery
    }

    func recordCurrentQuery() {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        recentQueries.removeAll {
            $0.compare(value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        recentQueries.insert(value, at: 0)
        recentQueries = Array(recentQueries.prefix(Self.maximumHistoryCount))
        Self.saveHistory(recentQueries)
    }

    func opacity(for cardID: UUID) -> Double {
        guard isPresented, hasResolvedFilter else { return 1 }
        return matchingCardIDs.contains(cardID) ? 1 : 0.20
    }

    func updateDocuments(from cards: [BoardCard]) {
        let generation = UUID()
        indexGeneration = generation
        indexTask?.cancel()

        indexTask = Task { [weak self] in
            do {
                // Editing updates SwiftData on every keystroke. Wait for a short idle
                // window so a fast typist never causes repeated full-board indexing.
                try await Task.sleep(for: .milliseconds(180))
            } catch {
                return
            }

            guard
                !Task.isCancelled,
                let self,
                self.indexGeneration == generation
            else { return }

            let sourceDocuments = cards.map {
                SearchSourceDocument(
                    id: $0.id,
                    kindRawValue: $0.kindRawValue,
                    title: $0.title,
                    content: $0.content,
                    updatedAt: $0.updatedAt
                )
            }
            let indexedDocuments = await Task.detached(priority: .utility) {
                BoardSearchEngine.makeIndex(sourceDocuments)
            }.value

            guard
                !Task.isCancelled,
                self.indexGeneration == generation
            else { return }

            self.documents = indexedDocuments
            self.scheduleSearch()
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let generation = UUID()
        searchGeneration = generation
        results = []
        matchingCardIDs = []
        resolvedQuery = ""

        let submittedQuery = query
        guard !submittedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSearching = false
            return
        }

        isSearching = true
        let indexedDocuments = documents

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(70))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            let output = await Task.detached(priority: .userInitiated) {
                BoardSearchEngine.search(submittedQuery, in: indexedDocuments)
            }.value

            guard
                !Task.isCancelled,
                let self,
                self.searchGeneration == generation,
                self.query == submittedQuery
            else { return }

            self.results = output.results
            self.matchingCardIDs = output.matchingCardIDs
            self.resolvedQuery = submittedQuery
            self.isSearching = false
        }
    }

    private static func loadHistory() -> [String] {
        guard
            let data = UserDefaults.standard.data(forKey: historyKey),
            let values = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }

        return Array(values.prefix(maximumHistoryCount))
    }

    private static func saveHistory(_ history: [String]) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

private struct SearchSourceDocument: Sendable {
    let id: UUID
    let kindRawValue: String
    let title: String
    let content: String
    let updatedAt: Date
}

private struct IndexedSearchDocument: Sendable {
    let source: SearchSourceDocument
    let normalizedTitle: String
    let normalizedContent: String
}

private struct BoardSearchOutput: Sendable {
    let results: [BoardSearchResult]
    let matchingCardIDs: Set<UUID>
}

private enum BoardSearchEngine {
    nonisolated static func makeIndex(
        _ documents: [SearchSourceDocument]
    ) -> [IndexedSearchDocument] {
        documents.map {
            IndexedSearchDocument(
                source: $0,
                normalizedTitle: normalize($0.title),
                normalizedContent: normalize($0.content)
            )
        }
    }

    nonisolated static func search(
        _ query: String,
        in documents: [IndexedSearchDocument]
    ) -> BoardSearchOutput {
        let normalizedQuery = normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        let tokens = normalizedQuery.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else {
            return BoardSearchOutput(results: [], matchingCardIDs: [])
        }

        var matches: [(document: IndexedSearchDocument, score: Int)] = []

        for document in documents {
            if Task.isCancelled { break }

            let containsEveryToken = tokens.allSatisfy { token in
                document.normalizedTitle.contains(token)
                    || document.normalizedContent.contains(token)
            }
            guard containsEveryToken else { continue }

            var score = 100
            if document.normalizedTitle == normalizedQuery {
                score += 1_000
            } else if document.normalizedTitle.hasPrefix(normalizedQuery) {
                score += 700
            } else if document.normalizedTitle.contains(normalizedQuery) {
                score += 500
            } else if document.normalizedContent.contains(normalizedQuery) {
                score += 260
            }
            score += tokens.reduce(into: 0) { partialResult, token in
                if document.normalizedTitle.hasPrefix(token) {
                    partialResult += 90
                } else if document.normalizedTitle.contains(token) {
                    partialResult += 45
                }
            }

            matches.append((document, score))
        }

        matches.sort {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.document.source.updatedAt > $1.document.source.updatedAt
        }

        let matchingCardIDs = Set(matches.map(\.document.source.id))
        let results = matches.prefix(10).map { match in
            BoardSearchResult(
                id: match.document.source.id,
                kindRawValue: match.document.source.kindRawValue,
                title: match.document.source.title,
                snippet: snippet(from: match.document.source.content, matching: query)
            )
        }

        return BoardSearchOutput(
            results: results,
            matchingCardIDs: matchingCardIDs
        )
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    nonisolated private static func snippet(
        from content: String,
        matching query: String
    ) -> String {
        let flattened = content
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !flattened.isEmpty else { return "Title match" }

        guard let match = flattened.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        ) else {
            return String(flattened.prefix(120))
        }

        let start = flattened.index(
            match.lowerBound,
            offsetBy: -36,
            limitedBy: flattened.startIndex
        ) ?? flattened.startIndex
        let end = flattened.index(
            match.upperBound,
            offsetBy: 84,
            limitedBy: flattened.endIndex
        ) ?? flattened.endIndex
        let leadingEllipsis = start == flattened.startIndex ? "" : "…"
        let trailingEllipsis = end == flattened.endIndex ? "" : "…"
        return leadingEllipsis + flattened[start..<end] + trailingEllipsis
    }
}
