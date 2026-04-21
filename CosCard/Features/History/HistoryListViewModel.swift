import Foundation

@MainActor
final class HistoryListViewModel: ObservableObject {
    @Published private(set) var peers: [PeerSummary] = []

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        peers = (try? await env.peerRepository.listPeers(newestFirst: true)) ?? []
    }
}
