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
                .accessibilityLabel("\(previewName)からの交換リクエスト")
            HStack(spacing: AppSpacing.md) {
                Button("拒否", role: .destructive) { onReject() }
                    .accessibilityHint("このリクエストを断ります")
                Button("承諾") { onAccept() }
                    .accessibilityHint("交換を開始します")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    IncomingInviteView(previewName: "相手の名前", onAccept: {}, onReject: {})
}
