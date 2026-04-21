import SwiftUI

struct BlockListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = BlockListViewModel()

    var body: some View {
        Group {
            if vm.peers.isEmpty {
                ContentUnavailableView(
                    "ブロック中の相手はいません",
                    systemImage: "hand.raised.slash",
                    description: Text("履歴の詳細からブロックした相手がここに表示されます。")
                )
            } else {
                List {
                    ForEach(vm.peers) { p in
                        NavigationLink(value: p.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.latestDisplayName).font(.headline)
                                Text(p.lastMetAt.coscardShortString())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("ブロック解除") {
                                Task { await vm.unblock(peerId: p.id) }
                            }
                            .tint(.blue)
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    PeerDetailView(peerId: id)
                }
            }
        }
        .navigationTitle("ブロックリスト")
        .task { await vm.load() }
        .onAppear { vm.attach(env) }
    }
}

#Preview {
    NavigationStack {
        BlockListView()
            .environmentObject(AppEnvironment.preview)
    }
}
