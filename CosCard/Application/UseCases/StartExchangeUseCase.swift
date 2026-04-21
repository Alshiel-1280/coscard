import Foundation

@MainActor
struct StartExchangeUseCase {
    let nearby: NearbyServiceProtocol

    func execute(displayName: String) async throws {
        try await nearby.startAdvertisingAndBrowsing(displayName: displayName)
    }
}
