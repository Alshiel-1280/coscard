import Foundation

@MainActor
final class PeerDetailViewModel: ObservableObject {
    @Published private(set) var detail: PeerDetail?
    @Published private(set) var contactLinks: [ContactLinkSummary] = []

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load(peerId: UUID) async {
        guard let env else { return }
        do {
            detail = try await env.peerRepository.fetchPeer(id: peerId)
            contactLinks = try await env.businessCardRepository.listLinks(peerContactId: peerId)
        } catch {
            AppLogger.log("fetchPeer failed: \(error.localizedDescription)", category: "PeerDetail")
        }
    }

    func saveMemo(_ text: String) async {
        guard let env, let id = detail?.summary.id else { return }
        do {
            try await env.peerRepository.updateMemo(peerId: id, memo: text.isEmpty ? nil : text)
        } catch {
            AppLogger.log("updateMemo failed: \(error.localizedDescription)", category: "PeerDetail")
        }
        await load(peerId: id)
    }

    func toggleBlock() async {
        guard let env, let d = detail else { return }
        do {
            try await env.peerRepository.setBlocked(peerId: d.summary.id, blocked: !d.summary.isBlocked)
        } catch {
            AppLogger.log("setBlocked failed: \(error.localizedDescription)", category: "PeerDetail")
        }
        await load(peerId: d.summary.id)
        NotificationCenter.default.post(name: .coscardPeerBlockListDidChange, object: nil)
    }

    func toggleHidden() async {
        guard let env, let d = detail else { return }
        do {
            try await env.peerRepository.setHidden(peerId: d.summary.id, hidden: !d.summary.isHidden)
        } catch {
            AppLogger.log("setHidden failed: \(error.localizedDescription)", category: "PeerDetail")
        }
        await load(peerId: d.summary.id)
    }
}
