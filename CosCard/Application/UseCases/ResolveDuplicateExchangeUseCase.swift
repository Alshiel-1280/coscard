import Foundation

@MainActor
struct ResolveDuplicateExchangeUseCase {
    /// 同一 localPeerKey の再交換を検知してログに残す（upsert は既存の PeerRepository が担当）
    func logIfDuplicate(localPeerKey: String, peerRepository: PeerRepositoryProtocol) async throws {
        if try await peerRepository.hasPeer(withLocalPeerKey: localPeerKey) {
            AppLogger.log(
                "Duplicate exchange: localPeerKey already known (prefix \(String(localPeerKey.prefix(12)))…)",
                category: "Exchange"
            )
        }
    }
}
