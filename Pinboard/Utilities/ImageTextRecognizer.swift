//
//  ImageTextRecognizer.swift
//  Pinboard
//

import Foundation
import Vision

enum ImageTextRecognizerError: LocalizedError {
    case imageUnavailable
    case noReadableText

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            "The original image is unavailable."
        case .noReadableText:
            "No readable text was found."
        }
    }
}

enum ImageTextRecognizer {
    private struct RecognizedLine {
        let text: String
        let bounds: CGRect
    }

    nonisolated static func recognizeText(at imageURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            request.minimumTextHeight = 0.006

            let handler = VNImageRequestHandler(url: imageURL, options: [:])
            try handler.perform([request])
            try Task.checkCancellation()

            let lines = (request.results ?? []).compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.20 else {
                    return nil
                }

                let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return RecognizedLine(text: text, bounds: observation.boundingBox)
            }
            .sorted { lhs, rhs in
                let verticalDistance = abs(lhs.bounds.midY - rhs.bounds.midY)
                if verticalDistance > 0.025 {
                    return lhs.bounds.midY > rhs.bounds.midY
                }
                return lhs.bounds.minX < rhs.bounds.minX
            }

            var outputLines: [String] = []
            for line in lines where outputLines.last != line.text {
                outputLines.append(line.text)
            }

            let text = outputLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let meaningfulCharacterCount = text.unicodeScalars.reduce(into: 0) { count, scalar in
                if CharacterSet.alphanumerics.contains(scalar) {
                    count += 1
                }
            }
            guard meaningfulCharacterCount >= 2 else {
                throw ImageTextRecognizerError.noReadableText
            }
            return text
        }.value
    }
}
