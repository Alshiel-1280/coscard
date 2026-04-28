import Foundation

@MainActor
final class HistoryListViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all
        case blocked

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all:
                "すべて"
            case .blocked:
                "ブロック中"
            }
        }
    }

    @Published var searchText = ""
    @Published var filter: Filter = .all
    @Published private(set) var peers: [PeerSummary] = []

    private var env: AppEnvironment?
    private var allPeers: [PeerSummary] = []

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        do {
            switch filter {
            case .all:
                allPeers = try await env.peerRepository.listPeers(newestFirst: true)
            case .blocked:
                allPeers = try await env.peerRepository.listBlockedPeers(newestFirst: true)
            }
            applyFilters()
        } catch {
            AppLogger.log("listPeers failed: \(error.localizedDescription)", category: "History")
        }
    }

    func filterDidChange() async {
        await load()
    }

    func searchTextDidChange() {
        applyFilters()
    }

    var isFiltering: Bool {
        filter != .all || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyFilters() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            peers = allPeers
            return
        }

        peers = allPeers.filter { peer in
            matches(query, in: peer.latestDisplayName)
                || matches(query, in: peer.latestBio)
                || matches(query, in: peer.memo)
        }
    }

    private func matches(_ query: String, in value: String?) -> Bool {
        guard let value, !value.isEmpty else { return false }
        return value.localizedStandardContains(query)
    }
}
