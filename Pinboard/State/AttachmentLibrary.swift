//
//  AttachmentLibrary.swift
//  Pinboard
//

import AppKit
import Foundation
import ImageIO
import Observation
import PDFKit
import UniformTypeIdentifiers

struct StoredAttachment: Sendable {
    let attachmentRelativePath: String?
    let sourceFileBookmark: Data?
    let previewImageRelativePath: String?
    let sourceFileName: String
    let fileSize: Int64
    let pixelSize: CGSize?
    let pageCount: Int?
}

struct StoredPreviewImage: Sendable {
    let relativePath: String
    let pixelSize: CGSize
}

struct ImageOCRResult: Sendable {
    let text: String
    let refreshedBookmark: Data?
}

@MainActor
@Observable
final class AttachmentLibrary {
    private(set) var rootURL: URL
    private let legacyRootURL: URL?
    private let previewCache = NSCache<NSString, NSImage>()
    private let previewThemeColorCache = NSCache<NSString, NSColor>()
    private var previewLoadTasks: [String: Task<NSImage?, Never>] = [:]

    private static let bookmarkKey = "attachmentLibraryBookmark"
    private static let libraryFolderName = "Pinboard Library"

    init() {
        let defaultRoot = Self.defaultRootURL()
        let savedRoot = Self.resolveSavedRootURL()
        rootURL = defaultRoot
        legacyRootURL = savedRoot?.standardizedFileURL == defaultRoot.standardizedFileURL
            ? nil
            : savedRoot
        try? AttachmentFileIO.prepareLibrary(at: rootURL)
    }

    var locationIdentifier: String {
        rootURL.standardizedFileURL.path(percentEncoded: false)
    }

    func importImage(from sourceURL: URL, id: UUID) async throws -> StoredAttachment {
        let root = rootURL
        let rootAccess = root.startAccessingSecurityScopedResource()
        let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if rootAccess { root.stopAccessingSecurityScopedResource() }
            if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let sourceBookmark = try? sourceURL.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        return try await Task.detached(priority: .userInitiated) {
            try AttachmentFileIO.importImage(
                from: sourceURL,
                sourceBookmark: sourceBookmark,
                id: id,
                root: root
            )
        }.value
    }

