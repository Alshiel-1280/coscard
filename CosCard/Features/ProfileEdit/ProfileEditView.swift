import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = ProfileEditViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        Form {
            Section("ユーザーネーム") {
                TextField("1〜24文字", text: $vm.displayName)
                    .onChange(of: vm.displayName) { _, new in
                        if new.count > ProfileValidation.displayNameRange.upperBound {
                            vm.displayName = String(new.prefix(ProfileValidation.displayNameRange.upperBound))
                        }
                    }
            }

            Section("アイコン") {
                HStack(spacing: AppSpacing.md) {
                    iconPreview
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("写真を選択", systemImage: "photo")
                        }
                        if vm.iconThumbnailData != nil {
                            Button("アイコンを削除", role: .destructive) {
                                vm.removeIcon()
                            }
                        }
                    }
                }
            }

            Section("作例") {
                TextField("作品URLや実績など（任意）", text: $vm.workSamples, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .onChange(of: vm.workSamples) { _, new in
                        if new.count > ProfileValidation.bioRange.upperBound {
                            vm.workSamples = String(new.prefix(ProfileValidation.bioRange.upperBound))
                        }
                    }
            }

            Section("SNSリンク") {
                TextField("Twitter URL", text: $vm.twitterURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .onChange(of: vm.twitterURL) { _, new in
                        if new.count > ProfileValidation.snsURLRange.upperBound {
                            vm.twitterURL = String(new.prefix(ProfileValidation.snsURLRange.upperBound))
                        }
                    }
                TextField("Instagram URL", text: $vm.instagramURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .onChange(of: vm.instagramURL) { _, new in
                        if new.count > ProfileValidation.snsURLRange.upperBound {
                            vm.instagramURL = String(new.prefix(ProfileValidation.snsURLRange.upperBound))
                        }
                    }
                TextField("TikTok URL", text: $vm.tiktokURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .onChange(of: vm.tiktokURL) { _, new in
                        if new.count > ProfileValidation.snsURLRange.upperBound {
                            vm.tiktokURL = String(new.prefix(ProfileValidation.snsURLRange.upperBound))
                        }
                    }
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(AppColors.danger) }
            }

            Section {
                Button("保存") {
                    Task {
                        if await vm.save() { dismiss() }
                    }
                }
            }
        }
        .navigationTitle("プロフィール編集")
        .task {
            vm.attach(env)
            await vm.load()
        }
        .task(id: selectedPhoto) { await loadSelectedPhoto() }
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let data = vm.iconThumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppColors.card)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            let data = try await selectedPhoto.loadTransferable(type: Data.self)
            vm.updateIcon(rawData: data)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
        self.selectedPhoto = nil
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
            .environmentObject(AppEnvironment.preview)
    }
}
