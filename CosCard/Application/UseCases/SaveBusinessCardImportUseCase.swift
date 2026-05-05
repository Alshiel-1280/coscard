import Foundation

@MainActor
struct SaveBusinessCardImportUseCase {
    let peerRepository: PeerRepositoryProtocol
    let businessCardRepository: BusinessCardRepositoryProtocol

    @discardableResult
    func execute(
        draft: BusinessCardImportDraft,
        mergePeerId: UUID?
    ) async throws -> UUID {
        let peerId = try await peerRepository.upsertPeerFromBusinessCard(
            draft: draft,
            mergePeerId: mergePeerId
        )
        _ = try await businessCardRepository.saveImport(
            draft: draft,
            linkedPeerContactId: peerId
        )
        return peerId
    }
}
