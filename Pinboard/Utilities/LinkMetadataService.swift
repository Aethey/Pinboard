//
//  LinkMetadataService.swift
//  Pinboard
//

import Foundation
import LinkPresentation
import UniformTypeIdentifiers

struct LinkCardMetadata: Sendable {
    let title: String?
    let summary: String?
    let resolvedURL: URL
    let temporaryImageURL: URL?
    let isVideo: Bool
}

enum LinkMetadataService {
    private static let maximumHTMLBytes = 2 * 1_024 * 1_024
    private static let maximumJSONBytes = 1 * 1_024 * 1_024
    private static let maximumRemoteImageBytes: Int64 = 32 * 1_024 * 1_024

    static func fetch(for url: URL) async -> LinkCardMetadata {
        async let systemTask = fetchSystemMetadata(for: url)
        async let webTask = fetchWebMetadata(for: url)
        let (system, web) = await (systemTask, webTask)

        let resolvedURL = web?.resolvedURL ?? system.resolvedURL ?? url
        var temporaryImageURL: URL?

        if let remoteImageURL = web?.imageURL {
            temporaryImageURL = await downloadPreviewImage(
                from: remoteImageURL,
                referringPage: resolvedURL
            )
        }

        if temporaryImageURL == nil {
            temporaryImageURL = system.temporaryImageURL
        } else if let systemImageURL = system.temporaryImageURL {
            try? FileManager.default.removeItem(at: systemImageURL)
        }

        return LinkCardMetadata(
            title: displayTitle(
                cleaned(web?.title) ?? cleaned(system.title),
                for: resolvedURL
            ),
            summary: cleaned(web?.summary),
            resolvedURL: resolvedURL,
            temporaryImageURL: temporaryImageURL,
            isVideo: web?.isVideo == true || system.isVideo
        )
    }

    private struct SystemMetadata {
        let title: String?
        let resolvedURL: URL?
        let temporaryImageURL: URL?
        let isVideo: Bool
    }

