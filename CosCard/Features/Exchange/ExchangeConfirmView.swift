import SwiftUI

struct ExchangeConfirmView: View {
    let candidate: PeerCandidate
    @ObservedObject var viewModel: ExchangeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("相手") {
                ExchangeCandidateRow(candidate: candidate)
            }
            Section {
                Button("交換リクエストを送る") {
                    Task {
                        await viewModel.sendInvite(to: candidate)
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("確認")
    }
}
