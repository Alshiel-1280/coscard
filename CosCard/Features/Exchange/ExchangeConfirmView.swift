import SwiftUI

struct ExchangeConfirmView: View {
    let candidate: PeerCandidate
    @ObservedObject var viewModel: ExchangeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                outgoingApprovalView
                    .padding(AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            outgoingActionBar
        }
        .background(AppColors.background)
        .navigationTitle("交換リクエスト")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var outgoingApprovalView: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                ExchangeApprovalAvatar(
                    name: candidate.previewDisplayName,
                    imageData: candidate.previewIconThumbnailData,
                    size: 104,
                    cornerRadius: 28
                )

                VStack(spacing: AppSpacing.xs) {
                    Text(candidate.previewDisplayName)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    if let snippet = normalized(candidate.previewBioSnippet) {
                        Text(snippet)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)

            HStack(spacing: AppSpacing.sm) {
                ExchangeApprovalInfoBadge(systemImage: "antenna.radiowaves.left.and.right", text: "近くで検出")
                ExchangeApprovalInfoBadge(systemImage: "number", text: "コード確認")
            }
        }
    }

    private var outgoingActionBar: some View {
        VStack(spacing: AppSpacing.sm) {
            if isSending {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                    Text("リクエストを送信中…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            } else {
                Button {
                    sendInvite()
                } label: {
                    Label("リクエストを送る", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(AppSpacing.md)
        .background(.regularMaterial)
    }

    private func sendInvite() {
        guard !isSending else { return }
        isSending = true
        Task {
            await viewModel.sendInvite(to: candidate)
            dismiss()
        }
    }

    private func normalized(_ text: String?) -> String? {
        let value = text?.trimmedCoscard() ?? ""
        return value.isEmpty ? nil : value
    }
}

struct ExchangeApprovalAvatar: View {
    let name: String
    let imageData: Data?
    var size: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.card)
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel(name)
    }
}

struct ExchangeApprovalInfoBadge: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }
}

#Preview("Exchange Confirm") {
    NavigationStack {
        ExchangeConfirmView(
            candidate: PeerCandidate(
                mpcPeerId: "sample",
                previewDisplayName: "ゆき",
                previewBioSnippet: "今日は東館にいます"
            ),
            viewModel: ExchangeViewModel()
        )
        .environmentObject(AppEnvironment.preview)
    }
}
