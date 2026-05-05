import Foundation
import SwiftData

@Model
final class PeerContactEntity {
    @Attribute(.unique) var id: UUID
    var localPeerKey: String
    var publicProfileId: String?
    var latestDisplayName: String
    var latestCosplayCharacterName: String?
    var latestBio: String?
    var latestSNSLabel: String?
    var latestSNSURL: String?
    var latestTwitterURL: String?
    var latestInstagramURL: String?
    var latestTiktokURL: String?
    @Attribute(.externalStorage) var latestIconThumbnailData: Data?
    @Attribute(.externalStorage) var latestBusinessCardImageData: Data?
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
        publicProfileId: String? = nil,
        latestDisplayName: String,
        latestCosplayCharacterName: String? = nil,
        latestBio: String? = nil,
        latestSNSLabel: String? = nil,
        latestSNSURL: String? = nil,
        latestTwitterURL: String? = nil,
        latestInstagramURL: String? = nil,
        latestTiktokURL: String? = nil,
        latestIconThumbnailData: Data? = nil,
        latestBusinessCardImageData: Data? = nil,
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
        self.publicProfileId = publicProfileId
        self.latestDisplayName = latestDisplayName
        self.latestCosplayCharacterName = latestCosplayCharacterName
        self.latestBio = latestBio
        self.latestSNSLabel = latestSNSLabel
        self.latestSNSURL = latestSNSURL
        self.latestTwitterURL = latestTwitterURL
        self.latestInstagramURL = latestInstagramURL
        self.latestTiktokURL = latestTiktokURL
        self.latestIconThumbnailData = latestIconThumbnailData
        self.latestBusinessCardImageData = latestBusinessCardImageData
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
