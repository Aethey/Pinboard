import AppKit
import Darwin
import Foundation
import MCP

@main
struct PinboardMCP {
    static func main() async throws {
        let server = Server(
            name: "Pinboard",
            version: "1.2.0",
            instructions: """
            Create local notes and save useful AI conversations to the user's Pinboard canvas.
            When the user asks to save, pin, archive, or remember the current chat, do not ask
            them to summarize it manually. Distill the conversation yourself, infer the AI
            provider, generate a useful title, and call save_chat. Include a real share URL only
            when one is already available in the conversation or client context; never invent one.
            """,
            capabilities: .init(tools: .init(listChanged: false))
        )

        await server.withMethodHandler(ListTools.self) { _ -> ListTools.Result in
            ListTools.Result(tools: [createNoteTool, saveChatTool])
        }

        await server.withMethodHandler(CallTool.self) { parameters -> CallTool.Result in
            do {
                let url: URL
                let successMessage: String

                switch parameters.name {
                case createNoteTool.name:
                    let note = try CreateNote(arguments: parameters.arguments)
                    url = try note.deepLinkURL()
                    successMessage = "Created \(note.kind) note \(note.id.uuidString) in Pinboard."

                case saveChatTool.name:
                    let chat = try SaveChat(arguments: parameters.arguments)
                    url = try chat.deepLinkURL()
                    successMessage = "Saved \(chat.providerTitle) chat \(chat.id.uuidString) in Pinboard."

                default:
                    return CallTool.Result(
                        content: [.text(
                            text: "Unknown tool: \(parameters.name)",
                            annotations: nil,
                            _meta: nil
                        )],
                        isError: true
                    )
                }

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
                        text: successMessage,
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

    private static let saveChatTool = Tool(
        name: "save_chat",
        description: """
        Organize the current AI conversation and save it as a Chat card in the local Pinboard
        macOS app. Use this when the user asks to save, pin, archive, collect, or remember the
        current chat. Before calling, generate the title and concise Markdown summary yourself
        from the conversation already in context; do not ask the user to prepare or paste a
        summary. Preserve the objective, important context, decisions, conclusions, unresolved
        questions, and next actions when relevant. Do not copy the full transcript. Infer the
        provider from the current AI client. Include share_url only if a real share link is
        already available; omit it rather than asking for one or fabricating one.
        """,
        inputSchema: .object([
            "type": "object",
            "properties": .object([
                "title": .object([
                    "type": "string",
                    "description": "A concise, specific title generated from the conversation.",
                    "maxLength": 200,
                ]),
                "summary_markdown": .object([
                    "type": "string",
                    "description": """
                    A durable Markdown summary generated from the current conversation. Prefer
                    short sections such as Overview, Key points, Decisions, and Next actions,
                    omitting empty sections. Never paste the complete transcript.
                    """,
                    "maxLength": 20_000,
                ]),
                "provider": .object([
                    "type": "string",
                    "description": """
                    Infer this from the current AI client: chatgpt for ChatGPT or OpenAI,
                    claude for Anthropic Claude, gemini for Google Gemini, cursor for Cursor,
                    codex for Codex, otherwise other. Do not ask the user to choose it.
                    """,
                    "enum": ["chatgpt", "claude", "gemini", "cursor", "codex", "other"],
                ]),
                "share_url": .object([
                    "type": "string",
                    "description": """
                    Optional real HTTP(S) share link for the original conversation. Supply it
                    only when it is already available in context; never invent a URL.
                    """,
                    "maxLength": 2_048,
                ]),
                "x": .object([
                    "type": "number",
                    "description": "Optional horizontal center position in canvas points.",
                ]),
                "y": .object([
                    "type": "number",
                    "description": "Optional vertical center position in canvas points. Supply x and y together.",
                ]),
            ]),
            "required": ["title", "summary_markdown", "provider"],
            "additionalProperties": false,
        ])
    )
}

@MainActor
private enum PinboardLauncher {
    private static let bundleIdentifier = "rya.Pinboard"

    static func open(_ deepLink: URL) async -> Bool {
        if await LocalPinboardBridge.send(deepLink) {
            return true
        }

        guard let applicationURL else { return false }
        return await open(deepLink, withApplicationAt: applicationURL)
    }

    private static func open(
        _ deepLink: URL,
        withApplicationAt applicationURL: URL
    ) async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

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

private enum LocalPinboardBridge {
    private static let port: UInt16 = 17_373
    private static let acknowledgement = "OK\n"

    static func send(_ deepLink: URL) async -> Bool {
        let urlString = deepLink.absoluteString
        return await Task.detached(priority: .userInitiated) {
            send(urlString)
        }.value
    }

    private static func send(_ urlString: String) -> Bool {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else { return false }
        defer { Darwin.close(socketDescriptor) }

        var timeout = timeval(tv_sec: 0, tv_usec: 750_000)
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_SNDTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )
        setsockopt(
            socketDescriptor,
            SOL_SOCKET,
            SO_RCVTIMEO,
            &timeout,
            socklen_t(MemoryLayout<timeval>.size)
        )

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, "127.0.0.1", &address.sin_addr) == 1 else {
            return false
        }

        let connectionResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(
                    socketDescriptor,
                    $0,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                )
            }
        }
        guard connectionResult == 0 else { return false }

        let payload = Data((urlString + "\n").utf8)
        let didSendAllBytes = payload.withUnsafeBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            var bytesSent = 0
            while bytesSent < rawBuffer.count {
                let result = Darwin.send(
                    socketDescriptor,
                    baseAddress.advanced(by: bytesSent),
                    rawBuffer.count - bytesSent,
                    0
                )
                guard result > 0 else { return false }
                bytesSent += result
            }
            return true
        }
        guard didSendAllBytes else { return false }