    func importPDF(from sourceURL: URL, id: UUID) async throws -> StoredAttachment {
        let root = rootURL
        let rootAccess = root.startAccessingSecurityScopedResource()
        let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if rootAccess { root.stopAccessingSecurityScopedResource() }
            if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }
        let sourceBookmark = try? sourceURL.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        return try await Task.detached(priority: .userInitiated) {
            try AttachmentFileIO.importPDF(
                from: sourceURL,
                sourceBookmark: sourceBookmark,
                id: id,
                root: root
            )
        }.value
    }

    func migrateLegacyImage(_ data: Data, id: UUID) async throws -> StoredAttachment {
        let root = rootURL
        let rootAccess = root.startAccessingSecurityScopedResource()
        defer {
            if rootAccess { root.stopAccessingSecurityScopedResource() }
        }

        return try await Task.detached(priority: .utility) {
            try AttachmentFileIO.storeLegacyImage(data, id: id, root: root)
        }.value
    }

    func storeLinkPreview(from temporaryURL: URL, id: UUID) async throws -> StoredPreviewImage {
        let root = rootURL
        let rootAccess = root.startAccessingSecurityScopedResource()
        defer {
            if rootAccess { root.stopAccessingSecurityScopedResource() }
        }

        return try await Task.detached(priority: .utility) {
            try AttachmentFileIO.storeLinkPreview(from: temporaryURL, id: id, root: root)
        }.value
    }

    func cachedPreviewImage(relativePath: String?) -> NSImage? {
        guard let relativePath else { return nil }
        let cacheKey = "\(locationIdentifier)|\(relativePath)" as NSString
        return previewCache.object(forKey: cacheKey)
    }

    func loadPreviewImage(relativePath: String?) async -> NSImage? {
        guard let relativePath else { return nil }
        if let cachedImage = cachedPreviewImage(relativePath: relativePath) {
            return cachedImage
        }

        let cacheIdentifier = "\(locationIdentifier)|\(relativePath)"
        let cacheKey = cacheIdentifier as NSString
        if let existingTask = previewLoadTasks[cacheIdentifier] {
            let image = await existingTask.value
            if let image {
                previewCache.setObject(image, forKey: cacheKey)
            }
            return image
        }

        let managedRoots = [rootURL, legacyRootURL].compactMap { $0 }
        let rootAccesses = managedRoots.map { $0.startAccessingSecurityScopedResource() }
        let task: Task<NSImage?, Never> = Task.detached(priority: .utility) {
            for managedRoot in managedRoots {
                if let image = AttachmentFileIO.loadPreviewImage(
                    relativePath: relativePath,
                    root: managedRoot
                ) {
                    return image
                }
            }
            return nil
        }
        previewLoadTasks[cacheIdentifier] = task

        let image = await task.value
        previewLoadTasks[cacheIdentifier] = nil
        for (managedRoot, hasAccess) in zip(managedRoots, rootAccesses) where hasAccess {
            managedRoot.stopAccessingSecurityScopedResource()
        }

        if let image {
            previewCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    func previewThemeColor(relativePath: String?) -> NSColor? {
        guard let relativePath else { return nil }
        let cacheKey = "\(locationIdentifier)|\(relativePath)" as NSString
        if let cachedColor = previewThemeColorCache.object(forKey: cacheKey) {
            return cachedColor
        }

        guard
            let image = cachedPreviewImage(relativePath: relativePath),
            let color = AttachmentFileIO.representativeColor(from: image)
        else { return nil }

        previewThemeColorCache.setObject(color, forKey: cacheKey)
        return color
    }

    func recognizeImageText(
        attachmentRelativePath: String?,
        previewRelativePath: String?,
        sourceBookmark: Data?
    ) async throws -> ImageOCRResult {
        if let sourceBookmark,
           let resolved = resolveExternalAttachment(from: sourceBookmark) {
            let access = resolved.url.startAccessingSecurityScopedResource()
            defer {
                if access { resolved.url.stopAccessingSecurityScopedResource() }
            }

            do {
                let text = try await ImageTextRecognizer.recognizeText(at: resolved.url)
                return ImageOCRResult(
                    text: text,
                    refreshedBookmark: resolved.refreshedBookmark
                )
            } catch ImageTextRecognizerError.noReadableText {
                throw ImageTextRecognizerError.noReadableText
            } catch {
                // The original file may have moved. Fall back to Pinboard's
                // lightweight managed preview below when it is still available.
            }
        }

        let relativePaths = [attachmentRelativePath, previewRelativePath].compactMap { $0 }
        for managedRoot in [rootURL, legacyRootURL].compactMap({ $0 }) {
            let rootAccess = managedRoot.startAccessingSecurityScopedResource()
            defer {
                if rootAccess { managedRoot.stopAccessingSecurityScopedResource() }
            }

            for relativePath in relativePaths {
                guard
                    let fileURL = AttachmentFileIO.fileURL(
                        relativePath: relativePath,
                        root: managedRoot
                    ),
                    FileManager.default.fileExists(atPath: fileURL.path)
                else { continue }

                do {
                    let text = try await ImageTextRecognizer.recognizeText(at: fileURL)
                    return ImageOCRResult(text: text, refreshedBookmark: nil)
                } catch ImageTextRecognizerError.noReadableText {
                    throw ImageTextRecognizerError.noReadableText
                } catch {
                    continue
                }
            }
        }

        throw ImageTextRecognizerError.imageUnavailable
    }

    @discardableResult
    func openAttachment(relativePath: String?, sourceBookmark: Data?) -> Data? {
        if let sourceBookmark,
           let resolved = resolveExternalAttachment(from: sourceBookmark) {
            let access = resolved.url.startAccessingSecurityScopedResource()
            defer {
                if access { resolved.url.stopAccessingSecurityScopedResource() }
            }
            NSWorkspace.shared.open(resolved.url)
            return resolved.refreshedBookmark
        }

        guard let relativePath else { return nil }
        for managedRoot in [rootURL, legacyRootURL].compactMap({ $0 }) {
            guard
                let fileURL = AttachmentFileIO.fileURL(
                    relativePath: relativePath,
                    root: managedRoot
                ),
                FileManager.default.fileExists(atPath: fileURL.path)
            else { continue }

            let rootAccess = managedRoot.startAccessingSecurityScopedResource()
            NSWorkspace.shared.open(fileURL)
            if rootAccess { managedRoot.stopAccessingSecurityScopedResource() }
            return nil
        }
        return nil
    }

    func openWebURL(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    func remove(relativePaths: [String]) async {
        guard !relativePaths.isEmpty else { return }
        let root = rootURL
        let rootAccess = root.startAccessingSecurityScopedResource()
        defer {
            if rootAccess { root.stopAccessingSecurityScopedResource() }
        }

        await Task.detached(priority: .utility) {
            AttachmentFileIO.remove(relativePaths: relativePaths, root: root)
        }.value
    }

    private static func defaultRootURL() -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        return applicationSupport
            .appending(path: "Pinboard", directoryHint: .isDirectory)
            .appending(path: libraryFolderName, directoryHint: .isDirectory)
    }

    private static func resolveSavedRootURL() -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        if isStale,
           let refreshedBookmark = try? url.bookmarkData(
               options: [.withSecurityScope],
               includingResourceValuesForKeys: nil,
               relativeTo: nil
           ) {
            UserDefaults.standard.set(refreshedBookmark, forKey: bookmarkKey)
        }
        return url
    }

    private func resolveExternalAttachment(
        from bookmark: Data
    ) -> (url: URL, refreshedBookmark: Data?)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        let refreshedBookmark: Data?
        if isStale {
            refreshedBookmark = try? url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else {
            refreshedBookmark = nil
        }
        return (url, refreshedBookmark)
    }
}

