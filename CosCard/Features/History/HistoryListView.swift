import SwiftUI

struct HistoryListView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = HistoryListViewModel()

    var body: some View {
        Group {
            if vm.peers.isEmpty {
                ContentUnavailableView(
                    "まだ交換履歴がありません",
                    systemImage: "person.2.slash",
                    description: Text("近くの相手とプロフィールを交換すると、ここに記録されます。")
                )
            } else {
                List {
                    ForEach(vm.peers) { p in
                        NavigationLink(value: p.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.latestDisplayName).font(.headline)
                                if let bio = p.latestBio, !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                HStack(spacing: AppSpacing.xs) {
                                    Text(p.lastMetAt.coscardShortString())
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
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
        .navigationDestination(for: UUID.self) { id in
            PeerDetailView(peerId: id)
        }
        .refreshable { await vm.load() }
        .onAppear {
            vm.attach(env)
            Task { await vm.load() }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryListView()
            .environmentObject(AppEnvironment.preview)
    }
}
