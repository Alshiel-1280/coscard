import Foundation

/// 交換用の軽量プロフィール（ドメイン値）。SwiftData Entity は View に渡さない。
struct LightweightProfile: Equatable, Sendable {
    var ephemeralToken: String
    var displayName: String
    var bioShort: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var profileVersion: Int
    var iconThumbnailData: Data?

    init(
        ephemeralToken: String,
        displayName: String,
        bioShort: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        profileVersion: Int,
        iconThumbnailData: Data? = nil
    ) {
        self.ephemeralToken = ephemeralToken
        self.displayName = displayName
        self.bioShort = bioShort
        self.primarySNSLabel = primarySNSLabel
        self.primarySNSURL = primarySNSURL
        self.profileVersion = profileVersion
        self.iconThumbnailData = iconThumbnailData
    }
}
