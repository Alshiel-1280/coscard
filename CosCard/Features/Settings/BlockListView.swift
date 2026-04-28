import SwiftUI

struct BlockListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = BlockListViewModel()
    @State private var peerPendingUnblock: PeerSummary?
    @State private var showUnblockConfirm = false

    var body: some View {
        Group {
            if vm.peers.isEmpty {
                ContentUnavailableView(
                    "ブロック中の相手はいません",
                    systemImage: "hand.raised.slash",
                    description: Text("履歴の詳細からブロックした相手がここに表示されます。")
                )
            } else {
                blockedPeerList
            }
        }
        .navigationTitle("ブロックリスト")
        .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "名前・メモで検索")
        .confirmationDialog("ブロックを解除しますか？", isPresented: $showUnblockConfirm, titleVisibility: .visible, presenting: peerPendingUnblock) { peer in
            Button("ブロック解除", role: .destructive) {
                Task { await vm.unblock(peerId: peer.id) }
            }
        } message: { peer in
            Text("\(peer.latestDisplayName) が今後の一覧や交換対象に表示されるようになります。")
        }
        .task {
            vm.attach(env)
            await vm.load()
        }
    }

    @ViewBuilder
    private var blockedPeerList: some View {
        if vm.filteredPeers.isEmpty {
            ContentUnavailableView.search(text: vm.searchText)
        } else {
            List {
                Section {
                    ForEach(vm.filteredPeers) { p in
                        NavigationLink(value: p.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.latestDisplayName).font(.headline)
                                Text(p.lastMetAt.coscardShortString())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(p.latestDisplayName)、最終交換 \(p.lastMetAt.coscardShortString())")
                        .accessibilityHint("詳細を開きます。スワイプ操作でブロックを解除できます。")
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("ブロック解除") {
                                peerPendingUnblock = p
                                showUnblockConfirm = true
                            }
                            .tint(.blue)
                        }
                    }
                } footer: {
                    Text("ブロックを解除すると、相手は履歴や交換候補に再び表示されます。")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PeerDetailView(peerId: id)
            }
        }
    }
}

#Preview {
    NavigationStack {
        BlockListView()
            .environmentObject(AppEnvironment.preview)
    }
}
