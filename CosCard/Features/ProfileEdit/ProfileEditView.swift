import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = ProfileEditViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedBusinessCardPhoto: PhotosPickerItem?
    @State private var isSaving = false
    @State private var draft = ProfileEditFormDraft()
    @State private var iconPreviewImage: UIImage?
    @State private var businessCardPreviewImage: UIImage?

    var body: some View {
        Form {
            Section {
                TextField("1〜24文字", text: $draft.displayName)
            } header: {
                Text("ユーザーネーム")
            } footer: {
                characterCounter(
                    count: draft.displayName.count,
                    max: ProfileValidation.displayNameRange.upperBound
                )
            }

            Section {
                TextField("例: 初音ミク", text: $draft.cosplayCharacterName)
            } header: {
                Text("コスプレしているキャラ名")
            } footer: {
                characterCounter(
                    count: draft.cosplayCharacterName.count,
                    max: ProfileValidation.cosplayCharacterNameRange.upperBound
                )
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
                                iconPreviewImage = nil
                            }
                        }
                    }
                }
            }

            Section("名刺画像") {
                businessCardPreview
                HStack {
                    PhotosPicker(selection: $selectedBusinessCardPhoto, matching: .images) {
                        Label("名刺画像を選択", systemImage: "rectangle.stack")
                    }
                    if vm.businessCardImageData != nil {
                        Spacer()
                        Button("削除", role: .destructive) {
                            vm.removeBusinessCard()
                            businessCardPreviewImage = nil
                        }
                    }
                }
            }

            Section {
                TextField("XのユーザーID", text: $draft.xUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                TextField("InstagramのユーザーID", text: $draft.instagramUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                TextField("TikTokのユーザーID", text: $draft.tiktokUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
            } header: {
                Text("SNSユーザーID")
            } footer: {
                Text("各SNSのユーザーIDだけを入力してください")
                    .font(.caption2)
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(AppColors.danger) }
            }

            Section {
                if isSaving {
                    HStack {
                        ProgressView()
                        Text("保存中…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("保存") {
                        isSaving = true
                        Task {
                            if await vm.save(draft) {
                                dismiss()
                            } else {
                                isSaving = false
                            }
                        }
                    }
                    .disabled(!ProfileValidation.validateDisplayName(draft.displayName))
                }
            }
        }
        .navigationTitle("プロフィール編集")
        .task {
            vm.attach(env)
            draft = await vm.load()
            refreshPreviewImages()
        }
        .task(id: selectedPhoto) { await loadSelectedPhoto() }
        .task(id: selectedBusinessCardPhoto) { await loadSelectedBusinessCardPhoto() }
    }

    @ViewBuilder
    private var iconPreview: some View {
        if let image = iconPreviewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .accessibilityLabel("アイコン画像")
        } else {
            Circle()
                .fill(AppColors.card)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("アイコン未設定")
        }
    }

    @ViewBuilder
    private var businessCardPreview: some View {
        if let image = businessCardPreviewImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("名刺画像")
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppColors.card)
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .overlay {
                    VStack(spacing: AppSpacing.xs) {
                        Image(systemName: "rectangle.stack")
                            .font(.title2)
                        Text("名刺画像未登録")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .accessibilityLabel("名刺画像未登録")
        }
    }

    private func characterCounter(count: Int, max: Int) -> some View {
        Text("\(count)/\(max)")
            .font(.caption2)
            .foregroundStyle(count > max ? AppColors.danger : Color.secondary)
    }

    private func refreshPreviewImages() {
        iconPreviewImage = vm.iconThumbnailData.flatMap(UIImage.init(data:))
        businessCardPreviewImage = vm.businessCardImageData.flatMap(UIImage.init(data:))
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            let data = try await selectedPhoto.loadTransferable(type: Data.self)
            vm.updateIcon(rawData: data)
            iconPreviewImage = vm.iconThumbnailData.flatMap(UIImage.init(data:))
        } catch {
            vm.errorMessage = error.localizedDescription
        }
        self.selectedPhoto = nil
    }

    private func loadSelectedBusinessCardPhoto() async {
        guard let selectedBusinessCardPhoto else { return }
        do {
            let data = try await selectedBusinessCardPhoto.loadTransferable(type: Data.self)
            vm.updateBusinessCard(rawData: data)
            businessCardPreviewImage = vm.businessCardImageData.flatMap(UIImage.init(data:))
        } catch {
            vm.errorMessage = error.localizedDescription
        }
        self.selectedBusinessCardPhoto = nil
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
            .environmentObject(AppEnvironment.preview)
    }
}
