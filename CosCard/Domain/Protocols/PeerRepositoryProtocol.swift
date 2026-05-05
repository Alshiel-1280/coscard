import Foundation

struct PeerSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var localPeerKey: String
    var publicProfileId: String?
    var latestDisplayName: String
    var latestBio: String?
    var memo: String?
    var lastMetAt: Date
    var isBlocked: Bool
    var isHidden: Bool
}

struct PeerExchangeSessionRow: Identifiable, Equatable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var state: String
    var result: String?
    var failureReason: String?
    var transport: String
}

struct PeerDetail: Equatable, Sendable {
    var summary: PeerSummary
    var latestCosplayCharacterName: String?
    var latestSNSLabel: String?
    var latestSNSURL: String?
    var latestTwitterURL: String?
    var latestInstagramURL: String?
    var latestTiktokURL: String?
    var latestIconThumbnailData: Data?
    var latestBusinessCardImageData: Data?
    var firstMetAt: Date
    var lastMetAt: Date
    var lastEventTag: String?
    var exchangeSessions: [PeerExchangeSessionRow]
}

@MainActor
protocol PeerRepositoryProtocol: AnyObject {
    func listPeers(newestFirst: Bool) async throws -> [PeerSummary]
    /// ブロック済みの相手のみ（履歴一覧のフィルタとは独立）
    func listBlockedPeers(newestFirst: Bool) async throws -> [PeerSummary]
    func fetchPeer(id: UUID) async throws -> PeerDetail?
    func updateMemo(peerId: UUID, memo: String?) async throws
    func setBlocked(peerId: UUID, blocked: Bool) async throws
    func setHidden(peerId: UUID, hidden: Bool) async throws
    func isBlockedLocalPeerKey(_ key: String) async throws -> Bool
    /// ブロック済みピアの表示名（正規化）集合 — 招待時の簡易フィルタ用
    func blockedNormalizedDisplayNames() async throws -> Set<String>
    /// ブロック済みピアの publicProfileId 集合 — 招待時の安定識別子フィルタ用
    func blockedPublicProfileIds() async throws -> Set<String>
    func hasPeer(withLocalPeerKey key: String) async throws -> Bool
    func hasPeer(withPublicProfileId publicProfileId: String) async throws -> Bool

    func upsertPeerFromExchange(
        localPeerKey: String,
        received: LightweightProfile,
        memo: String?,
        eventTag: String?
    ) async throws -> UUID

    func upsertPeerFromBusinessCard(
        draft: BusinessCardImportDraft,
        mergePeerId: UUID?
    ) async throws -> UUID
}
