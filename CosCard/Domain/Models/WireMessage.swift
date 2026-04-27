import Foundation

// MARK: - Wire protocol version

enum WireSchema {
    static let currentVersion = 1
}

// MARK: - Message type

enum WireMessageType: String, Codable, Sendable {
    case hello
    case invite
    case inviteAccepted
    case inviteRejected
    case confirmationCode
    case approvalState
    case lightweightProfile
    case ack
    case cancel
    case error
}

// MARK: - Envelope

struct WireEnvelope: Codable, Sendable {
    var schemaVersion: Int
    var messageType: WireMessageType
    var exchangeId: UUID
    var issuedAt: Date
    var expiresAt: Date?
    var payload: Data
    var checksum: String
}

// MARK: - Payloads

struct HelloPayload: Codable, Sendable {
    var peerSessionName: String
}

struct InvitePayload: Codable, Sendable {
    var requesterPreviewName: String
    var requesterPreviewIconData: Data?
}

struct InviteAcceptedPayload: Codable, Sendable {
    var acceptedAt: Date
}

struct InviteRejectedPayload: Codable, Sendable {
    var rejectedAt: Date
    var reason: String?
}

struct ConfirmationCodePayload: Codable, Sendable {
    var code: String
}

struct ApprovalStatePayload: Codable, Sendable {
    var approved: Bool
    var approvedAt: Date
}

struct LightweightProfilePayload: Codable, Sendable {
    var ephemeralToken: String
    var publicProfileId: String?
    var displayName: String
    var bioShort: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var profileVersion: Int
    var iconThumbnailData: Data?
}

struct AckPayload: Codable, Sendable {
    var receivedAt: Date
    var message: String?
}

struct CancelPayload: Codable, Sendable {
    var cancelledAt: Date
    var reason: String?
}

struct ErrorPayload: Codable, Sendable {
    var code: String
    var message: String
}
