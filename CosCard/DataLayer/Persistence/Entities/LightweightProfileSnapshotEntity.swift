import Foundation
import SwiftData

@Model
final class LightweightProfileSnapshotEntity {
    @Attribute(.unique) var id: UUID
    var ownerType: String
    var ownerReferenceId: UUID?
    var displayName: String
    var cosplayCharacterName: String?
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    @Attribute(.externalStorage) var iconThumbnailData: Data?
    @Attribute(.externalStorage) var businessCardImageData: Data?
    var profileVersion: Int
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        ownerType: String,
        ownerReferenceId: UUID? = nil,
        displayName: String,
        cosplayCharacterName: String? = nil,
        bio: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        twitterURL: String? = nil,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        iconThumbnailData: Data? = nil,
        businessCardImageData: Data? = nil,
        profileVersion: Int = 1,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.ownerType = ownerType
        self.ownerReferenceId = ownerReferenceId
        self.displayName = displayName
        self.cosplayCharacterName = cosplayCharacterName
        self.bio = bio
        self.primarySNSLabel = primarySNSLabel
        self.primarySNSURL = primarySNSURL
        self.twitterURL = twitterURL
        self.instagramURL = instagramURL
        self.tiktokURL = tiktokURL
        self.iconThumbnailData = iconThumbnailData
        self.businessCardImageData = businessCardImageData
        self.profileVersion = profileVersion
        self.capturedAt = capturedAt
    }
}