        var response = [UInt8](repeating: 0, count: acknowledgement.utf8.count)
        let receivedCount = Darwin.recv(
            socketDescriptor,
            &response,
            response.count,
            0
        )
        guard receivedCount > 0 else { return false }
        return String(decoding: response.prefix(receivedCount), as: UTF8.self)
            .hasPrefix("OK")
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

private struct SaveChat: Encodable {
    let id: UUID
    let kind = "chat"
    let title: String
    let content: String
    let x: Double?
    let y: Double?
    let theme: String? = nil
    let chatProvider: String
    let sourceURL: String?

    var providerTitle: String {
        switch chatProvider {
        case "chatgpt":
            "ChatGPT"
        case "claude":
            "Claude"
        case "gemini":
            "Gemini"
        case "cursor":
            "Cursor"
        case "codex":
            "Codex"
        default:
            "AI"
        }
    }

    init(arguments: [String: Value]?) throws {
        let arguments = arguments ?? [:]

        guard let rawTitle = arguments["title"]?.stringValue else {
            throw SaveChatError.missingTitle
        }
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw SaveChatError.missingTitle
        }
        guard title.count <= 200 else {
            throw SaveChatError.titleTooLong
        }

        guard let rawSummary = arguments["summary_markdown"]?.stringValue else {
            throw SaveChatError.missingSummary
        }
        let summary = rawSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            throw SaveChatError.missingSummary
        }
        guard summary.count <= 20_000 else {
            throw SaveChatError.summaryTooLong
        }

        guard let provider = arguments["provider"]?.stringValue,
              ["chatgpt", "claude", "gemini", "cursor", "codex", "other"].contains(provider) else {
            throw SaveChatError.invalidProvider
        }

        let shareURL = arguments["share_url"]?.stringValue
        if let shareURL {
            guard shareURL.count <= 2_048,
                  let parsedURL = URL(string: shareURL),
                  let scheme = parsedURL.scheme?.lowercased(),
                  scheme == "https" || scheme == "http",
                  parsedURL.host() != nil else {
                throw SaveChatError.invalidShareURL
            }
        }

        let x = numericValue(arguments["x"])
        let y = numericValue(arguments["y"])
        guard (x == nil) == (y == nil) else {
            throw SaveChatError.incompletePosition
        }
        guard [x, y].compactMap({ $0 }).allSatisfy(\.isFinite) else {
            throw SaveChatError.invalidPosition
        }

        self.id = UUID()
        self.title = title
        self.content = summary
        self.x = x
        self.y = y
        self.chatProvider = provider
        self.sourceURL = shareURL
    }

    func deepLinkURL() throws -> URL {
        let payload = try JSONEncoder().encode(self).base64URLEncodedString()
        var components = URLComponents()
        components.scheme = "pinboard"
        components.host = "create-note"
        components.queryItems = [URLQueryItem(name: "payload", value: payload)]

        guard let url = components.url else {
            throw SaveChatError.invalidURL
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

private enum SaveChatError: LocalizedError {
    case missingTitle
    case titleTooLong
    case missingSummary
    case summaryTooLong
    case invalidProvider
    case invalidShareURL
    case incompletePosition
    case invalidPosition
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            "title is required and must not be empty"
        case .titleTooLong:
            "title must contain no more than 200 characters"
        case .missingSummary:
            "summary_markdown is required and must not be empty"
        case .summaryTooLong:
            "summary_markdown must contain no more than 20,000 characters"
        case .invalidProvider:
            "provider must be chatgpt, claude, gemini, cursor, codex, or other"
        case .invalidShareURL:
            "share_url must be a valid HTTP(S) URL no longer than 2,048 characters"
        case .incompletePosition:
            "x and y must be supplied together"
        case .invalidPosition:
            "x and y must be finite numbers"
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
