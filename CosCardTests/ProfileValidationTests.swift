import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class ProfileValidationTests: XCTestCase {
    func testSNSUserIDValidationAcceptsPlainIDsOnly() {
        XCTAssertTrue(ProfileValidation.validateSNSUserID("cos_user.01"))
        XCTAssertTrue(ProfileValidation.validateSNSUserID("@cos_user"))
        XCTAssertFalse(ProfileValidation.validateSNSUserID("cos user"))
        XCTAssertFalse(ProfileValidation.validateSNSUserID("https://x.com/cos_user"))
        XCTAssertFalse(ProfileValidation.validateSNSUserID("x.com/cos_user"))
    }

    func testSNSUserIDNormalizeExtractsIDFromLegacyURLs() {
        XCTAssertEqual(SNSUserID.normalize("https://x.com/cos_user", service: .x), "cos_user")
        XCTAssertEqual(SNSUserID.normalize("https://instagram.com/cos.photo/", service: .instagram), "cos.photo")
        XCTAssertEqual(SNSUserID.normalize("https://www.tiktok.com/@cos_tok?lang=ja", service: .tiktok), "cos_tok")
        XCTAssertEqual(SNSUserID.normalize("@plain_id", service: .x), "plain_id")
    }

    func testExpiredEnvelopeThrows() async throws {
        let container = try ModelContainerProvider.makePreviewContainer()
        let context = ModelContext(container)
        let repo = TokenRepository(modelContext: context)

        let payload = LightweightProfilePayload(
            ephemeralToken: "tok",
            publicProfileId: nil,
            displayName: "A",
            bioShort: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            profileVersion: 1,
            iconThumbnailData: nil
        )
        let payloadData = try JSONEncoder().encode(payload)
        let envelope = WireEnvelope(
            schemaVersion: 1,
            messageType: .lightweightProfile,
            exchangeId: UUID(),
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(-60),
            payload: payloadData,
            checksum: ""
        )

        var caught: CosCardError?
        do {
            try await ProfileValidation.validateIncomingExchange(
                envelope: envelope,
                ephemeralToken: "tok",
                tokenRepository: repo
            )
        } catch let e as CosCardError {
            caught = e
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(caught, .envelopeExpired)
    }

    func testAlreadySeenTokenThrows() async throws {
        let container = try ModelContainerProvider.makePreviewContainer()
        let context = ModelContext(container)
        let repo = TokenRepository(modelContext: context)
        let inserted = try await repo.recordIncomingTokenIfNew(value: "dup", sessionId: UUID(), peerContactId: Optional<UUID>.none)
        XCTAssertTrue(inserted)

        let payload = LightweightProfilePayload(
            ephemeralToken: "dup",
            publicProfileId: nil,
            displayName: "A",
            bioShort: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            profileVersion: 1,
            iconThumbnailData: nil
        )
        let payloadData = try JSONEncoder().encode(payload)
        let envelope = WireEnvelope(
            schemaVersion: 1,
            messageType: .lightweightProfile,
            exchangeId: UUID(),
            issuedAt: Date(),
            expiresAt: Date().addingTimeInterval(120),
            payload: payloadData,
            checksum: ""
        )

        var caught: CosCardError?
        do {
            try await ProfileValidation.validateIncomingExchange(
                envelope: envelope,
                ephemeralToken: "dup",
                tokenRepository: repo
            )
        } catch let e as CosCardError {
            caught = e
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(caught, .tokenAlreadyUsed)
    }
}
