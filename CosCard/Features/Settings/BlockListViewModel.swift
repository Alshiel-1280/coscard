import Foundation

@MainActor
final class BlockListViewModel: ObservableObject {
    @Published private(set) var peers: [PeerSummary] = []

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        peers = (try? await env.peerRepository.listBlockedPeers(newestFirst: true)) ?? []
    }

    func unblock(peerId: UUID) async {
        guard let env else { return }
        try? await env.peerRepository.setBlocked(peerId: peerId, blocked: false)
        await load()
    }
}
