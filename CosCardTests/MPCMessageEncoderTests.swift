import XCTest
@testable import CosCard

final class MPCMessageEncoderTests: XCTestCase {
    func testEncodeDecodeRoundTrip_confirmationCode() throws {
        let exchangeId = UUID()
        let raw = try MPCMessageEncoder.encodeEnvelope(
            messageType: .confirmationCode,
            exchangeId: exchangeId,
            payload: ConfirmationCodePayload(code: "1234")
        )
        let envelope = try MPCMessageEncoder.decodeEnvelope(raw)
        XCTAssertEqual(envelope.messageType, .confirmationCode)
        XCTAssertEqual(envelope.exchangeId, exchangeId)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let p = try dec.decode(ConfirmationCodePayload.self, from: envelope.payload)
        XCTAssertEqual(p.code, "1234")
    }

    func testEncodeDecodeRoundTrip_lightweightProfile() throws {
        let exchangeId = UUID()
        let payload = LightweightProfilePayload(
            ephemeralToken: "abc",
            publicProfileId: "pub-1",
            displayName: "Test",
            bioShort: "bio",
            primarySNSLabel: "X",
            primarySNSURL: "https://example.com",
            profileVersion: 4,
            iconThumbnailData: nil
        )
        let exp = Date().addingTimeInterval(120)
        let raw = try MPCMessageEncoder.encodeEnvelope(
            messageType: .lightweightProfile,
            exchangeId: exchangeId,
            payload: payload,
            expiresAt: exp
        )
        let envelope = try MPCMessageEncoder.decodeEnvelope(raw)
        XCTAssertEqual(envelope.messageType, .lightweightProfile)
        XCTAssertEqual(envelope.exchangeId, exchangeId)
        XCTAssertNotNil(envelope.expiresAt)

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let decodedPayload = try dec.decode(LightweightProfilePayload.self, from: envelope.payload)
        XCTAssertEqual(decodedPayload.ephemeralToken, "abc")
        XCTAssertEqual(decodedPayload.publicProfileId, "pub-1")
        XCTAssertEqual(decodedPayload.displayName, "Test")
        XCTAssertEqual(decodedPayload.profileVersion, 4)
    }
}
