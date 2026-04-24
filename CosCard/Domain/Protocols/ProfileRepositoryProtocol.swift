import Foundation

struct ProfileDraft: Sendable {
    var displayName: String
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var iconThumbnailData: Data?
}

struct ProfileSummary: Equatable, Sendable {
    var id: UUID
    var displayName: String
    var bio: String?
    var primarySNSLabel: String?
    var primarySNSURL: String?
    var twitterURL: String?
    var instagramURL: String?
    var tiktokURL: String?
    var iconThumbnailData: Data?
    var profileVersion: Int
    var updatedAt: Date
}

@MainActor
protocol ProfileRepositoryProtocol: AnyObject {
    func fetchCurrentProfile() async throws -> ProfileSummary?
    func upsertProfile(_ draft: ProfileDraft) async throws -> ProfileSummary
}
