import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = SettingsViewModel()
    @AppStorage("coscard.settings.notifyExchangeRequest") private var notifyExchangeRequest = true
    @State private var showTokenDeleteConfirm = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("アカウント") {
                NavigationLink {
                    BlockListView()
                } label: {
                    Label("ブロックリスト", systemImage: "hand.raised.fill")
                }
            }
            Section {
                Toggle(isOn: $notifyExchangeRequest) {
                    Label("交換リクエスト通知", systemImage: "bell.badge")
                }
            } header: {
                Text("通知")
            } footer: {
                Text("将来の通知機能向けに保存されます。現バージョンではローカルのみです。")
                    .font(.caption)
            }
            Section {
                Button {
                    showTokenDeleteConfirm = true
                } label: {
                    Label("期限切れトークンを削除", systemImage: "trash")
                }
            } header: {
                Text("データ")
            } footer: {
                Text("交換で使う短命トークンのうち期限切れのものを端末内から削除します。")
                    .font(.caption)
            }
            Section("法的情報") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("プライバシーポリシー", systemImage: "lock.doc")
                }
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Label("利用規約", systemImage: "doc.text")
                }
            }
            Section("アプリ情報") {
                LabeledContent("バージョン", value: appVersion)
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.attach(env) }
        .confirmationDialog("期限切れトークンを削除しますか？", isPresented: $showTokenDeleteConfirm, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task { await vm.clearExpiredTokens() }
            }
        }
        .alert("結果", isPresented: $vm.showResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.cacheClearResultMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppEnvironment.preview)
    }
}
