import SwiftUI
import UIKit

struct BusinessCardHistoryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var items: [BusinessCardHistoryItem] = []
    @State private var errorMessage: String?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    var body: some View {
        Group {
            if items.isEmpty, errorMessage == nil {
                ContentUnavailableView(
                    "名刺履歴がありません",
                    systemImage: "rectangle.stack",
                    description: Text("名刺画像を保存すると、ここに履歴が残ります。")
                )
            } else {
                List {
                    ForEach(items, id: \.id) { item in
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    if let characterName = normalized(item.cosplayCharacterName) {
                                        Text(characterName)
                                            .font(.headline)
                                    } else {
                                        Text("キャラ名未設定")
                                            .font(.headline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(Self.dateFormatter.string(from: item.createdAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            if let data = item.businessCardImageData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .accessibilityLabel("保存済み名刺画像")
                            } else {
                                Text("名刺画像なし")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, AppSpacing.xs)
                    }
                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(AppColors.danger)
                        }
                    }
                }
            }
        }
        .navigationTitle("名刺履歴")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do {
            items = try await env.profileRepository.listBusinessCardHistory(newestFirst: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        BusinessCardHistoryView()
            .environmentObject(AppEnvironment.preview)
    }
}
