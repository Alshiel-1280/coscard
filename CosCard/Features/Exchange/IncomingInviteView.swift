import SwiftUI

struct IncomingInviteView: View {
    let previewName: String
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("交換リクエスト")
                .font(.title2.bold())
            Text(previewName)
                .font(.headline)
            HStack(spacing: AppSpacing.md) {
                Button("拒否", role: .destructive) { onReject() }
                Button("承諾") { onAccept() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    IncomingInviteView(previewName: "相手の名前", onAccept: {}, onReject: {})
}
