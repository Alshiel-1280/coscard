import Foundation

struct PeerSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var localPeerKey: String
    var latestDisplayName: String
    var latestBio: String?
    var memo: String?
    var lastMetAt: Date
    var isBlocked: Bool
    var isHidden: Bool
}

struct PeerDetail: Equatable, Sendable {
    var summary: PeerSummary
    var latestSNSLabel: String?
    var latestSNSURL: String?
    var latestIconThumbnailData: Data?
    var firstMetAt: Date
    var lastEventTag: String?
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
    func hasPeer(withLocalPeerKey key: String) async throws -> Bool

    func upsertPeerFromExchange(
        localPeerKey: String,
        received: LightweightProfile,
        memo: String?,
        eventTag: String?
    ) async throws -> UUID
}
