import Foundation
import ImageIO
import UIKit
import Vision

enum BusinessCardImageAnalyzer {
    static func analyze(imageData: Data) async -> BusinessCardExtraction {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: imageData),
                  let cgImage = image.cgImage
            else {
                return BusinessCardExtraction(
                    ocrRawText: nil,
                    qrRawValues: [],
                    links: [],
                    extractionResults: [],
                    suggestedDisplayName: nil,
                    suggestedCosplayCharacterName: nil
                )
            }

            let barcodeRequest = VNDetectBarcodesRequest()
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            textRequest.recognitionLanguages = ["ja-JP", "en-US"]
            if #available(iOS 16.0, *) {
                textRequest.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(image.imageOrientation),
                options: [:]
            )

            do {
                try handler.perform([barcodeRequest, textRequest])
            } catch {
                AppLogger.log("Business card analysis failed: \(error.localizedDescription)", category: "BusinessCard")
            }

            let qrValues = (barcodeRequest.results ?? [])
                .compactMap(\.payloadStringValue)
                .map { $0.trimmedCoscard() }
                .filter { !$0.isEmpty }

            let recognizedLines = (textRequest.results ?? []).compactMap { observation -> (text: String, confidence: Float)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return (candidate.string.trimmedCoscard(), candidate.confidence)
            }
            let textLines = recognizedLines.map(\.text).filter { !$0.isEmpty }
            let rawText = textLines.isEmpty ? nil : textLines.joined(separator: "\n")

            let qrLinks = qrValues.compactMap {
                ContactLinkNormalizer.normalize($0, sourceType: .qr)
            }
            let ocrLinks = rawText.map {
                ContactLinkNormalizer.links(from: $0, sourceType: .ocr)
            } ?? []
            let links = ContactLinkNormalizer.unique(qrLinks + ocrLinks)

            var extractionResults = qrValues.map {
                ExtractionResultDraft(
                    kind: "qr",
                    originalValue: $0,
                    normalizedValue: ContactLinkNormalizer.normalize($0, sourceType: .qr)?.normalizedURL,
                    confidence: 1,
                    sourceType: .qr,
                    isAccepted: true
                )
            }
            extractionResults.append(contentsOf: links.map {
                ExtractionResultDraft(
                    kind: "link",
                    originalValue: $0.originalValue,
                    normalizedValue: $0.normalizedURL,
                    confidence: $0.sourceType == .qr ? 1 : 0.7,
                    sourceType: $0.sourceType,
                    isAccepted: true
                )
            })

            let suggestedDisplayName = suggestDisplayName(from: textLines)
            let suggestedCosplayCharacterName = suggestCosplayCharacterName(from: textLines, displayName: suggestedDisplayName)

            return BusinessCardExtraction(
                ocrRawText: rawText,
                qrRawValues: qrValues,
                links: links,
                extractionResults: extractionResults,
                suggestedDisplayName: suggestedDisplayName,
                suggestedCosplayCharacterName: suggestedCosplayCharacterName
            )
        }.value
    }

    private static func suggestDisplayName(from lines: [String]) -> String? {
        lines.first { line in
            let value = line.trimmedCoscard()
            guard (1 ... 24).contains(value.count) else { return false }
            let lower = value.lowercased()
            if lower.contains("http") || lower.contains("@") || lower.contains("instagram") || lower.contains("twitter") {
                return false
            }
            if value.range(of: #"[0-9]{3,}"#, options: .regularExpression) != nil {
                return false
            }
            return true
        }
    }

    private static func suggestCosplayCharacterName(from lines: [String], displayName: String?) -> String? {
        lines.first { line in
            let value = line.trimmedCoscard()
            guard !value.isEmpty, value != displayName, value.count <= 40 else { return false }
            let lower = value.lowercased()
            return lower.contains("cos") || value.contains("コス") || value.contains("併せ") || value.contains("撮影")
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
