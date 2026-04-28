import Foundation

struct DuplicateExchangeCheck: Equatable, Sendable {
    let localPeerKey: String
    let isDuplicate: Bool

    var requiresUserChoice: Bool {
        isDuplicate
    }
}

@MainActor
struct ResolveDuplicateExchangeUseCase {
    func check(peerProfile: LightweightProfile, peerRepository: PeerRepositoryProtocol) async throws -> DuplicateExchangeCheck {
        let key = LocalPeerKey.make(from: peerProfile)
        let publicProfileId = peerProfile.publicProfileId?.trimmedCoscard() ?? ""
        let hasSamePublicProfileId = publicProfileId.isEmpty
            ? false
            : try await peerRepository.hasPeer(withPublicProfileId: publicProfileId)
        let hasSameLocalPeerKey = try await peerRepository.hasPeer(withLocalPeerKey: key)
        let isDuplicate = hasSamePublicProfileId || hasSameLocalPeerKey
        logDuplicateIfNeeded(
            isDuplicate: isDuplicate,
            localPeerKey: key,
            matchedByPublicProfileId: hasSamePublicProfileId
        )
        return DuplicateExchangeCheck(localPeerKey: key, isDuplicate: isDuplicate)
    }

    /// 同一 localPeerKey の再交換を検知して、保存前のユーザー選択に渡せる結果を返す。
    func check(localPeerKey: String, peerRepository: PeerRepositoryProtocol) async throws -> DuplicateExchangeCheck {
        let isDuplicate = try await peerRepository.hasPeer(withLocalPeerKey: localPeerKey)
        logDuplicateIfNeeded(
            isDuplicate: isDuplicate,
            localPeerKey: localPeerKey,
            matchedByPublicProfileId: false
        )
        return DuplicateExchangeCheck(localPeerKey: localPeerKey, isDuplicate: isDuplicate)
    }

    /// 同一 localPeerKey の再交換を検知してログに残す（upsert は既存の PeerRepository が担当）。
    func logIfDuplicate(localPeerKey: String, peerRepository: PeerRepositoryProtocol) async throws {
        _ = try await check(localPeerKey: localPeerKey, peerRepository: peerRepository)
    }

    private func logDuplicateIfNeeded(
        isDuplicate: Bool,
        localPeerKey: String,
        matchedByPublicProfileId: Bool
    ) {
        guard isDuplicate else { return }
        let reason = matchedByPublicProfileId ? "publicProfileId/localPeerKey" : "localPeerKey"
        AppLogger.log(
            "Duplicate exchange: \(reason) already known (key prefix \(String(localPeerKey.prefix(12)))...)",
            category: "Exchange"
        )
    }
}