private enum AttachmentFileIO {
    nonisolated private struct ColorBucket {
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0
        var weight: Double = 0

        mutating func add(red: Double, green: Double, blue: Double, weight: Double) {
            self.red += red * weight
            self.green += green * weight
            self.blue += blue * weight
            self.weight += weight
        }
    }

    nonisolated private static let imagesDirectory = "Images"
    nonisolated private static let pdfsDirectory = "PDFs"
    nonisolated private static let maximumPreviewBytes = 12 * 1_024 * 1_024
    nonisolated private static let maximumPreviewPixelSize = 1_600

    nonisolated static func prepareLibrary(at root: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: root.appending(path: imagesDirectory, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: root.appending(path: pdfsDirectory, directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    nonisolated static func importImage(
        from sourceURL: URL,
        sourceBookmark: Data?,
        id: UUID,
        root: URL
    ) throws -> StoredAttachment {
        try prepareLibrary(at: root)
        let details = try imageDetails(at: sourceURL)
        let fileExtension = safeImageExtension(for: sourceURL, sourceType: details.sourceType)
        let previewRelativePath = "\(imagesDirectory)/\(id.uuidString)-preview.jpg"
        let previewURL = root.appending(path: previewRelativePath, directoryHint: .notDirectory)

        let originalRelativePath: String?
        if sourceBookmark == nil {
            let relativePath = "\(imagesDirectory)/\(id.uuidString).\(fileExtension)"
            let originalURL = root.appending(path: relativePath, directoryHint: .notDirectory)
            try replaceFile(at: originalURL) {
                try FileManager.default.copyItem(at: sourceURL, to: originalURL)
            }
            originalRelativePath = relativePath
        } else {
            originalRelativePath = nil
        }
        try writeThumbnail(from: sourceURL, to: previewURL)

        return StoredAttachment(
            attachmentRelativePath: originalRelativePath,
            sourceFileBookmark: sourceBookmark,
            previewImageRelativePath: previewRelativePath,
            sourceFileName: sourceURL.lastPathComponent,
            fileSize: fileSize(at: sourceURL),
            pixelSize: details.pixelSize,
            pageCount: nil
        )
    }

    nonisolated static func importPDF(
        from sourceURL: URL,
        sourceBookmark: Data?,
        id: UUID,
        root: URL
    ) throws -> StoredAttachment {
        try prepareLibrary(at: root)
        let previewRelativePath = "\(imagesDirectory)/\(id.uuidString)-pdf-preview.jpg"
        let previewURL = root.appending(path: previewRelativePath, directoryHint: .notDirectory)

        let originalRelativePath: String?
        if sourceBookmark == nil {
            let relativePath = "\(pdfsDirectory)/\(id.uuidString).pdf"
            let originalURL = root.appending(path: relativePath, directoryHint: .notDirectory)
            try replaceFile(at: originalURL) {
                try FileManager.default.copyItem(at: sourceURL, to: originalURL)
            }
            originalRelativePath = relativePath
        } else {
            originalRelativePath = nil
        }

        let document = PDFDocument(url: sourceURL)
        let firstPage = document?.page(at: 0)
        let pageSize = firstPage?.bounds(for: .mediaBox).size
        if let firstPage {
            try writePDFPreview(page: firstPage, to: previewURL)
        }

        return StoredAttachment(
            attachmentRelativePath: originalRelativePath,
            sourceFileBookmark: sourceBookmark,
            previewImageRelativePath: firstPage == nil ? nil : previewRelativePath,
            sourceFileName: sourceURL.lastPathComponent,
            fileSize: fileSize(at: sourceURL),
            pixelSize: pageSize,
            pageCount: document?.pageCount
        )
    }

    nonisolated static func storeLegacyImage(
        _ data: Data,
        id: UUID,
        root: URL
    ) throws -> StoredAttachment {
        try prepareLibrary(at: root)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AttachmentLibraryError.invalidImage
        }
        let sourceType = CGImageSourceGetType(source) as String?
        let fileExtension = sourceType
            .flatMap(UTType.init)
            .flatMap(\.preferredFilenameExtension) ?? "img"
        let originalRelativePath = "\(imagesDirectory)/\(id.uuidString).\(fileExtension)"
        let previewRelativePath = "\(imagesDirectory)/\(id.uuidString)-preview.jpg"
        let originalURL = root.appending(path: originalRelativePath, directoryHint: .notDirectory)
        let previewURL = root.appending(path: previewRelativePath, directoryHint: .notDirectory)

        try data.write(to: originalURL, options: .atomic)
        let details = try imageDetails(at: originalURL)
        try writeThumbnail(from: originalURL, to: previewURL)

        return StoredAttachment(
            attachmentRelativePath: originalRelativePath,
            sourceFileBookmark: nil,
            previewImageRelativePath: previewRelativePath,
            sourceFileName: "Image.\(fileExtension)",
            fileSize: Int64(data.count),
            pixelSize: details.pixelSize,
            pageCount: nil
        )
    }

    nonisolated static func storeLinkPreview(
        from sourceURL: URL,
        id: UUID,
        root: URL
    ) throws -> StoredPreviewImage {
        try prepareLibrary(at: root)
        let details = try imageDetails(at: sourceURL)
        let relativePath = "\(imagesDirectory)/\(id.uuidString)-link-preview.jpg"
        let destinationURL = root.appending(path: relativePath, directoryHint: .notDirectory)
        try writeThumbnail(from: sourceURL, to: destinationURL)
        return StoredPreviewImage(relativePath: relativePath, pixelSize: details.pixelSize)
    }

    nonisolated static func loadPreviewImage(relativePath: String, root: URL) -> NSImage? {
        guard let url = fileURL(relativePath: relativePath, root: root) else { return nil }
        guard fileSize(at: url) <= maximumPreviewBytes else { return nil }
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        else { return nil }

        return NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
    }

    nonisolated static func representativeColor(from image: NSImage) -> NSColor? {
        var proposedRect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(
            forProposedRect: &proposedRect,
            context: nil,
            hints: nil
        ) else { return nil }

        let sampleWidth = 32
        let sampleHeight = 32
        let bytesPerPixel = 4
        let bytesPerRow = sampleWidth * bytesPerPixel
        var pixels = [UInt8](
            repeating: 0,
            count: sampleHeight * bytesPerRow
        )

        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        )

        var buckets: [Int: ColorBucket] = [:]
        var fallback = ColorBucket()

        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0.5 else { continue }

            let red = Double(pixels[offset]) / 255
            let green = Double(pixels[offset + 1]) / 255
            let blue = Double(pixels[offset + 2]) / 255
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

            fallback.add(red: red, green: green, blue: blue, weight: alpha)

            guard luminance > 0.08, luminance < 0.94 else { continue }
            let redBand = min(7, Int(red * 8))
            let greenBand = min(7, Int(green * 8))
            let blueBand = min(7, Int(blue * 8))
            let key = redBand << 6 | greenBand << 3 | blueBand
            let midtoneWeight = 1 - abs(luminance - 0.52) * 0.65
            let weight = alpha * (0.35 + saturation * 1.9) * midtoneWeight
            buckets[key, default: ColorBucket()].add(
                red: red,
                green: green,
                blue: blue,
                weight: weight
            )
        }

        let selected = buckets.values.max { $0.weight < $1.weight } ?? fallback
        guard selected.weight > 0 else { return nil }

        let rawColor = NSColor(
            srgbRed: selected.red / selected.weight,
            green: selected.green / selected.weight,
            blue: selected.blue / selected.weight,
            alpha: 1
        )
        guard let rgbColor = rawColor.usingColorSpace(NSColorSpace.sRGB) else {
            return rawColor
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        rgbColor.getHue(
            &hue,
            saturation: &saturation,
            brightness: &brightness,
            alpha: &alpha
        )

        if saturation < 0.12 {
            return NSColor(
                hue: hue,
                saturation: saturation,
                brightness: min(max(brightness, 0.42), 0.68),
                alpha: 1
            )
        }

        return NSColor(
            hue: hue,
            saturation: min(max(saturation * 1.08, 0.34), 0.82),
            brightness: min(max(brightness, 0.42), 0.78),
            alpha: 1
        )
    }

    nonisolated static func remove(relativePaths: [String], root: URL) {
        for relativePath in Set(relativePaths) {
            guard let url = fileURL(relativePath: relativePath, root: root) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated static func fileURL(relativePath: String, root: URL) -> URL? {
        guard
            !relativePath.hasPrefix("/"),
            !relativePath.split(separator: "/").contains("..")
        else { return nil }

        let standardizedRoot = root.standardizedFileURL
        let candidate = standardizedRoot
            .appending(path: relativePath, directoryHint: .notDirectory)
            .standardizedFileURL
        guard candidate.pathComponents.starts(with: standardizedRoot.pathComponents) else {
            return nil
        }
        return candidate
    }

    private struct ImageDetails {
        let pixelSize: CGSize
        let sourceType: String?
    }

    nonisolated private static func imageDetails(at url: URL) throws -> ImageDetails {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
            let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
            pixelWidth > 0,
            pixelHeight > 0
        else {
            throw AttachmentLibraryError.invalidImage
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapsDimensions = [5, 6, 7, 8].contains(orientation)
        let pixelSize = swapsDimensions
            ? CGSize(width: pixelHeight, height: pixelWidth)
            : CGSize(width: pixelWidth, height: pixelHeight)
        return ImageDetails(
            pixelSize: pixelSize,
            sourceType: CGImageSourceGetType(source) as String?
        )
    }

    nonisolated private static func writeThumbnail(from sourceURL: URL, to destinationURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw AttachmentLibraryError.invalidImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPreviewPixelSize,
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AttachmentLibraryError.invalidImage
        }
        try writeJPEG(thumbnail, to: destinationURL)
    }

    nonisolated private static func writePDFPreview(page: PDFPage, to destinationURL: URL) throws {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(
            CGFloat(maximumPreviewPixelSize) / max(1, bounds.width),
            CGFloat(maximumPreviewPixelSize) / max(1, bounds.height)
        )
        let size = CGSize(
            width: max(1, bounds.width * min(1, scale)),
            height: max(1, bounds.height * min(1, scale))
        )
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let jpegData = bitmap.representation(
                using: .jpeg,
                properties: [.compressionFactor: 0.82]
            )
        else {
            throw AttachmentLibraryError.previewGenerationFailed
        }
        try jpegData.write(to: destinationURL, options: .atomic)
    }

    nonisolated private static func writeJPEG(_ image: CGImage, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        guard
            let destination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw AttachmentLibraryError.previewGenerationFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw AttachmentLibraryError.previewGenerationFailed
        }
    }

    nonisolated private static func safeImageExtension(
        for sourceURL: URL,
        sourceType: String?
    ) -> String {
        let pathExtension = sourceURL.pathExtension.lowercased()
        if !pathExtension.isEmpty,
           pathExtension.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return pathExtension
        }
        return sourceType
            .flatMap(UTType.init)
            .flatMap(\.preferredFilenameExtension) ?? "img"
    }

    nonisolated private static func replaceFile(at url: URL, write: () throws -> Void) rethrows {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try write()
    }

    nonisolated private static func fileSize(at url: URL) -> Int64 {
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return Int64(size ?? 0)
    }
}

private enum AttachmentLibraryError: LocalizedError {
    case invalidImage
    case previewGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "The selected image could not be read."
        case .previewGenerationFailed:
            "Pinboard could not create a lightweight preview."
        }
    }
}
