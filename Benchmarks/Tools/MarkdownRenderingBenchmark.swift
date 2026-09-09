// Standalone AppKit/SwiftUI workload; uses the production MarkdownContentView.
// No XCTest runner, persistence, or user boards are involved.
import AppKit
import Darwin
import SwiftUI

// Only referenced by the production file's Xcode preview.
enum PinboardTheme { static let canvasBottom = Color.black }

private func document(_ index: Int) -> String {
    (0..<24).map { section in
        """
        ## Card \(index + 1) / Section \(section + 1)

        Markdown scrolling sample with **bold**, *italic*, `inline code` and [a link](https://example.com).
        多张 Markdown 卡片同时显示，滚动时应保持流畅，并保留换行、字号和文字选择。
        - First item with enough text to wrap across several lines in a narrow card.
        - Second item with **formatting** and `code`.
        1. Numbered item

        | Feature | Description | Status |
        | :--- | :--- | ---: |
        | Scrolling | Preserve smooth scrolling and text selection | Ready |
        | Layout | Wrap paragraphs but allow wide tables to scroll horizontally | Ready |

        """
    }.joined(separator: "\n")
}

private struct Workload: View {
    let documents: [String]
    let target: Int
    let offset: CGFloat
    var fontSize: CGFloat = 18
    var textWidth: CGFloat = 300

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.gray.opacity(0.2)
            ForEach(documents.indices, id: \.self) { index in
                ScrollViewReader { proxy in
                    ScrollView([.horizontal, .vertical]) {
                        preview(documents[index])
                            .textSelection(.enabled)
                            .padding(10)
                    }
                    .onChange(of: target) { _, value in
                        if index == 0 { proxy.scrollTo(value, anchor: .topLeading) }
                    }
                }
                .frame(width: 320, height: 240)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 8, y: 4)
                .offset(x: CGFloat(index % 4) * 330 + 10,
                        y: CGFloat(index / 4) * 250 + 10 + offset)
            }
        }
        .frame(width: 1_200, height: 800, alignment: .topLeading)
        .clipped()
    }

    @ViewBuilder private func preview(_ source: String) -> some View {
        #if MARKDOWN_OPTIMIZED
        MarkdownContentView(markdown: source, baseFontSize: fontSize, textWidth: textWidth).equatable()
        #else
        MarkdownContentView(markdown: source, baseFontSize: fontSize, textWidth: textWidth)
        #endif
    }
}

@main @MainActor
enum MarkdownRenderingBenchmark {
    static func cpuTime() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }

    static func settle(_ host: NSView) {
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    static func main() {
        let verifyOnly = ProcessInfo.processInfo.environment["PINBOARD_BENCHMARK_VERIFY_ONLY"] == "1"
        let docs = (0..<12).map(document)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let window = NSWindow(contentRect: NSRect(x: 30, y: 30, width: 1_200, height: 800),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Pinboard Markdown benchmark (temporary fixture)"
        window.isReleasedWhenClosed = false

        let startCPU = cpuTime()
        let startWall = ProcessInfo.processInfo.systemUptime
        let host = NSHostingView(rootView: Workload(documents: docs, target: 0, offset: 0))
        window.contentView = host
        window.orderFront(nil)
        for _ in 0..<5 { settle(host) }
        var samples: [[String: Any]] = [[
            "operation": "initial_layout", "iteration": 1,
            "cpu_seconds": cpuTime() - startCPU,
            "wall_seconds": ProcessInfo.processInfo.systemUptime - startWall
        ]]

        for operation in (verifyOnly ? [] : ["scroll_first_card", "pan_all_cards"]) {
            for iteration in 1...5 {
                let cpu = cpuTime()
                let wall = ProcessInfo.processInfo.systemUptime
                for step in 0..<6 {
                    let target = operation == "scroll_first_card" && step.isMultiple(of: 2) ? 120 : 0
                    let offset: CGFloat = operation == "pan_all_cards" && step.isMultiple(of: 2) ? -100 : 0
                    host.rootView = Workload(documents: docs, target: target, offset: offset)
                    settle(host)
                }
                samples.append([
                    "operation": operation, "iteration": iteration,
                    "cpu_seconds": cpuTime() - cpu,
                    "wall_seconds": ProcessInfo.processInfo.systemUptime - wall
                ])
            }
        }
        if let path = ProcessInfo.processInfo.environment["PINBOARD_BENCHMARK_SCREENSHOT"],
           let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        if verifyOnly {
            // Verify lazy rows can reach a table and the end of the document.
            let lines = docs[0].components(separatedBy: "\n")
            let targets = [
                "table": lines.firstIndex(where: { $0.hasPrefix("| Feature") })!,
                "end": lines.lastIndex(where: { $0.hasPrefix("## Card") })!
            ]
            for name in ["table", "end", "edited"] {
                var content = docs
                if name == "edited" { content[0] = "## UPDATED preview\n\n**Changed text** and `code`." }
                host.rootView = Workload(documents: content, target: targets[name] ?? 0, offset: 0,
                                         fontSize: name == "edited" ? 24 : 18,
                                         textWidth: name == "edited" ? 260 : 300)
                for _ in 0..<5 { settle(host) }
                if let path = ProcessInfo.processInfo.environment["PINBOARD_BENCHMARK_SCREENSHOT"],
                   let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + "." + name + ".png"))
                }
            }
        }
        // Exercise the shared parser/column sizing used by Fit Content after
        // text, width and font changes; compare these values between versions.
        let sources = ["", docs[0], "## UPDATED\n\nDifferent text.",
                       "| A | B |\n| --- | ---: |\n| escaped \\| pipe | `a|b` |\n| short |"]
        let fittedHeights = sources.flatMap { source in
            [CGFloat(220), 300, 500].flatMap { width in
                [CGFloat(12), 18, 24].map { font in
                    MarkdownContentView.fittingHeight(markdown: source, baseFontSize: font, textWidth: width)
                }
            }
        }
        let output: [String: Any] = [
            "harness": "Standalone NSHostingView; programmatic scroll targets and offsets, not trackpad events",
            "cards": docs.count, "sections_per_card": 24, "samples": samples,
            "verification_only": verifyOnly, "fitted_heights": fittedHeights,
            "os": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        let json = try! JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: json, as: UTF8.self))
        window.close()
    }
}