    private static func fetchSystemMetadata(for url: URL) async -> SystemMetadata {
        let provider = LPMetadataProvider()
        provider.timeout = 10
        provider.shouldFetchSubresources = true

        let metadata: LPLinkMetadata? = await withCheckedContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, _ in
                continuation.resume(returning: metadata)
            }
        }

        guard let metadata else {
            return SystemMetadata(
                title: nil,
                resolvedURL: nil,
                temporaryImageURL: nil,
                isVideo: false
            )
        }

        return SystemMetadata(
            title: metadata.title,
            resolvedURL: metadata.url ?? metadata.originalURL,
            temporaryImageURL: await copyTemporaryImage(from: metadata.imageProvider),
            isVideo: metadata.videoProvider != nil
        )
    }

    private static func copyTemporaryImage(from itemProvider: NSItemProvider?) async -> URL? {
        guard
            let itemProvider,
            itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        else { return nil }

        return await withCheckedContinuation { continuation in
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) {
                sourceURL,
                _ in
                guard let sourceURL else {
                    continuation.resume(returning: nil)
                    return
                }

                let fileExtension = sourceURL.pathExtension.isEmpty
                    ? "image"
                    : sourceURL.pathExtension
                let temporaryURL = FileManager.default.temporaryDirectory
                    .appending(
                        path: "pinboard-link-\(UUID().uuidString).\(fileExtension)",
                        directoryHint: .notDirectory
                    )

                do {
                    try FileManager.default.copyItem(at: sourceURL, to: temporaryURL)
                    continuation.resume(returning: temporaryURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private struct WebMetadata {
        let title: String?
        let summary: String?
        let imageURL: URL?
        let resolvedURL: URL
        let isVideo: Bool
    }

    private struct PageMetadata {
        let metadata: WebMetadata
        let discoveredOEmbedURL: URL?
    }

    private static func fetchWebMetadata(for originalURL: URL) async -> WebMetadata? {
        async let pageTask = fetchPageMetadata(for: originalURL)
        async let knownOEmbedTask = fetchKnownOEmbed(for: originalURL)

        let (page, initiallyKnownOEmbed) = await (pageTask, knownOEmbedTask)
        var oEmbed = initiallyKnownOEmbed

        if oEmbed == nil,
           let endpoint = page?.discoveredOEmbedURL {
            oEmbed = await fetchOEmbed(from: endpoint, originalURL: originalURL)
        }

        if oEmbed == nil,
           let resolvedURL = page?.metadata.resolvedURL,
           resolvedURL != originalURL,
           let endpoint = knownOEmbedEndpoint(for: resolvedURL) {
            oEmbed = await fetchOEmbed(from: endpoint, originalURL: resolvedURL)
        }

        guard oEmbed != nil || page != nil else { return nil }
        let fallback = page?.metadata
        return WebMetadata(
            title: cleaned(oEmbed?.title) ?? cleaned(fallback?.title),
            summary: cleaned(fallback?.summary) ?? cleaned(oEmbed?.summary),
            imageURL: oEmbed?.imageURL ?? fallback?.imageURL,
            resolvedURL: fallback?.resolvedURL ?? oEmbed?.resolvedURL ?? originalURL,
            isVideo: oEmbed?.isVideo == true
                || fallback?.isVideo == true
                || looksLikeVideoURL(fallback?.resolvedURL ?? originalURL)
        )
    }

    private static func fetchKnownOEmbed(for url: URL) async -> WebMetadata? {
        guard let endpoint = knownOEmbedEndpoint(for: url) else { return nil }
        return await fetchOEmbed(from: endpoint, originalURL: url)
    }

    private static func knownOEmbedEndpoint(for url: URL) -> URL? {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return nil }

        if matches(host, domain: "youtube.com") || host == "youtu.be" {
            return endpoint(
                "https://www.youtube.com/oembed",
                items: [
                    URLQueryItem(name: "url", value: url.absoluteString),
                    URLQueryItem(name: "format", value: "json"),
                ]
            )
        }

        if matches(host, domain: "tiktok.com") {
            return endpoint(
                "https://www.tiktok.com/oembed",
                items: [URLQueryItem(name: "url", value: url.absoluteString)]
            )
        }

        if matches(host, domain: "x.com") || matches(host, domain: "twitter.com") {
            return endpoint(
                "https://publish.x.com/oembed",
                items: [
                    URLQueryItem(name: "url", value: url.absoluteString),
                    URLQueryItem(name: "omit_script", value: "true"),
                    URLQueryItem(name: "dnt", value: "true"),
                ]
            )
        }

        if matches(host, domain: "vimeo.com") {
            return endpoint(
                "https://vimeo.com/api/oembed.json",
                items: [URLQueryItem(name: "url", value: url.absoluteString)]
            )
        }

        return nil
    }

    private static func endpoint(_ base: String, items: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        components.queryItems = items
        return components.url
    }

    private static func matches(_ host: String, domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }

    private static func fetchOEmbed(from endpointURL: URL, originalURL: URL) async -> WebMetadata? {
        guard isSafeWebURL(endpointURL) else { return nil }
        var request = metadataRequest(for: endpointURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard
            let downloaded = await download(request: request),
            let data = readPrefix(
                from: downloaded.fileURL,
                maximumBytes: maximumJSONBytes,
                allowsTruncation: false
            ),
            let object = try? JSONSerialization.jsonObject(with: data),
            let response = object as? [String: Any]
        else { return nil }

        let type = stringValue(response["type"])?.lowercased()
        let rawHTML = stringValue(response["html"])
        let htmlText = rawHTML.map(plainText(from:))
        let authorName = cleaned(stringValue(response["author_name"]))
        let providerName = cleaned(stringValue(response["provider_name"]))
        let explicitTitle = cleaned(stringValue(response["title"]))
        let embeddedText = cleaned(htmlText)
        let attribution = [authorName, providerName]
            .compactMap { $0 }
            .filter { $0.caseInsensitiveCompare(explicitTitle ?? "") != .orderedSame }
            .joined(separator: " · ")
        let summary = explicitTitle == nil
            ? embeddedText
            : (attribution.isEmpty ? nil : attribution)
        let photoURL = type == "photo" ? webURL(from: response["url"], relativeTo: originalURL) : nil

        return WebMetadata(
            title: explicitTitle,
            summary: summary,
            imageURL: webURL(from: response["thumbnail_url"], relativeTo: originalURL) ?? photoURL,
            resolvedURL: webURL(from: response["url"], relativeTo: originalURL) ?? originalURL,
            isVideo: type == "video"
        )
    }

    private static func fetchPageMetadata(for originalURL: URL) async -> PageMetadata? {
        var request = metadataRequest(for: originalURL)
        request.setValue(
            "text/html,application/xhtml+xml;q=0.9,*/*;q=0.5",
            forHTTPHeaderField: "Accept"
        )

        guard
            let downloaded = await download(request: request),
            let data = readPrefix(
                from: downloaded.fileURL,
                maximumBytes: maximumHTMLBytes,
                allowsTruncation: true
            )
        else { return nil }

        let resolvedURL = downloaded.response.url ?? originalURL
        guard let html = decodeHTMLData(data, response: downloaded.response) else { return nil }
        return parseHTML(html, pageURL: resolvedURL)
    }

    private struct DownloadedResponse {
        let fileURL: URL
        let response: HTTPURLResponse
    }

    private static func download(request: URLRequest) async -> DownloadedResponse? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpMaximumConnectionsPerHost = 2
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (fileURL, response) = try await session.download(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<400).contains(response.statusCode)
            else { return nil }
            return DownloadedResponse(fileURL: fileURL, response: response)
        } catch {
            return nil
        }
    }

    private static func metadataRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.8,zh-CN;q=0.7,ja;q=0.6", forHTTPHeaderField: "Accept-Language")
        return request
    }

    private static func readPrefix(
        from fileURL: URL,
        maximumBytes: Int,
        allowsTruncation: Bool
    ) -> Data? {
        let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard allowsTruncation || fileSize <= maximumBytes else { return nil }

        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
            guard allowsTruncation || data.count <= maximumBytes else { return nil }
            return data.count > maximumBytes ? Data(data.prefix(maximumBytes)) : data
        } catch {
            return nil
        }
    }

    private static func decodeHTMLData(_ data: Data, response: HTTPURLResponse) -> String? {
        if let encodingName = response.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let encoding = String.Encoding(
                    rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                )
                if let string = String(data: data, encoding: encoding) {
                    return string
                }
            }
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func parseHTML(_ html: String, pageURL: URL) -> PageMetadata {
        let tags = elementTags(named: ["meta", "link"], in: html)
        let metadataTags = tags.map { attributes(in: $0) }

        func metaValue(_ names: [String]) -> String? {
            for name in names {
                if let value = metadataTags.first(where: { attributes in
                    let key = attributes["property"] ?? attributes["name"] ?? attributes["itemprop"]
                    return key?.lowercased() == name
                })?["content"] {
                    return cleaned(decodeHTMLEntities(value))
                }
            }
            return nil
        }

        let jsonLD = parseJSONLD(in: html, pageURL: pageURL)
        let title = metaValue(["og:title", "twitter:title", "title"])
            ?? titleElement(in: html)
            ?? jsonLD.title
        let summary = metaValue([
            "og:description",
            "twitter:description",
            "description",
        ]) ?? jsonLD.summary
        let imageString = metaValue([
            "og:image:secure_url",
            "og:image",
            "twitter:image:src",
            "twitter:image",
            "thumbnailurl",
            "thumbnail",
        ])
        let canonicalString = metaValue(["og:url"])
            ?? metadataTags.first(where: {
                $0["rel"]?.lowercased().split(separator: " ").contains("canonical") == true
            })?["href"]
        let type = metaValue(["og:type"])?.lowercased()
        let hasVideoMetadata = metaValue([
            "og:video:secure_url",
            "og:video:url",
            "og:video",
            "twitter:player:stream",
            "twitter:player",
        ]) != nil
        let discoveredOEmbedString = metadataTags.first(where: {
            $0["type"]?.lowercased() == "application/json+oembed"
                && $0["rel"]?.lowercased().split(separator: " ").contains("alternate") == true
        })?["href"]
        let resolvedURL = safeResolvedURL(canonicalString, relativeTo: pageURL) ?? jsonLD.resolvedURL

        return PageMetadata(
            metadata: WebMetadata(
                title: title,
                summary: summary,
                imageURL: safeResolvedURL(imageString, relativeTo: pageURL) ?? jsonLD.imageURL,
                resolvedURL: resolvedURL,
                isVideo: type?.hasPrefix("video") == true
                    || hasVideoMetadata
                    || jsonLD.isVideo
            ),
            discoveredOEmbedURL: safeResolvedURL(discoveredOEmbedString, relativeTo: pageURL)
        )
    }

    private static func elementTags(named names: [String], in html: String) -> [String] {
        let alternatives = names.joined(separator: "|")
        guard let regex = try? NSRegularExpression(
            pattern: "<(?:\(alternatives))\\b[^>]*>",
            options: [.caseInsensitive]
        ) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap {
            Range($0.range, in: html).map { String(html[$0]) }
        }
    }

    private static func attributes(in tag: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s\"'=<>`]+))"#,
            options: []
        ) else { return [:] }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        var result: [String: String] = [:]

        for match in regex.matches(in: tag, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: tag) else { continue }
            let key = tag[keyRange].lowercased()
            for index in 2...4 where match.range(at: index).location != NSNotFound {
                if let valueRange = Range(match.range(at: index), in: tag) {
                    result[key] = String(tag[valueRange])
                    break
                }
            }
        }
        return result
    }

    private static func titleElement(in html: String) -> String? {
        guard
            let regex = try? NSRegularExpression(
                pattern: #"<title\b[^>]*>(.*?)</title>"#,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ),
            let match = regex.firstMatch(
                in: html,
                range: NSRange(html.startIndex..<html.endIndex, in: html)
            ),
            let range = Range(match.range(at: 1), in: html)
        else { return nil }
        return cleaned(decodeHTMLEntities(String(html[range])))
    }

    private static func parseJSONLD(in html: String, pageURL: URL) -> WebMetadata {
        guard let regex = try? NSRegularExpression(
            pattern: #"<script\b(?=[^>]*\btype\s*=\s*['\"]application/ld\+json['\"])[^>]*>(.*?)</script>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return emptyWebMetadata(pageURL: pageURL)
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var dictionaries: [[String: Any]] = []
        for match in regex.matches(in: html, range: range).prefix(12) {
            guard
                let bodyRange = Range(match.range(at: 1), in: html),
                let data = String(html[bodyRange]).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            dictionaries.append(contentsOf: collectDictionaries(from: object, limit: 80))
        }

        dictionaries.sort { jsonLDScore($0) > jsonLDScore($1) }
        let title = firstString(keys: ["name", "headline", "caption"], in: dictionaries)
        let summary = firstString(keys: ["description", "abstract"], in: dictionaries)
        let imageValue = firstValue(keys: ["thumbnailUrl", "thumbnailURL", "image"], in: dictionaries)
        let urlValue = firstValue(keys: ["url", "mainEntityOfPage"], in: dictionaries)
        let types = dictionaries.compactMap { stringValue($0["@type"])?.lowercased() }

        return WebMetadata(
            title: cleaned(title),
            summary: cleaned(summary),
            imageURL: webURL(from: imageValue, relativeTo: pageURL),
            resolvedURL: webURL(from: urlValue, relativeTo: pageURL) ?? pageURL,
            isVideo: types.contains(where: { $0.contains("video") })
        )
    }

    private static func emptyWebMetadata(pageURL: URL) -> WebMetadata {
        WebMetadata(
            title: nil,
            summary: nil,
            imageURL: nil,
            resolvedURL: pageURL,
            isVideo: false
        )
    }

    private static func collectDictionaries(from object: Any, limit: Int) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var stack: [Any] = [object]
        while let item = stack.popLast(), result.count < limit {
            if let dictionary = item as? [String: Any] {
                result.append(dictionary)
                stack.append(contentsOf: dictionary.values)
            } else if let array = item as? [Any] {
                stack.append(contentsOf: array)
            }
        }
        return result
    }

    private static func jsonLDScore(_ dictionary: [String: Any]) -> Int {
        let type = stringValue(dictionary["@type"])?.lowercased() ?? ""
        if type.contains("video") { return 4 }
        if type.contains("article") || type.contains("news") { return 3 }
        if type.contains("webpage") { return 2 }
        return 1
    }

    private static func firstString(keys: [String], in dictionaries: [[String: Any]]) -> String? {
        stringValue(firstValue(keys: keys, in: dictionaries))
    }

    private static func firstValue(keys: [String], in dictionaries: [[String: Any]]) -> Any? {
        for key in keys {
            for dictionary in dictionaries {
                if let value = dictionary[key] { return value }
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? URL { return value.absoluteString }
        if let values = value as? [Any] {
            return values.lazy.compactMap { stringValue($0) }.first
        }
        if let dictionary = value as? [String: Any] {
            return stringValue(dictionary["url"] ?? dictionary["contentUrl"])
        }
        return nil
    }

    private static func webURL(from value: Any?, relativeTo baseURL: URL) -> URL? {
        safeResolvedURL(stringValue(value), relativeTo: baseURL)
    }

    private static func safeResolvedURL(_ value: String?, relativeTo baseURL: URL) -> URL? {
        guard let value = cleaned(value) else { return nil }
        let decodedValue = decodeHTMLEntities(value)
        guard
            let url = URL(string: decodedValue, relativeTo: baseURL)?.absoluteURL,
            isSafeWebURL(url)
        else { return nil }
        return url
    }

    private static func isSafeWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http"
    }

    private static func looksLikeVideoURL(_ url: URL) -> Bool {
        guard let host = url.host(percentEncoded: false)?.lowercased() else { return false }
        let path = url.path(percentEncoded: false).lowercased()

        if matches(host, domain: "youtube.com") || host == "youtu.be" { return true }
        if matches(host, domain: "tiktok.com") && path.contains("/video/") { return true }
        if matches(host, domain: "vimeo.com") { return true }
        if matches(host, domain: "bilibili.com") {
            return path.contains("/video/") || path.contains("/bangumi/play/")
        }
        if host == "b23.tv" { return true }
        if matches(host, domain: "dailymotion.com") && path.contains("/video/") { return true }
        if host == "dai.ly" || host == "clips.twitch.tv" { return true }
        if matches(host, domain: "twitch.tv") && path.contains("/videos/") { return true }
        if matches(host, domain: "douyin.com") && path.contains("/video/") { return true }
        if matches(host, domain: "kuaishou.com") && path.contains("/short-video/") { return true }
        if matches(host, domain: "instagram.com") && path.contains("/reel/") { return true }
        if matches(host, domain: "facebook.com") {
            return path.contains("/reel/") || path.contains("/videos/") || path == "/watch/"
        }
        return false
    }

    private static func downloadPreviewImage(from url: URL, referringPage: URL) async -> URL? {
        guard isSafeWebURL(url) else { return nil }
        var request = metadataRequest(for: url)
        request.setValue("image/avif,image/webp,image/apng,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(referringPage.absoluteString, forHTTPHeaderField: "Referer")

        guard let downloaded = await download(request: request) else { return nil }
        let fileSize = Int64(
            (try? downloaded.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        )
        guard fileSize > 0, fileSize <= maximumRemoteImageBytes else { return nil }

        if let mimeType = downloaded.response.mimeType,
           let contentType = UTType(mimeType: mimeType),
           !contentType.conforms(to: .image) {
            return nil
        }

        let contentType = downloaded.response.mimeType.flatMap { UTType(mimeType: $0) }
        let fileExtension = contentType?.preferredFilenameExtension
            ?? url.pathExtension.nilIfEmpty
            ?? "image"
        let destinationURL = FileManager.default.temporaryDirectory.appending(
            path: "pinboard-web-preview-\(UUID().uuidString).\(fileExtension)",
            directoryHint: .notDirectory
        )

        do {
            try FileManager.default.copyItem(at: downloaded.fileURL, to: destinationURL)
            return destinationURL
        } catch {
            return nil
        }
    }

    private static func plainText(from html: String) -> String {
        let withoutScripts = html.replacingOccurrences(
            of: #"<script\b[^>]*>.*?</script>"#,
            with: " ",
            options: [.regularExpression, .caseInsensitive]
        )
        let withoutTags = withoutScripts.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return cleaned(decodeHTMLEntities(withoutTags)) ?? ""
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let collapsed = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    private static func displayTitle(_ value: String?, for url: URL) -> String? {
        guard var value = cleaned(value) else { return nil }
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        if matches(host, domain: "bilibili.com") {
            for suffix in ["_哔哩哔哩_bilibili", " - 哔哩哔哩", "_哔哩哔哩"]
            where value.hasSuffix(suffix) {
                value.removeLast(suffix.count)
                break
            }
        }
        return cleaned(value)
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&hellip;", with: "…")

        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return result
        }
        let matches = regex.matches(
            in: result,
            range: NSRange(result.startIndex..<result.endIndex, in: result)
        )
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: result),
                let numberRange = Range(match.range(at: 1), in: result)
            else { continue }
            let rawNumber = String(result[numberRange])
            let radix = rawNumber.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(rawNumber.dropFirst()) : rawNumber
            guard
                let scalarValue = UInt32(digits, radix: radix),
                let scalar = UnicodeScalar(scalarValue)
            else { continue }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
