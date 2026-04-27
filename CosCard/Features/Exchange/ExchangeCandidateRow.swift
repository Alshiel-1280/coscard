import SwiftUI

struct ExchangeCandidateRow: View {
    let candidate: PeerCandidate

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if let data = candidate.previewIconThumbnailData,
               let ui = UIImage(data: data)
            {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.card)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.previewDisplayName)
                    .font(.headline)
                if let snippet = candidate.previewBioSnippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(candidate.previewDisplayName)
    }
}

#Preview {
    List {
        ExchangeCandidateRow(
            candidate: PeerCandidate(mpcPeerId: "x", previewDisplayName: "サンプル", previewBioSnippet: "よろしく")
        )
    }
}
