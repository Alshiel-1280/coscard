import Foundation

/// WireEnvelope の JSON 送受信と checksum 検証。
enum MPCMessageEncoder {
    private struct WireEnvelopeVersionProbe: Decodable {
        var schemaVersion: Int
    }

    private struct WireEnvelopeTransport: Codable {
        var schemaVersion: Int
        var messageType: WireMessageType
        var exchangeId: UUID
        var issuedAt: Date
        var expiresAt: Date?
        var payloadBase64: String
        var checksum: String
    }

    private static let minimumDecodableSchemaVersion = 1

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
        // ISO8601 の丸めで checksum がずれないよう秒単位に揃える
        let issuedAt = Self.wireDate(Date())
        let expiresSnap = expiresAt.map { Self.wireDate($0) }
        let checksum = makeChecksum(
            schemaVersion: WireSchema.currentVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresSnap,
            payload: payloadData
        )
        let transport = WireEnvelopeTransport(
            schemaVersion: WireSchema.currentVersion,
            messageType: messageType,
            exchangeId: exchangeId,
            issuedAt: issuedAt,
            expiresAt: expiresSnap,
            payloadBase64: payloadData.base64EncodedString(),
            checksum: checksum
        )
        return try encoder.encode(transport)
    }

    private static func wireDate(_ d: Date) -> Date {
        Date(timeIntervalSince1970: floor(d.timeIntervalSince1970))
    }

    static func decodeEnvelope(_ data: Data) throws -> WireEnvelope {
        let schemaVersion: Int
        do {
            schemaVersion = try decoder.decode(WireEnvelopeVersionProbe.self, from: data).schemaVersion
        } catch {
            throw CosCardError.invalidPayload
        }
        guard schemaVersion >= minimumDecodableSchemaVersion else {
            throw CosCardError.invalidPayload
        }
        guard schemaVersion <= WireSchema.currentVersion else {
            throw CosCardError.unsupportedSchemaVersion
        }
        let t: WireEnvelopeTransport
        do {
            t = try decoder.decode(WireEnvelopeTransport.self, from: data)
        } catch {
            throw CosCardError.invalidPayload
        }
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
        try validateJSONPayload(payloadData)
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

    private static func validateJSONPayload(_ payloadData: Data) throws {
        do {
            _ = try JSONSerialization.jsonObject(with: payloadData, options: [.fragmentsAllowed])
        } catch {
            throw CosCardError.invalidPayload
        }
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

enum CosCardError: Error, LocalizedError, Equatable {
    case invalidPayload
    case checksumMismatch
    case unsupportedSchemaVersion
    case notConnected
    case peerNotFound
    case sessionMissing
    case profileMissing
    case tokenAlreadyUsed
    case envelopeExpired

    var errorDescription: String? {
        switch self {
        case .invalidPayload: return "データの形式が正しくありません"
        case .checksumMismatch: return "データが壊れているか改ざんされています"
        case .unsupportedSchemaVersion: return "対応していない交換データのバージョンです"
        case .notConnected: return "接続されていません"
        case .peerNotFound: return "相手が見つかりません"
        case .sessionMissing: return "セッションがありません"
        case .profileMissing: return "プロフィールがありません"
        case .tokenAlreadyUsed: return "この交換コードは既に使用済みです"
        case .envelopeExpired: return "交換データの有効期限が切れています"
        }
    }
}
