import SwiftUI

struct ExchangeConfirmView: View {
    let candidate: PeerCandidate
    @ObservedObject var viewModel: ExchangeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false

    var body: some View {
        Form {
            Section("相手") {
                ExchangeCandidateRow(candidate: candidate)
            }
            if isSending {
                Section {
                    HStack {
                        ProgressView()
                        Text("リクエストを送信中…")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Section {
                    Button("交換リクエストを送る") {
                        isSending = true
                        Task {
                            await viewModel.sendInvite(to: candidate)
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("確認")
    }
}
