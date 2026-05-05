import Foundation
import UIKit

@MainActor
final class BusinessCardImportViewModel: ObservableObject {
    @Published private(set) var imageData: Data?
    @Published private(set) var previewImage: UIImage?
    @Published private(set) var isAnalyzing = false
    @Published private(set) var isSaving = false
    @Published var displayName = ""
    @Published var cosplayCharacterName = ""
    @Published var memo = ""
    @Published var eventTag = ""
    @Published var links: [ContactLinkDraft] = []
    @Published var mergeCandidates: [BusinessCardMergeCandidate] = []
    @Published var selectedMergePeerId: UUID?
    @Published var ocrRawText: String?
    @Published var errorMessage: String?

    private var env: AppEnvironment?
    private var thumbnailData: Data?
    private var captureSourceType: BusinessCardCaptureSourceType = .library
    private var capturedAt: Date = .now
    private var qrRawValue: String?
    private var extractionResults: [ExtractionResultDraft] = []

    var hasImage: Bool {
        imageData != nil
    }

    var canSave: Bool {
        imageData != nil && !displayName.trimmedCoscard().isEmpty && !isSaving
    }

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func loadImage(rawData: Data?, sourceType: BusinessCardCaptureSourceType) async {
        guard let rawData else { return }
        guard let image = UIImage(data: rawData),
              let compressed = ImageResizer.businessCardJPEGData(from: image, maxBytes: 900_000)
        else {
            errorMessage = "名刺画像の読み込みに失敗しました"
            return
        }

        imageData = compressed
        previewImage = UIImage(data: compressed)
        thumbnailData = ImageResizer.businessCardJPEGData(from: image, maxSide: 360, quality: 0.72, maxBytes: 120_000)
        captureSourceType = sourceType
        capturedAt = .now
        qrRawValue = nil
        extractionResults = []
        links = []
        mergeCandidates = []
        selectedMergePeerId = nil
        errorMessage = nil

        isAnalyzing = true
        let extraction = await BusinessCardImageAnalyzer.analyze(imageData: rawData)
        isAnalyzing = false
        apply(extraction)
        await refreshMergeCandidates()
    }

    func addManualLink() {
        links.append(ContactLinkDraft(
            platform: .website,
            originalValue: "",
            sourceType: .manual
        ))
    }

    func removeLink(id: UUID) {
        links.removeAll { $0.id == id }
    }

    func rebuildLinksFromCurrentValues() {
        links = normalizedLinks()
    }

    func refreshMergeCandidates() async {
        guard let env else { return }
        do {
            mergeCandidates = try await env.businessCardRepository.findMergeCandidates(
                displayName: displayName,
                links: normalizedLinks(),
                limit: 5
            )
            if let selectedMergePeerId,
               !mergeCandidates.contains(where: { $0.peerId == selectedMergePeerId })
            {
                self.selectedMergePeerId = nil
            }
        } catch {
            AppLogger.log("findMergeCandidates failed: \(error.localizedDescription)", category: "BusinessCard")
        }
    }

    func save() async -> UUID? {
        guard let env, let imageData else { return nil }
        isSaving = true
        defer { isSaving = false }
        let draft = BusinessCardImportDraft(
            displayName: displayName.trimmedCoscard(),
            cosplayCharacterName: normalizedOptional(cosplayCharacterName),
            memo: normalizedOptional(memo),
            eventTag: normalizedOptional(eventTag),
            imageData: imageData,
            thumbnailData: thumbnailData,
            captureSourceType: captureSourceType,
            capturedAt: capturedAt,
            ocrRawText: ocrRawText,
            qrRawValue: qrRawValue,
            links: normalizedLinks(),
            extractionResults: extractionResults
        )
        do {
            return try await SaveBusinessCardImportUseCase(
                peerRepository: env.peerRepository,
                businessCardRepository: env.businessCardRepository
            ).execute(
                draft: draft,
                mergePeerId: selectedMergePeerId
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func apply(_ extraction: BusinessCardExtraction) {
        ocrRawText = extraction.ocrRawText
        qrRawValue = extraction.qrRawValues.joined(separator: "\n")
        extractionResults = extraction.extractionResults
        links = extraction.links
        if displayName.trimmedCoscard().isEmpty {
            displayName = extraction.suggestedDisplayName ?? ""
        }
        if cosplayCharacterName.trimmedCoscard().isEmpty {
            cosplayCharacterName = extraction.suggestedCosplayCharacterName ?? ""
        }
    }

    private func normalizedLinks() -> [ContactLinkDraft] {
        let normalized = links.compactMap { link -> ContactLinkDraft? in
            let original = link.originalValue.trimmedCoscard()
            guard !original.isEmpty else { return nil }
            if var draft = ContactLinkNormalizer.normalize(
                original,
                hintedPlatform: link.platform,
                sourceType: link.sourceType
            ) {
                draft.id = link.id
                return draft
            }
            var fallback = link
            fallback.originalValue = original
            return fallback
        }
        return ContactLinkNormalizer.unique(normalized)
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }
}
