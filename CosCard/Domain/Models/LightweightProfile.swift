import Foundation

/// 交換用の軽量プロフィール（ドメイン値）。SwiftData Entity は View に渡さない。
struct LightweightProfile: Equatable, Sendable {
    var ephemeralToken: String
    var publicProfileId: String?
    var displayName: String
    var cosplayCharacterName: String?
    var bioShort: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var profileVersion: Int
    var iconThumbnailData: Data?
    var businessCardImageData: Data?

    init(
        ephemeralToken: String,
        publicProfileId: String? = nil,
        displayName: String,
        cosplayCharacterName: String? = nil,
        bioShort: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        twitterURL: String? = nil,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        profileVersion: Int,
        iconThumbnailData: Data? = nil,
        businessCardImageData: Data? = nil
    ) {
        self.ephemeralToken = ephemeralToken
        self.publicProfileId = publicProfileId
        self.displayName = displayName
        self.cosplayCharacterName = cosplayCharacterName
        self.bioShort = bioShort
        self.primarySNSLabel = primarySNSLabel
        self.primarySNSURL = primarySNSURL
        self.twitterURL = twitterURL
        self.instagramURL = instagramURL
        self.tiktokURL = tiktokURL
        self.profileVersion = profileVersion
        self.iconThumbnailData = iconThumbnailData
        self.businessCardImageData = businessCardImageData
    }
}
