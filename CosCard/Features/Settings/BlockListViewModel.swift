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
        do {
            peers = try await env.peerRepository.listBlockedPeers(newestFirst: true)
        } catch {
            AppLogger.log("listBlockedPeers failed: \(error.localizedDescription)", category: "BlockList")
        }
    }

    func unblock(peerId: UUID) async {
        guard let env else { return }
        do {
            try await env.peerRepository.setBlocked(peerId: peerId, blocked: false)
        } catch {
            AppLogger.log("unblock failed: \(error.localizedDescription)", category: "BlockList")
        }
        await load()
        NotificationCenter.default.post(name: .coscardPeerBlockListDidChange, object: nil)
    }
}
