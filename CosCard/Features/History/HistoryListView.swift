import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = HistoryListViewModel()

    var body: some View {
        List {
            if vm.peers.isEmpty {
                Text("まだ履歴がありません")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.peers) { p in
                    NavigationLink(value: p.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.latestDisplayName).font(.headline)
                            Text(p.lastMetAt.coscardShortString())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .navigationDestination(for: UUID.self) { id in
            PeerDetailView(peerId: id)
        }
        .task { await vm.load() }
        .onAppear { vm.attach(env) }
    }
}

#Preview {
    NavigationStack {
        HistoryListView()
            .environmentObject(AppEnvironment.preview)
    }
}
