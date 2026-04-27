import SwiftUI
import UIKit

struct MyCardView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = HomeViewModel()

    var body: some View {
        List {
            Section {
                cardContent
            }
            .listRowInsets(EdgeInsets(top: AppSpacing.md, leading: AppSpacing.md, bottom: AppSpacing.md, trailing: AppSpacing.md))
            .listRowBackground(Color.clear)

            Section {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    Label("プロフィールを編集", systemImage: "pencil")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("マイカード")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("設定")
                }
            }
        }
        .onAppear {
            vm.attach(env)
            Task { await vm.load() }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let p = vm.profile {
                HStack(spacing: AppSpacing.md) {
                    iconView(data: p.iconThumbnailData)
                    Text(p.displayName)
                        .font(.title2.weight(.bold))
                }
                if let workSamples = p.bio, !workSamples.isEmpty {
                    Text(workSamples)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.top, AppSpacing.xs)
                }
                let links = socialLinks(from: p)
                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(links, id: \.label) { item in
                            socialLinkRow(label: item.label, urlString: item.url)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
            } else {
                Text("読み込み中…")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.card)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private func iconView(data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppColors.card)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }

    @ViewBuilder
    private func socialLinkRow(label: String, urlString: String) -> some View {
        if let url = URL(string: urlString), url.scheme != nil {
            Link(destination: url) {
                LabeledContent(label, value: urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            LabeledContent(label, value: urlString)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func socialLinks(from profile: ProfileSummary) -> [(label: String, url: String)] {
        var links: [(label: String, url: String)] = []
        if let twitter = normalized(profile.twitterURL) {
            links.append(("Twitter", twitter))
        }
        if let instagram = normalized(profile.instagramURL) {
            links.append(("Instagram", instagram))
        }
        if let tiktok = normalized(profile.tiktokURL) {
            links.append(("TikTok", tiktok))
        }
        if links.isEmpty,
           let label = normalized(profile.primarySNSLabel),
           let url = normalized(profile.primarySNSURL)
        {
            links.append((label, url))
        }
        return links
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    NavigationStack {
        MyCardView()
            .environmentObject(AppEnvironment.preview)
    }
}
