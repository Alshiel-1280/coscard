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

    func testEncodeEnvelope_usesCurrentSchemaVersionAndPayloadBase64() throws {
        let raw = try MPCMessageEncoder.encodeEnvelope(
            messageType: .confirmationCode,
            exchangeId: UUID(),
            payload: ConfirmationCodePayload(code: "4321")
        )

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        XCTAssertEqual(json["schemaVersion"] as? Int, WireSchema.currentVersion)
        XCTAssertNotNil(json["payloadBase64"] as? String)
        XCTAssertNil(json["payload"])
    }

    func testDecodeEnvelope_acceptsVersionOneForBackwardCompatibility() throws {
        let payload = try encodedConfirmationPayload(code: "2222")
        let raw = try makeTransportData(schemaVersion: 1, payloadData: payload)

        let envelope = try MPCMessageEncoder.decodeEnvelope(raw)

        XCTAssertEqual(envelope.schemaVersion, 1)
        let decoded = try JSONDecoder().decode(ConfirmationCodePayload.self, from: envelope.payload)
        XCTAssertEqual(decoded.code, "2222")
    }

    func testDecodeEnvelope_ignoresUnknownTransportFieldsForAdditiveCompatibility() throws {
        let payload = try encodedConfirmationPayload(code: "3333")
        let raw = try makeTransportData(payloadData: payload, compatibilityNote: "same-version additive field")

        let envelope = try MPCMessageEncoder.decodeEnvelope(raw)

        XCTAssertEqual(envelope.schemaVersion, WireSchema.currentVersion)
        let decoded = try JSONDecoder().decode(ConfirmationCodePayload.self, from: envelope.payload)
        XCTAssertEqual(decoded.code, "3333")
    }

    func testDecodeEnvelope_rejectsFutureSchemaVersion() throws {
        let futureVersion = WireSchema.currentVersion + 1
        let payload = try encodedConfirmationPayload(code: "9999")
        let raw = try makeTransportData(schemaVersion: futureVersion, payloadData: payload)

        assertDecodeThrows(.unsupportedSchemaVersion, data: raw)
    }

    func testDecodeEnvelope_rejectsFutureSchemaVersionBeforeCurrentTransportShape() {
        let futureVersion = WireSchema.currentVersion + 1
        let raw = Data(#"{"schemaVersion":\#(futureVersion)}"#.utf8)

        assertDecodeThrows(.unsupportedSchemaVersion, data: raw)
    }

    func testDecodeEnvelope_rejectsNonPositiveSchemaVersionAsInvalidPayload() throws {
        let payload = try encodedConfirmationPayload(code: "0000")
        let raw = try makeTransportData(schemaVersion: 0, payloadData: payload)

        assertDecodeThrows(.invalidPayload, data: raw)
    }

    func testDecodeEnvelope_rejectsMalformedJSONAsInvalidPayload() {
        let raw = Data("not json".utf8)

        assertDecodeThrows(.invalidPayload, data: raw)
    }

    func testDecodeEnvelope_rejectsMissingRequiredJSONFieldsAsInvalidPayload() {
        let raw = Data(#"{"schemaVersion":1}"#.utf8)

        assertDecodeThrows(.invalidPayload, data: raw)
    }

    func testDecodeEnvelope_rejectsInvalidPayloadBase64AsInvalidPayload() throws {
        let raw = try makeTransportData(payloadBase64: "%%%")

        assertDecodeThrows(.invalidPayload, data: raw)
    }

    func testDecodeEnvelope_rejectsNonJSONPayloadBytesAsInvalidPayload() throws {
        let payload = Data("not json".utf8)
        let raw = try makeTransportData(payloadData: payload)

        assertDecodeThrows(.invalidPayload, data: raw)
    }

    func testDecodeEnvelope_rejectsChecksumMismatch() throws {
        let payload = try encodedConfirmationPayload(code: "5555")
        let raw = try makeTransportData(payloadData: payload, checksum: "bad-checksum")

        assertDecodeThrows(.checksumMismatch, data: raw)
    }

    func testInvitePayloadRoundTrip_includesPublicProfileId() throws {
        let payload = InvitePayload(
            requesterPreviewName: "Test",
            requesterPreviewIconData: nil,
            publicProfileId: "pid-1"
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(InvitePayload.self, from: data)

        XCTAssertEqual(decoded.requesterPreviewName, "Test")
        XCTAssertEqual(decoded.publicProfileId, "pid-1")
    }

    func testInvitePayloadDecodesLegacyPayload_withoutPublicProfileId() throws {
        let data = #"{"requesterPreviewName":"Legacy"}"#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(InvitePayload.self, from: data)

        XCTAssertEqual(decoded.requesterPreviewName, "Legacy")
        XCTAssertNil(decoded.requesterPreviewIconData)
        XCTAssertNil(decoded.publicProfileId)
    }

    private struct TestWireEnvelopeTransport: Encodable {
        var schemaVersion: Int
        var messageType: WireMessageType
        var exchangeId: UUID
        var issuedAt: Date
        var expiresAt: Date?
        var payloadBase64: String
        var checksum: String
        var compatibilityNote: String?
    }

    private func encodedConfirmationPayload(code: String) throws -> Data {
        try JSONEncoder().encode(ConfirmationCodePayload(code: code))
    }

    private func makeTransportData(
        schemaVersion: Int = WireSchema.currentVersion,
        messageType: WireMessageType = .confirmationCode,
        exchangeId: UUID = UUID(),
        issuedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        expiresAt: Date? = nil,
        payloadData: Data = Data(#"{"code":"1234"}"#.utf8),
        payloadBase64: String? = nil,
        checksum: String? = nil,
        compatibilityNote: String? = nil
    ) throws -> Data {
        let effectivePayloadBase64 = payloadBase64 ?? payloadData.base64EncodedString()
        let effectiveChecksum = checksum ?? makeChecksum(
            schemaVersion: schemaVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            payload: payloadData
        )
        let transport = TestWireEnvelopeTransport(
            schemaVersion: schemaVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            payloadBase64: effectivePayloadBase64,
            checksum: effectiveChecksum,
            compatibilityNote: compatibilityNote
        )
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(transport)
    }

    private func makeChecksum(
        schemaVersion: Int,
        messageType: WireMessageType,
        exchangeId: UUID,
        issuedAt: Date,
        expiresAt: Date?,
        payload: Data
    ) -> String {
        let exp = expiresAt.map { String($0.timeIntervalSince1970) } ?? ""
        let parts = [
            "\(schemaVersion)",
            messageType.rawValue,
            exchangeId.uuidString,
            String(issuedAt.timeIntervalSince1970),
            exp,
            Checksum.sha256Hex(of: payload),
        ]
        return Checksum.sha256Hex(of: parts.joined(separator: "|"))
    }

    private func assertDecodeThrows(
        _ expected: CosCardError,
        data: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try MPCMessageEncoder.decodeEnvelope(data)
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as CosCardError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
