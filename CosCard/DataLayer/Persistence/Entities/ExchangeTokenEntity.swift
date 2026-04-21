import Foundation
import SwiftData

@Model
final class ExchangeTokenEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var tokenValue: String
    var direction: String
    var issuedAt: Date
    var expiresAt: Date
    var isConsumed: Bool
    var linkedSessionId: UUID?
    var linkedPeerContactId: UUID?

    init(
        id: UUID = UUID(),
        tokenValue: String,
        direction: String,
        issuedAt: Date = .now,
        expiresAt: Date = .now.addingTimeInterval(180),
        isConsumed: Bool = false,
        linkedSessionId: UUID? = nil,
        linkedPeerContactId: UUID? = nil
    ) {
        self.id = id
        self.tokenValue = tokenValue
        self.direction = direction
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.isConsumed = isConsumed
        self.linkedSessionId = linkedSessionId
        self.linkedPeerContactId = linkedPeerContactId
    }
}
