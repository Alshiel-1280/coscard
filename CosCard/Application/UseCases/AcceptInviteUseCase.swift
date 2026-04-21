import Foundation

@MainActor
struct AcceptInviteUseCase {
    let nearby: NearbyServiceProtocol

    func execute() async throws {
        try await nearby.acceptInvite()
    }
}
