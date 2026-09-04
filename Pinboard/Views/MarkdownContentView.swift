//
//  MarkdownContentView.swift
//  Pinboard
//

import AppKit
import SwiftUI

struct MarkdownContentView: View {
    let markdown: String
    var baseFontSize: CGFloat = 18
    var textWidth: CGFloat?

    private var blocks: [MarkdownBlock] {
        MarkdownBlockParser.parse(markdown)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(blocks) { block in
                blockView(block)
            }
        }
        .font(.system(size: baseFontSize))
        .frame(minWidth: textWidth ?? 0, alignment: .topLeading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .line(line):
            if let textWidth {
                lineView(line)
                    .frame(width: textWidth, alignment: .leading)
            } else {
                lineView(line)
            }

        case let .table(table):
            MarkdownTableView(table: table, baseFontSize: baseFontSize)
        }
    }

    @ViewBuilder
    private func lineView(_ line: MarkdownLine) -> some View {
        switch line.kind {
        case .blank:
            Color.clear
                .frame(height: 3)

        case let .heading(level, content):
            Text(parseInlineMarkdown(content))
                .font(headingFont(level: level))
                .padding(.top, level == 1 ? 2 : 0)

        case let .bullet(content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text(parseInlineMarkdown(content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .numbered(number, content):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(number).")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(parseInlineMarkdown(content))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case let .paragraph(content):
            Text(parseInlineMarkdown(content))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

    static func fittingHeight(
        markdown: String,
        baseFontSize: CGFloat,
        textWidth: CGFloat
    ) -> CGFloat {
        let blocks = MarkdownBlockParser.parse(markdown)
        let blockHeights = blocks.map { block -> CGFloat in
            switch block.kind {
            case let .line(line):
                lineFittingHeight(line, baseFontSize: baseFontSize, textWidth: textWidth)
            case let .table(table):
                tableFittingHeight(table, baseFontSize: baseFontSize)
            }
        }
        return ceil(blockHeights.reduce(0, +) + CGFloat(max(0, blocks.count - 1)) * 7 + 2)
    }

    private static func lineFittingHeight(
        _ line: MarkdownLine,
        baseFontSize: CGFloat,
        textWidth: CGFloat
    ) -> CGFloat {
        switch line.kind {
        case .blank:
            return 3

        case let .heading(level, content):
            let size: CGFloat
            let weight: NSFont.Weight
            switch level {
            case 1:
                size = baseFontSize * 1.45
                weight = .bold
            case 2:
                size = baseFontSize * 1.25
                weight = .semibold
            default:
                size = baseFontSize * 1.1
                weight = .semibold
            }
            return measuredHeight(
                content,
                font: .systemFont(ofSize: size, weight: weight),
                width: textWidth
            ) + (level == 1 ? 2 : 0)

        case let .bullet(content):
            let font = NSFont.systemFont(ofSize: baseFontSize)
            let prefixWidth = measuredWidth("•", font: font) + 7
            return measuredHeight(content, font: font, width: textWidth - prefixWidth)

        case let .numbered(number, content):
            let font = NSFont.systemFont(ofSize: baseFontSize)
            let prefixWidth = measuredWidth("\(number).", font: font) + 7
            return measuredHeight(content, font: font, width: textWidth - prefixWidth)

        case let .paragraph(content):
            return measuredHeight(
                content,
                font: .systemFont(ofSize: baseFontSize, weight: .medium),
                width: textWidth
            )
        }
    }

    private static func tableFittingHeight(
        _ table: MarkdownTable,
        baseFontSize: CGFloat
    ) -> CGFloat {
        let columnWidths = table.header.indices.map { column in
            let values = [table.header[column]] + table.rows.map { $0[column] }
            let longestValue = values.map(\.count).max() ?? 0
            let estimatedWidth = CGFloat(longestValue) * baseFontSize * 0.52 + 16
            return min(280, max(72, estimatedWidth))
        }
        let rows = [table.header] + table.rows
        let rowsHeight = rows.enumerated().reduce(CGFloat.zero) { result, row in
            let font = NSFont.systemFont(
                ofSize: max(10, baseFontSize * 0.82),
                weight: row.offset == 0 ? .semibold : .regular
            )
            let height = row.element.enumerated().reduce(CGFloat.zero) { maximum, cell in
                max(
                    maximum,
                    measuredHeight(
                        cell.element,
                        font: font,
                        width: columnWidths[cell.offset] - 16
                    ) + 12
                )
            }
            return result + height
        }
        return rowsHeight + CGFloat(max(0, rows.count - 1))
    }

    private static func measuredHeight(_ text: String, font: NSFont, width: CGFloat) -> CGFloat {
        let displayText = text.isEmpty ? " " : text
        let bounds = (displayText as NSString).boundingRect(
            with: CGSize(width: max(1, width * 0.96), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(max(font.ascender - font.descender + font.leading, bounds.height))
    }

    private static func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private struct MarkdownTableView: View {
    let table: MarkdownTable
    let baseFontSize: CGFloat

    private var columnWidths: [CGFloat] {
        table.header.indices.map { column in
            let values = [table.header[column]] + table.rows.map { $0[column] }
            let longestValue = values.map(\.count).max() ?? 0
            let estimatedWidth = CGFloat(longestValue) * baseFontSize * 0.52 + 16
            return min(280, max(72, estimatedWidth))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tableRow(table.header, row: 0, isHeader: true)

            ForEach(Array(table.rows.enumerated()), id: \.offset) { row, cells in
                tableRow(cells, row: row + 1, isHeader: false)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.primary.opacity(0.16), lineWidth: 0.75)
        }
    }

    private func tableRow(
        _ cells: [String],
        row: Int,
        isHeader: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { column, cell in
                    tableCell(cell, column: column, isHeader: isHeader)

                    if column < cells.count - 1 {
                        Divider()
                    }
                }
            }
            .background(cellBackground(row: row, isHeader: isHeader))

            if row < table.rows.count {
                Divider()
            }
        }
    }

    private func tableCell(
        _ source: String,
        column: Int,
        isHeader: Bool
    ) -> some View {
        let alignment = table.alignments[column]

        return Text(parseInlineMarkdown(source))
            .font(.system(
                size: max(10, baseFontSize * 0.82),
                weight: isHeader ? .semibold : .regular
            ))
            .multilineTextAlignment(alignment.textAlignment)
            .frame(width: max(0, columnWidths[column] - 16), alignment: alignment.frameAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    private func cellBackground(row: Int, isHeader: Bool) -> Color {
        if isHeader {
            return .primary.opacity(0.10)
        }
        return row.isMultiple(of: 2) ? .primary.opacity(0.035) : .clear
    }
}

private struct MarkdownBlock: Identifiable {
    enum Kind {
        case line(MarkdownLine)
        case table(MarkdownTable)
    }

    let id: Int
    let kind: Kind
}

private struct MarkdownTable {
    let header: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]
}

private enum MarkdownTableAlignment {
    case leading
    case center
    case trailing

    var frameAlignment: Alignment {
        switch self {
        case .leading:
            .topLeading
        case .center:
            .top
        case .trailing:
            .topTrailing
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading:
            .leading
        case .center:
            .center
        case .trailing:
            .trailing
        }
    }
}

private enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var lineIndex = 0

        while lineIndex < lines.count {
            if let table = table(startingAt: lineIndex, in: lines) {
                blocks.append(MarkdownBlock(id: lineIndex, kind: .table(table.value)))
                lineIndex = table.nextLineIndex
            } else {
                let line = MarkdownLine(source: lines[lineIndex])
                blocks.append(MarkdownBlock(id: lineIndex, kind: .line(line)))
                lineIndex += 1
            }
        }

        return blocks
    }

    private static func table(
        startingAt startIndex: Int,
        in lines: [String]
    ) -> (value: MarkdownTable, nextLineIndex: Int)? {
        guard
            startIndex + 1 < lines.count,
            let header = splitTableRow(lines[startIndex]),
            header.count >= 2,
            let alignments = delimiterAlignments(
                lines[startIndex + 1],
                columnCount: header.count
            )
        else { return nil }

        var rows: [[String]] = []
        var nextLineIndex = startIndex + 2

        while nextLineIndex < lines.count {
            let source = lines[nextLineIndex]
            guard !source.trimmingCharacters(in: .whitespaces).isEmpty else { break }
            guard let cells = splitTableRow(source) else { break }

            rows.append(normalized(cells, columnCount: header.count))
            nextLineIndex += 1
        }

        return (
            MarkdownTable(
                header: header,
                alignments: alignments,
                rows: rows
            ),
            nextLineIndex
        )
    }

    private static func delimiterAlignments(
        _ source: String,
        columnCount: Int
    ) -> [MarkdownTableAlignment]? {
        guard
            let cells = splitTableRow(source),
            cells.count == columnCount
        else { return nil }

        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            guard let alignment = delimiterAlignment(cell) else { return nil }
            alignments.append(alignment)
        }
        return alignments
    }

    private static func delimiterAlignment(_ source: String) -> MarkdownTableAlignment? {
        let delimiter = source.trimmingCharacters(in: .whitespaces)
        let isLeadingColon = delimiter.hasPrefix(":")
        let isTrailingColon = delimiter.hasSuffix(":")
        let dashes = delimiter.trimmingCharacters(in: CharacterSet(charactersIn: ":"))

        guard dashes.count >= 3, dashes.allSatisfy({ $0 == "-" }) else { return nil }

        switch (isLeadingColon, isTrailingColon) {
        case (true, true):
            return .center
        case (false, true):
            return .trailing
        default:
            return .leading
        }
    }

    private static func normalized(_ cells: [String], columnCount: Int) -> [String] {
        if cells.count >= columnCount {
            return Array(cells.prefix(columnCount))
        }
        return cells + Array(repeating: "", count: columnCount - cells.count)
    }

    private static func splitTableRow(_ source: String) -> [String]? {
        var row = source.trimmingCharacters(in: .whitespaces)
        guard containsTableSeparator(row) else { return nil }

        if row.first == "|" {
            row.removeFirst()
        }
        if hasUnescapedTrailingPipe(row) {
            row.removeLast()
        }

        var cells: [String] = []
        var currentCell = ""
        var isEscaped = false
        var isInsideCode = false

        for character in row {
            if isEscaped {
                currentCell.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                currentCell.append(character)
                isEscaped = true
                continue
            }

            if character == "`" {
                isInsideCode.toggle()
                currentCell.append(character)
                continue
            }

            if character == "|", !isInsideCode {
                cells.append(currentCell.trimmingCharacters(in: .whitespaces))
                currentCell = ""
            } else {
                currentCell.append(character)
            }
        }

        cells.append(currentCell.trimmingCharacters(in: .whitespaces))
        return cells.count >= 2 ? cells : nil
    }

    private static func containsTableSeparator(_ source: String) -> Bool {
        var isEscaped = false
        var isInsideCode = false

        for character in source {
            if isEscaped {
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == "`" {
                isInsideCode.toggle()
                continue
            }
            if character == "|", !isInsideCode {
                return true
            }
        }

        return false
    }

    private static func hasUnescapedTrailingPipe(_ source: String) -> Bool {
        guard source.last == "|" else { return false }
        let backslashCount = source.dropLast().reversed().prefix { $0 == "\\" }.count
        return backslashCount.isMultiple(of: 2)
    }
}

private struct MarkdownLine {
    enum Kind {
        case blank
        case heading(level: Int, content: String)
        case bullet(content: String)
        case numbered(number: Int, content: String)
        case paragraph(content: String)
    }

    let source: String

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

private func parseInlineMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(
        markdown: source,
        options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    )) ?? AttributedString(source)
}

#Preview("Markdown table") {
    GeometryReader { geometry in
        ScrollView([.horizontal, .vertical]) {
            MarkdownContentView(
                markdown: """
                # Roadmap

                | Priority | Feature | Value | Effort |
                | :--- | :--- | :--- | ---: |
                | P0 | Quick capture | Create a note at the pointer and focus it immediately. | Small |
                | P1 | Search | Find **titles** and `inline code`, then bring the result forward. | Medium |
                | P2 | Export | Back up a board as Markdown or JSON. | Large |
                """,
                textWidth: max(0, geometry.size.width - 32)
            )
            .padding(16)
        }
    }
    .frame(width: 680, height: 320)
    .background(PinboardTheme.canvasBottom)
}
