import SwiftUI

struct PeerDetailView: View {
    let peerId: UUID
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = PeerDetailViewModel()
    @State private var memoText = ""

    var body: some View {
        Group {
            if let d = vm.detail {
                Form {
                    Section("プロフィール") {
                        Text(d.summary.latestDisplayName).font(.headline)
                        if let bio = d.summary.latestBio, !bio.isEmpty {
                            Text(bio)
                        }
                    }
                    Section("メモ") {
                        TextField("メモ", text: $memoText, axis: .vertical)
                            .lineLimit(3 ... 8)
                        Button("メモを保存") {
                            Task { await vm.saveMemo(memoText) }
                        }
                    }
                    Section {
                        Button(d.summary.isBlocked ? "ブロック解除" : "ブロック") {
                            Task { await vm.toggleBlock() }
                        }
                        Button(d.summary.isHidden ? "表示に戻す" : "非表示") {
                            Task { await vm.toggleHidden() }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("詳細")
        .task {
            vm.attach(env)
            await vm.load(peerId: peerId)
            memoText = vm.detail?.summary.memo ?? ""
        }
    }
}

#Preview {
    NavigationStack {
        PeerDetailView(peerId: UUID())
            .environmentObject(AppEnvironment.preview)
    }
}
