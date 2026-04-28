import Foundation

@MainActor
struct SendInviteUseCase {
    let nearby: NearbyServiceProtocol

    func execute(
        candidate: PeerCandidate,
        previewName: String,
        previewIcon: Data?,
        publicProfileId: String?,
        exchangeId: UUID
    ) async throws {
        try await nearby.sendInvite(
            to: candidate,
            previewName: previewName,
            previewIcon: previewIcon,
            publicProfileId: publicProfileId,
            exchangeId: exchangeId
        )
    }
}
