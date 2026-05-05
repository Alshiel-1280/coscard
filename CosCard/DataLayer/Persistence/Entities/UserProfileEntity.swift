import Foundation
import SwiftData

@Model
final class UserProfileEntity {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var displayNameReading: String?
    var cosplayCharacterName: String?
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var iconLocalPath: String?
    @Attribute(.externalStorage) var iconThumbnailData: Data?
    @Attribute(.externalStorage) var businessCardImageData: Data?
    var visibilityLevel: String
    var profileVersion: Int
    /// 交換ペイロード用の安定 ID（初回アクセスで生成・永続化）
    var publicProfileId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        displayNameReading: String? = nil,
        cosplayCharacterName: String? = nil,
        bio: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        twitterURL: String? = nil,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        iconLocalPath: String? = nil,
        iconThumbnailData: Data? = nil,
        businessCardImageData: Data? = nil,
        visibilityLevel: String = "public",
        profileVersion: Int = 1,
        publicProfileId: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.displayNameReading = displayNameReading
        self.cosplayCharacterName = cosplayCharacterName
        self.bio = bio
        self.primarySNSLabel = primarySNSLabel
        self.primarySNSURL = primarySNSURL
        self.twitterURL = twitterURL
        self.instagramURL = instagramURL
        self.tiktokURL = tiktokURL
        self.iconLocalPath = iconLocalPath
        self.iconThumbnailData = iconThumbnailData
        self.businessCardImageData = businessCardImageData
        self.visibilityLevel = visibilityLevel
        self.profileVersion = profileVersion
        self.publicProfileId = publicProfileId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
