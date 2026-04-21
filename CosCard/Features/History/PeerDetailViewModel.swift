import Foundation

@MainActor
final class PeerDetailViewModel: ObservableObject {
    @Published private(set) var detail: PeerDetail?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load(peerId: UUID) async {
        guard let env else { return }
        detail = try? await env.peerRepository.fetchPeer(id: peerId)
    }

    func saveMemo(_ text: String) async {
        guard let env, let id = detail?.summary.id else { return }
        try? await env.peerRepository.updateMemo(peerId: id, memo: text.isEmpty ? nil : text)
        await load(peerId: id)
    }

    func toggleBlock() async {
        guard let env, let d = detail else { return }
        try? await env.peerRepository.setBlocked(peerId: d.summary.id, blocked: !d.summary.isBlocked)
        await load(peerId: d.summary.id)
    }

    func toggleHidden() async {
        guard let env, let d = detail else { return }
        try? await env.peerRepository.setHidden(peerId: d.summary.id, hidden: !d.summary.isHidden)
        await load(peerId: d.summary.id)
    }
}
