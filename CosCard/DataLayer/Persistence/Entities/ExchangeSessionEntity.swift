import Foundation
import SwiftData

@Model
final class ExchangeSessionEntity {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var state: String
    var result: String?
    var failureReason: String?
    var transport: String
    var confirmationCode: String?
    var peerPreviewName: String?
    @Attribute(.externalStorage) var peerPreviewIconData: Data?
    var eventTag: String?
    var createdAt: Date

    var peerContact: PeerContactEntity?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        state: String = ExchangeState.idle.rawValue,
        result: String? = nil,
        failureReason: String? = nil,
        transport: String = "mpc",
        confirmationCode: String? = nil,
        peerPreviewName: String? = nil,
        peerPreviewIconData: Data? = nil,
        eventTag: String? = nil,
        createdAt: Date = .now,
        peerContact: PeerContactEntity? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.state = state
        self.result = result
        self.failureReason = failureReason
        self.transport = transport
        self.confirmationCode = confirmationCode
        self.peerPreviewName = peerPreviewName
        self.peerPreviewIconData = peerPreviewIconData
        self.eventTag = eventTag
        self.createdAt = createdAt
        self.peerContact = peerContact
    }
}
