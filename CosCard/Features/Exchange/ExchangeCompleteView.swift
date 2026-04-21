import SwiftUI

struct ExchangeCompleteView: View {
    let peerName: String
    @State private var memo = ""
    @State private var eventTag = ""
    var onDone: (_ memo: String?, _ eventTag: String?) -> Void

    var body: some View {
        Form {
            Section("交換完了") {
                Text(peerName).font(.headline)
            }
            Section("メモ（任意）") {
                TextField("メモ", text: $memo, axis: .vertical)
                    .lineLimit(2 ... 6)
            }
            Section("イベントタグ（任意）") {
                TextField("例: コミケ2日目", text: $eventTag)
            }
            Section {
                Button("保存して完了") {
                    let m = memo.trimmedCoscard()
                    let t = eventTag.trimmedCoscard()
                    onDone(m.isEmpty ? nil : m, t.isEmpty ? nil : t)
                }
            }
        }
        .navigationTitle("完了")
    }
}

#Preview {
    NavigationStack {
        ExchangeCompleteView(peerName: "相手") { _, _ in }
    }
}
