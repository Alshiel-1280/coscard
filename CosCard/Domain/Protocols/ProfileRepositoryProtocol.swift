import Foundation

struct ProfileDraft: Sendable {
    var displayName: String
    var cosplayCharacterName: String?
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var iconThumbnailData: Data?
    var businessCardImageData: Data?

    init(
        displayName: String,
        cosplayCharacterName: String? = nil,
        bio: String? = nil,
        primarySNSLabel: String? = nil,
        primarySNSURL: String? = nil,
        twitterURL: String? = nil,
        instagramURL: String? = nil,
        tiktokURL: String? = nil,
        iconThumbnailData: Data? = nil,
        businessCardImageData: Data? = nil
    ) {
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
    }
}

struct ProfileSummary: Equatable, Sendable {
    var id: UUID
    var displayName: String
    var cosplayCharacterName: String?
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var iconThumbnailData: Data?
    var businessCardImageData: Data?
    var profileVersion: Int
    var publicProfileId: String?
    var updatedAt: Date
}

struct BusinessCardHistoryItem: Equatable, Sendable {
    var id: UUID
    var cosplayCharacterName: String?
    var businessCardImageData: Data?
    var createdAt: Date
}

@MainActor
protocol ProfileRepositoryProtocol: AnyObject {
    func fetchCurrentProfile() async throws -> ProfileSummary?
    func upsertProfile(_ draft: ProfileDraft) async throws -> ProfileSummary
    func listBusinessCardHistory(newestFirst: Bool) async throws -> [BusinessCardHistoryItem]
    func saveBusinessCardSnapshot(cosplayCharacterName: String?, imageData: Data) async throws -> BusinessCardHistoryItem
    /// 未設定なら UUID を生成して保存し、以降は同じ値を返す。
    func ensurePublicProfileId() async throws -> String
}
