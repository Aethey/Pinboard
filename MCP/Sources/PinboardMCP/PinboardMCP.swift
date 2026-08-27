import AppKit
import Foundation
import MCP

@main
struct PinboardMCP {
    static func main() async throws {
        let server = Server(
            name: "Pinboard",
            version: "1.0.0",
            instructions: "Create local text and Markdown notes on the user's Pinboard canvas.",
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { _ -> ListTools.Result in
            ListTools.Result(tools: [createNoteTool])
        }

        await server.withMethodHandler(CallTool.self) { parameters -> CallTool.Result in
            guard parameters.name == createNoteTool.name else {
                return CallTool.Result(
                    content: [.text(
                        text: "Unknown tool: \(parameters.name)",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            }

            do {
                let note = try CreateNote(arguments: parameters.arguments)
                let url = try note.deepLinkURL()
                let wasOpened = await PinboardLauncher.open(url)

                guard wasOpened else {
                    return CallTool.Result(
                        content: [.text(
                            text: "Pinboard could not be opened. Build and launch the app once, then retry.",
                            annotations: nil,
                            _meta: nil
                        )],
                        isError: true
                    )
                }

                return CallTool.Result(
                    content: [.text(
                        text: "Created \(note.kind) note \(note.id.uuidString) in Pinboard.",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: false
                )
            } catch {
                return CallTool.Result(
                    content: [.text(
                        text: "Could not create the Pinboard note: \(error.localizedDescription)",
                        annotations: nil,
                        _meta: nil
                    )],
                    isError: true
                )
            }
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)

        // The MCP client owns the lifetime of this local STDIO process.
        try await Task.sleep(nanoseconds: .max)
    }

    private static let createNoteTool = Tool(
        name: "create_note",
        description: "Create a text or Markdown note in the local Pinboard macOS app.",
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "content": .object([
                    "type": "string",
                    "description": "The note body. Markdown is rendered when kind is markdown.",
                    "maxLength": 20_000,
                ]),
                "title": .object([
                    "type": "string",
                    "description": "Optional note title.",
                    "maxLength": 200,
                ]),
                "kind": .object([
                    "type": "string",
                    "description": "The note format. Defaults to text.",
                    "enum": ["text", "markdown"],
                    "default": "text",
                ]),
                "x": .object([
                    "type": "number",
                    "description": "Optional horizontal center position in canvas points.",
                ]),
                "y": .object([
                    "type": "number",
                    "description": "Optional vertical center position in canvas points. Supply x and y together.",
                ]),
                "theme": .object([
                    "type": "string",
                    "description": "Optional card color theme.",
                    "enum": ["graphite", "indigo", "teal", "amber", "rose"],
                ]),
            ]),
            "required": ["content"],
            "additionalProperties": false,
        ])
    )
}

@MainActor
private enum PinboardLauncher {
    private static let bundleIdentifier = "rya.Pinboard"

    static func open(_ deepLink: URL) async -> Bool {
        guard let applicationURL else { return false }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.open(
                [deepLink],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    private static var applicationURL: URL? {
        if let explicitPath = ProcessInfo.processInfo.environment["PINBOARD_APP_PATH"] {
            let explicitURL = URL(fileURLWithPath: explicitPath, isDirectory: true)
            if FileManager.default.fileExists(atPath: explicitURL.path) {
                return explicitURL
            }
        }

        if let embeddedApplicationURL {
            return embeddedApplicationURL
        }

        if let runningURL = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { !$0.isTerminated })?
            .bundleURL {
            return runningURL
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    private static var embeddedApplicationURL: URL? {
        let executablePath = CommandLine.arguments[0]
        var candidate = URL(fileURLWithPath: executablePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()

        while candidate.path != "/" {
            if candidate.pathExtension == "app",
               FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return nil
    }
}

private struct CreateNote: Encodable {
    let id: UUID
    let kind: String
    let title: String?
    let content: String
    let x: Double?
    let y: Double?
    let theme: String?

    init(arguments: [String: Value]?) throws {
        let arguments = arguments ?? [:]

        guard let content = arguments["content"]?.stringValue else {
            throw CreateNoteError.missingContent
        }
        guard content.count <= 20_000 else {
            throw CreateNoteError.contentTooLong
        }

        let title = arguments["title"]?.stringValue
        guard title?.count ?? 0 <= 200 else {
            throw CreateNoteError.titleTooLong
        }

        let kind = arguments["kind"]?.stringValue ?? "text"
        guard ["text", "markdown"].contains(kind) else {
            throw CreateNoteError.invalidKind
        }

        let x = numericValue(arguments["x"])
        let y = numericValue(arguments["y"])
        guard (x == nil) == (y == nil) else {
            throw CreateNoteError.incompletePosition
        }
        guard [x, y].compactMap({ $0 }).allSatisfy(\.isFinite) else {
            throw CreateNoteError.invalidPosition
        }

        let theme = arguments["theme"]?.stringValue
        guard theme.map({ ["graphite", "indigo", "teal", "amber", "rose"].contains($0) }) ?? true else {
            throw CreateNoteError.invalidTheme
        }

        self.id = UUID()
        self.kind = kind
        self.title = title
        self.content = content
        self.x = x
        self.y = y
        self.theme = theme
    }

    func deepLinkURL() throws -> URL {
        let payload = try JSONEncoder().encode(self).base64URLEncodedString()
        var components = URLComponents()
        components.scheme = "pinboard"
        components.host = "create-note"
        components.queryItems = [URLQueryItem(name: "payload", value: payload)]

        guard let url = components.url else {
            throw CreateNoteError.invalidURL
        }
        return url
    }
}

private func numericValue(_ value: Value?) -> Double? {
    switch value {
    case let .int(number):
        Double(number)
    case let .double(number):
        number
    default:
        nil
    }
}

private enum CreateNoteError: LocalizedError {
    case missingContent
    case contentTooLong
    case titleTooLong
    case invalidKind
    case incompletePosition
    case invalidPosition
    case invalidTheme
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingContent:
            "content is required and must be a string"
        case .contentTooLong:
            "content must contain no more than 20,000 characters"
        case .titleTooLong:
            "title must contain no more than 200 characters"
        case .invalidKind:
            "kind must be text or markdown"
        case .incompletePosition:
            "x and y must be supplied together"
        case .invalidPosition:
            "x and y must be finite numbers"
        case .invalidTheme:
            "theme must be graphite, indigo, teal, amber, or rose"
        case .invalidURL:
            "the Pinboard URL could not be constructed"
        }
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
