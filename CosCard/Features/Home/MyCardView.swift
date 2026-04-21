import SwiftUI

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
        .task { await vm.load() }
        .onAppear { vm.attach(env) }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let p = vm.profile {
                Text(p.displayName)
                    .font(.title2.weight(.bold))
                if let reading = p.displayNameReading, !reading.isEmpty {
                    Text(reading)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let bio = p.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.top, AppSpacing.xs)
                }
                if let label = p.primarySNSLabel, !label.isEmpty, let url = p.primarySNSURL, !url.isEmpty {
                    LabeledContent(label, value: url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
}

#Preview {
    NavigationStack {
        MyCardView()
            .environmentObject(AppEnvironment.preview)
    }
}
