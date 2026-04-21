import Foundation

@MainActor
struct SendInviteUseCase {
    let nearby: NearbyServiceProtocol

    func execute(candidate: PeerCandidate, previewName: String, previewIcon: Data?, exchangeId: UUID) async throws {
        try await nearby.sendInvite(to: candidate, previewName: previewName, previewIcon: previewIcon, exchangeId: exchangeId)
    }
}
