import SwiftUI

struct IncomingInviteView: View {
    let previewName: String
    var onAccept: () -> Void
    var onReject: () -> Void
    @State private var isResponding = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                incomingApprovalView
                    .padding(AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            incomingActionBar
        }
        .background(AppColors.background)
    }

    private var incomingApprovalView: some View {
        VStack(spacing: AppSpacing.lg) {
            ExchangeApprovalAvatar(
                name: previewName,
                imageData: nil,
                size: 104,
                cornerRadius: 28
            )

            VStack(spacing: AppSpacing.xs) {
                Text(previewName)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .accessibilityLabel("\(previewName)からの交換リクエスト")

                Text("交換リクエスト")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, AppSpacing.sm)

            HStack(spacing: AppSpacing.sm) {
                ExchangeApprovalInfoBadge(systemImage: "person.2.wave.2.fill", text: "近くの相手")
                ExchangeApprovalInfoBadge(systemImage: "number", text: "コード確認")
            }
        }
        .padding(.top, AppSpacing.lg)
    }

    private var incomingActionBar: some View {
        HStack(spacing: AppSpacing.md) {
            Button(role: .destructive) {
                respond(onReject)
            } label: {
                Label("拒否", systemImage: "xmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isResponding)
            .accessibilityHint("このリクエストを断ります")

            Button {
                respond(onAccept)
            } label: {
                Label(isResponding ? "処理中…" : "承諾", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isResponding)
            .accessibilityHint("交換を開始します")
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial)
    }

    private func respond(_ action: () -> Void) {
        guard !isResponding else { return }
        isResponding = true
        action()
    }
}

#Preview {
    IncomingInviteView(previewName: "相手の名前", onAccept: {}, onReject: {})
}
