import Foundation

/// WireEnvelope の JSON 送受信と checksum 検証。
enum MPCMessageEncoder {
    private struct WireEnvelopeTransport: Codable {
        var schemaVersion: Int
        var messageType: WireMessageType
        var exchangeId: UUID
        var issuedAt: Date
        var expiresAt: Date?
        var payloadBase64: String
        var checksum: String
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func encodeEnvelope<P: Encodable>(
        messageType: WireMessageType,
        exchangeId: UUID,
        payload: P,
        expiresAt: Date? = nil
    ) throws -> Data {
        let payloadData = try encoder.encode(payload)
        let issuedAt = Date()
        let checksum = makeChecksum(
            schemaVersion: WireSchema.currentVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            payload: payloadData
        )
        let transport = WireEnvelopeTransport(
            schemaVersion: WireSchema.currentVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            payloadBase64: payloadData.base64EncodedString(),
            checksum: checksum
        )
        return try encoder.encode(transport)
    }

    static func decodeEnvelope(_ data: Data) throws -> WireEnvelope {
        let t = try decoder.decode(WireEnvelopeTransport.self, from: data)
        guard let payloadData = Data(base64Encoded: t.payloadBase64) else {
            throw CosCardError.invalidPayload
        }
        let expected = makeChecksum(
            schemaVersion: t.schemaVersion,
            messageType: t.messageType,
            exchangeId: t.exchangeId,
            issuedAt: t.issuedAt,
            expiresAt: t.expiresAt,
            payload: payloadData
        )
        guard expected == t.checksum else {
            throw CosCardError.checksumMismatch
        }
        if t.schemaVersion != WireSchema.currentVersion {
            // TODO: マイグレーション
        }
        return WireEnvelope(
            schemaVersion: t.schemaVersion,
            messageType: t.messageType,
            exchangeId: t.exchangeId,
            issuedAt: t.issuedAt,
            expiresAt: t.expiresAt,
            payload: payloadData,
            checksum: t.checksum
        )
    }

    private static func makeChecksum(
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
}

enum CosCardError: Error {
    case invalidPayload
    case checksumMismatch
    case notConnected
    case peerNotFound
    case sessionMissing
}
