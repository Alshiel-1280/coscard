import Foundation

@MainActor
struct StopExchangeUseCase {
    let nearby: NearbyServiceProtocol

    func execute() async {
        await nearby.stop()
    }
}
