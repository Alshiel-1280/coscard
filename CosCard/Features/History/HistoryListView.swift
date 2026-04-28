import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = HistoryListViewModel()

    var body: some View {
        Group {
            if vm.peers.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: emptySystemImage,
                    description: Text(emptyDescription)
                )
            } else {
                List {
                    ForEach(vm.peers) { p in
                        NavigationLink(value: p.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.latestDisplayName).font(.headline)
                                HStack(spacing: AppSpacing.xs) {
                                    Text(p.lastMetAt.coscardShortString())
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    if p.isBlocked {
                                        Label("ブロック中", systemImage: "hand.raised.fill")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.danger)
                                    }
                                    if let memo = p.memo, !memo.isEmpty {
                                        Text("📝")
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .searchable(text: $vm.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "名前・メモを検索")
        .onChange(of: vm.searchText) { _, _ in
            vm.searchTextDidChange()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Picker("表示", selection: $vm.filter) {
                    ForEach(HistoryListViewModel.Filter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: vm.filter) { _, _ in
                    Task { await vm.filterDidChange() }
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            PeerDetailView(peerId: id)
        }
        .refreshable { await vm.load() }
        .task {
            vm.attach(env)
            await vm.load()
        }
    }

    private var emptyTitle: String {
        if vm.isFiltering {
            "条件に合う履歴がありません"
        } else {
            "まだ交換履歴がありません"
        }
    }

    private var emptySystemImage: String {
        vm.isFiltering ? "magnifyingglass" : "person.2.slash"
    }

    private var emptyDescription: String {
        if vm.isFiltering {
            "検索ワードや表示条件を変えると、見つかる可能性があります。"
        } else {
            "近くの相手とプロフィールを交換すると、ここに記録されます。"
        }
    }
}

#Preview {
    NavigationStack {
        HistoryListView()
            .environmentObject(AppEnvironment.preview)
    }
}
