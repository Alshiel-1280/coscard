import SwiftUI

struct ExchangeCompleteView: View {
    let peerName: String
    var isDuplicateExchange = false
    @State private var memo = ""
    @State private var eventTag = ""
    @State private var isSaving = false
    var onDone: (_ memo: String?, _ eventTag: String?, _ duplicateChoice: DuplicateExchangeSaveChoice) -> Void

    init(
        peerName: String,
        isDuplicateExchange: Bool = false,
        onDone: @escaping (_ memo: String?, _ eventTag: String?) -> Void
    ) {
        self.peerName = peerName
        self.isDuplicateExchange = isDuplicateExchange
        self.onDone = { memo, eventTag, _ in
            onDone(memo, eventTag)
        }
    }

    init(
        peerName: String,
        isDuplicateExchange: Bool = false,
        onDone: @escaping (_ memo: String?, _ eventTag: String?, _ duplicateChoice: DuplicateExchangeSaveChoice) -> Void
    ) {
        self.peerName = peerName
        self.isDuplicateExchange = isDuplicateExchange
        self.onDone = onDone
    }

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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
            }
            .listRowBackground(Color.clear)
            if isDuplicateExchange {
                Section {
                    Label("保存済みの相手です", systemImage: "person.crop.circle.badge.exclamationmark")
                        .font(.headline)
                    Text("更新するとプロフィール、メモ、イベントタグを今回の内容で保存します。スキップすると連絡先は更新しません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
                    Button(isDuplicateExchange ? "更新して完了" : "保存して完了") {
                        submit(.updateExisting)
                    }
                    if isDuplicateExchange {
                        Button("保存せず完了", role: .cancel) {
                            submit(.skip)
                        }
                    }
                }
            }
        }
        .navigationTitle("完了")
    }

    private func submit(_ duplicateChoice: DuplicateExchangeSaveChoice) {
        isSaving = true
        let m = memo.trimmedCoscard()
        let t = eventTag.trimmedCoscard()
        onDone(m.isEmpty ? nil : m, t.isEmpty ? nil : t, duplicateChoice)
    }
}

#Preview {
    NavigationStack {
        ExchangeCompleteView(peerName: "相手") { _, _ in }
    }
}
