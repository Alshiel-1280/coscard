import SwiftUI

struct ExchangeCompleteView: View {
    let peerName: String
    var peerBio: String?
    @State private var memo = ""
    @State private var eventTag = ""
    @State private var isSaving = false
    var onDone: (_ memo: String?, _ eventTag: String?) -> Void

    var body: some View {
        Form {
            Section {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("交換完了")
                        .font(.title2.bold())
                    Text(peerName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if let bio = peerBio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
            .listRowBackground(Color.clear)
            Section("メモ（任意）") {
                TextField("メモ", text: $memo, axis: .vertical)
                    .lineLimit(2 ... 6)
            }
            Section("イベントタグ（任意）") {
                TextField("例: コミケ2日目", text: $eventTag)
            }
            Section {
                if isSaving {
                    HStack {
                        ProgressView()
                        Text("保存中…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("保存して完了") {
                        isSaving = true
                        let m = memo.trimmedCoscard()
                        let t = eventTag.trimmedCoscard()
                        onDone(m.isEmpty ? nil : m, t.isEmpty ? nil : t)
                    }
                }
            }
        }
        .navigationTitle("完了")
    }
}

#Preview {
    NavigationStack {
        ExchangeCompleteView(peerName: "相手", peerBio: "コスプレイヤーです") { _, _ in }
    }
}
