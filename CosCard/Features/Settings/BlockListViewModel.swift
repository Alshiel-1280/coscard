import Foundation

@MainActor
final class BlockListViewModel: ObservableObject {
    @Published private(set) var peers: [PeerSummary] = []
    @Published var searchText = ""

    var filteredPeers: [PeerSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return peers }

        return peers.filter { peer in
            peer.latestDisplayName.localizedCaseInsensitiveContains(query)
                || peer.localPeerKey.localizedCaseInsensitiveContains(query)
                || (peer.publicProfileId?.localizedCaseInsensitiveContains(query) ?? false)
                || (peer.memo?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

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
