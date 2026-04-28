import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = ProfileEditViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isSaving = false

    var body: some View {
        Form {
            Section {
                TextField("1〜24文字", text: $vm.displayName)
                    .onChange(of: vm.displayName) { _, new in
                        if new.count > ProfileValidation.displayNameRange.upperBound {
                            vm.displayName = String(new.prefix(ProfileValidation.displayNameRange.upperBound))
                        }
                    }
            } header: {
                Text("ユーザーネーム")
            } footer: {
                Text("\(vm.displayName.count)/\(ProfileValidation.displayNameRange.upperBound)")
                    .font(.caption2)
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

            Section {
                TextField("XのユーザーID", text: $vm.xUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .onChange(of: vm.xUserID) { _, new in
                        if new.count > ProfileValidation.snsUserIDRange.upperBound {
                            vm.xUserID = String(new.prefix(ProfileValidation.snsUserIDRange.upperBound))
                        }
                    }
                TextField("InstagramのユーザーID", text: $vm.instagramUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .onChange(of: vm.instagramUserID) { _, new in
                        if new.count > ProfileValidation.snsUserIDRange.upperBound {
                            vm.instagramUserID = String(new.prefix(ProfileValidation.snsUserIDRange.upperBound))
                        }
                    }
                TextField("TikTokのユーザーID", text: $vm.tiktokUserID)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .onChange(of: vm.tiktokUserID) { _, new in
                        if new.count > ProfileValidation.snsUserIDRange.upperBound {
                            vm.tiktokUserID = String(new.prefix(ProfileValidation.snsUserIDRange.upperBound))
                        }
                    }
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
                            if await vm.save() {
                                dismiss()
                            } else {
                                isSaving = false
                            }
                        }
                    }
                    .disabled(vm.displayName.trimmedCoscard().isEmpty)
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
