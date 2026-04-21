import Foundation
import SwiftData

@Model
final class PeerContactEntity {
    @Attribute(.unique) var id: UUID
    var localPeerKey: String
    var latestDisplayName: String
    var latestBio: String?
    var latestSNSLabel: String?
    var latestSNSURL: String?
    @Attribute(.externalStorage) var latestIconThumbnailData: Data?
    var firstMetAt: Date
    var lastMetAt: Date
    var lastEventTag: String?
    var memo: String?
    var isBlocked: Bool
    var isHidden: Bool
    var lastReceivedProfileVersion: Int?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ExchangeSessionEntity.peerContact)
    var sessions: [ExchangeSessionEntity] = []

    init(
        id: UUID = UUID(),
        localPeerKey: String,
        latestDisplayName: String,
        latestBio: String? = nil,
        latestSNSLabel: String? = nil,
        latestSNSURL: String? = nil,
        latestIconThumbnailData: Data? = nil,
        firstMetAt: Date = .now,
        lastMetAt: Date = .now,
        lastEventTag: String? = nil,
        memo: String? = nil,
        isBlocked: Bool = false,
        isHidden: Bool = false,
        lastReceivedProfileVersion: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.localPeerKey = localPeerKey
        self.latestDisplayName = latestDisplayName
        self.latestBio = latestBio
        self.latestSNSLabel = latestSNSLabel
        self.latestSNSURL = latestSNSURL
        self.latestIconThumbnailData = latestIconThumbnailData
        self.firstMetAt = firstMetAt
        self.lastMetAt = lastMetAt
        self.lastEventTag = lastEventTag
        self.memo = memo
        self.isBlocked = isBlocked
        self.isHidden = isHidden
        self.lastReceivedProfileVersion = lastReceivedProfileVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
