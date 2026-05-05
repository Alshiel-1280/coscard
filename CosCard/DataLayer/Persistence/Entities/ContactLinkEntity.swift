import Foundation
import SwiftData

@Model
final class ContactLinkEntity {
    @Attribute(.unique) var id: UUID
    var peerContactId: UUID?
    var captureId: UUID?
    var platform: String
    var originalValue: String
    var normalizedURL: String?
    var usernameCandidate: String?
    var sourceType: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        peerContactId: UUID? = nil,
        captureId: UUID? = nil,
        platform: String,
        originalValue: String,
        normalizedURL: String? = nil,
        usernameCandidate: String? = nil,
        sourceType: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.peerContactId = peerContactId
        self.captureId = captureId
        self.platform = platform
        self.originalValue = originalValue
        self.normalizedURL = normalizedURL
        self.usernameCandidate = usernameCandidate
        self.sourceType = sourceType
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
