//
//  MarkdownContentView.swift
//  Pinboard
//

import SwiftUI

struct MarkdownContentView: View {
    let markdown: String
    var baseFontSize: CGFloat = 18

    private var lines: [MarkdownLine] {
        markdown
            .components(separatedBy: .newlines)
            .enumerated()
            .map { MarkdownLine(index: $0.offset, source: $0.element) }
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 7) {
            ForEach(lines) { line in
                lineView(line)
            }
        }
        .font(.system(size: baseFontSize))
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func lineView(_ line: MarkdownLine) -> some View {
        switch line.kind {
        case .blank:
            Color.clear
                .frame(height: 3)

        case let .heading(level, content):
            Text(inlineMarkdown(content))
                .font(headingFont(level: level))
                .padding(.top, level == 1 ? 2 : 0)

        case let .bullet(content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(inlineMarkdown(content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .numbered(number, content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(inlineMarkdown(content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .paragraph(content):
            Text(inlineMarkdown(content))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inlineMarkdown(_ source: String) -> AttributedString {
        (try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(source)
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1:
            .system(size: baseFontSize * 1.45, weight: .bold)
        case 2:
            .system(size: baseFontSize * 1.25, weight: .semibold)
        default:
            .system(size: baseFontSize * 1.1, weight: .semibold)
        }
    }
}

private struct MarkdownLine: Identifiable {
    enum Kind {
        case blank
        case heading(level: Int, content: String)
        case bullet(content: String)
        case numbered(number: Int, content: String)
        case paragraph(content: String)
    }

    let index: Int
    let source: String

    var id: Int { index }

    var kind: Kind {
        let trimmed = source.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .blank }

        let headingLevel = min(trimmed.prefix { $0 == "#" }.count, 3)
        if headingLevel > 0 {
            let contentStart = trimmed.index(trimmed.startIndex, offsetBy: headingLevel)
            let content = trimmed[contentStart...].trimmingCharacters(in: .whitespaces)
            return .heading(level: headingLevel, content: content)
        }

        for prefix in ["- ", "* ", "+ ", "• "] where trimmed.hasPrefix(prefix) {
            return .bullet(content: String(trimmed.dropFirst(prefix.count)))
        }

        if
            let separator = trimmed.firstIndex(of: "."),
            let number = Int(trimmed[..<separator]),
            trimmed.index(after: separator) < trimmed.endIndex,
            trimmed[trimmed.index(after: separator)] == " "
        {
            let content = trimmed[trimmed.index(separator, offsetBy: 2)...]
            return .numbered(number: number, content: String(content))
        }

        return .paragraph(content: trimmed)
    }
}
