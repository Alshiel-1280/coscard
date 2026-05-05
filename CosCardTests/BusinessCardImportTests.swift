import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class BusinessCardImportTests: XCTestCase {
    func testContactLinkNormalizerNormalizesKnownSNSURLs() {
        let x = ContactLinkNormalizer.normalize("https://twitter.com/cos_user/status/1", sourceType: .qr)
        XCTAssertEqual(x?.platform, .x)
        XCTAssertEqual(x?.usernameCandidate, "cos_user")
        XCTAssertEqual(x?.normalizedURL, "https://x.com/cos_user")

        let instagram = ContactLinkNormalizer.normalize("instagram.com/cos.photo/", sourceType: .ocr)
        XCTAssertEqual(instagram?.platform, .instagram)
        XCTAssertEqual(instagram?.usernameCandidate, "cos.photo")
        XCTAssertEqual(instagram?.normalizedURL, "https://www.instagram.com/cos.photo/")

        let tiktok = ContactLinkNormalizer.normalize("https://www.tiktok.com/@cos_tok?lang=ja", sourceType: .ocr)
        XCTAssertEqual(tiktok?.platform, .tiktok)
        XCTAssertEqual(tiktok?.usernameCandidate, "cos_tok")
        XCTAssertEqual(tiktok?.normalizedURL, "https://www.tiktok.com/@cos_tok")
    }

    func testContactLinkNormalizerExtractsLabeledHandlesAndLinksFromOCRText() {
        let text = """
        X: @cos_x
        Instagram: cos.photo
        https://lit.link/coscard
        """
        let links = ContactLinkNormalizer.links(from: text, sourceType: .ocr)

        XCTAssertTrue(links.contains { $0.platform == .x && $0.usernameCandidate == "cos_x" })
        XCTAssertTrue(links.contains { $0.platform == .instagram && $0.usernameCandidate == "cos.photo" })
        XCTAssertTrue(links.contains { $0.platform == .litlink && $0.normalizedURL == "https://lit.link/coscard" })
    }

    func testSaveBusinessCardImportCreatesPeerCaptureAndLinks() async throws {
        let container = try ModelContainerProvider.makePreviewContainer()
        let context = ModelContext(container)
        let peerRepository = PeerRepository(modelContext: context)
        let businessCardRepository = BusinessCardRepository(modelContext: context)
        let xLink = try XCTUnwrap(ContactLinkNormalizer.normalize("x.com/cos_user", sourceType: .qr))
        let draft = BusinessCardImportDraft(
            displayName: "紙名刺さん",
            cosplayCharacterName: "初音ミク",
            memo: "撮影列で交換",
            eventTag: "C105",
            imageData: Data([0x01, 0x02, 0x03]),
            thumbnailData: Data([0x01]),
            captureSourceType: .library,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ocrRawText: "X: @cos_user",
            qrRawValue: "x.com/cos_user",
            links: [xLink],
            extractionResults: [
                ExtractionResultDraft(
                    kind: "qr",
                    originalValue: "x.com/cos_user",
                    normalizedValue: xLink.normalizedURL,
                    confidence: 1,
                    sourceType: .qr,
                    isAccepted: true
                ),
            ]
        )

        let peerId = try await SaveBusinessCardImportUseCase(
            peerRepository: peerRepository,
            businessCardRepository: businessCardRepository
        ).execute(draft: draft, mergePeerId: nil)

        let detail = try await peerRepository.fetchPeer(id: peerId)
        XCTAssertEqual(detail?.summary.latestDisplayName, "紙名刺さん")
        XCTAssertEqual(detail?.latestCosplayCharacterName, "初音ミク")
        XCTAssertEqual(detail?.latestTwitterURL, "cos_user")
        XCTAssertEqual(detail?.latestBusinessCardImageData, Data([0x01, 0x02, 0x03]))

        let links = try await businessCardRepository.listLinks(peerContactId: peerId)
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links.first?.platform, .x)
        XCTAssertEqual(links.first?.normalizedURL, "https://x.com/cos_user")

        let candidates = try await businessCardRepository.findMergeCandidates(
            displayName: "紙名刺さん",
            links: [xLink],
            limit: 5
        )
        XCTAssertEqual(candidates.first?.peerId, peerId)
        XCTAssertTrue(candidates.first?.reasons.contains("リンクが一致") == true)
    }
}
