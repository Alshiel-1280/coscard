import Foundation

@MainActor
struct RejectInviteUseCase {
    let nearby: NearbyServiceProtocol

    func execute() async throws {
        try await nearby.rejectInvite()
    }
}
