import PhotosUI
import SwiftUI
import UIKit

struct BusinessCardImportView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = BusinessCardImportViewModel()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    var onSaved: (UUID) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            Form {
                if vm.hasImage {
                    confirmationContent
                } else {
                    importActions
                }

                if let errorMessage = vm.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppColors.danger)
                    }
                }
            }
            .navigationTitle("名刺取り込み")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                if vm.hasImage {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("保存") {
                            Task {
                                if let peerId = await vm.save() {
                                    onSaved(peerId)
                                    dismiss()
                                }
                            }
                        }
                        .disabled(!vm.canSave)
                    }
                }
            }
            .task {
                vm.attach(env)
            }
            .task(id: selectedPhoto) {
                await loadSelectedPhoto()
            }
            .fullScreenCover(isPresented: $showCamera) {
                BusinessCardCameraPicker { data in
                    Task {
                        await vm.loadImage(rawData: data, sourceType: .camera)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var importActions: some View {
        Section {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("撮影する", systemImage: "camera")
                }
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("写真から選択", systemImage: "photo")
            }
        }
    }

    private var confirmationContent: some View {
        Group {
            Section("名刺画像") {
                if let image = vm.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("取り込み対象の名刺画像")
                }
                if vm.isAnalyzing {
                    HStack {
                        ProgressView()
                        Text("解析中…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("プロフィール候補") {
                TextField("名前", text: $vm.displayName)
                TextField("キャラ名", text: $vm.cosplayCharacterName)
                TextField("イベントタグ", text: $vm.eventTag)
                TextField("メモ", text: $vm.memo, axis: .vertical)
                    .lineLimit(2 ... 6)
                Button("統合候補を更新") {
                    Task { await vm.refreshMergeCandidates() }
                }
            }

            Section("リンク候補") {
                if vm.links.isEmpty {
                    Text("リンク候補なし")
                        .foregroundStyle(.secondary)
                }
                ForEach($vm.links) { $link in
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Picker("種別", selection: $link.platform) {
                            ForEach(ContactLinkPlatform.allCases) { platform in
                                Text(platform.displayName).tag(platform)
                            }
                        }
                        TextField("リンクまたはID", text: $link.originalValue)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                        if let normalizedURL = link.normalizedURL, !normalizedURL.isEmpty {
                            Text(normalizedURL)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        Button("削除", role: .destructive) {
                            vm.removeLink(id: link.id)
                        }
                        .font(.caption)
                    }
                }
                Button("リンクを追加") {
                    vm.addManualLink()
                }
                Button("リンクを再解析") {
                    vm.rebuildLinksFromCurrentValues()
                }
            }

            if !vm.mergeCandidates.isEmpty {
                Section("既存連絡先と統合") {
                    Button {
                        vm.selectedMergePeerId = nil
                    } label: {
                        HStack {
                            Text("新規保存")
                            Spacer()
                            if vm.selectedMergePeerId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(vm.mergeCandidates) { candidate in
                        Button {
                            vm.selectedMergePeerId = candidate.peerId
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate.displayName)
                                    Text(candidate.reasons.joined(separator: " / "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if vm.selectedMergePeerId == candidate.peerId {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            if let ocrRawText = vm.ocrRawText, !ocrRawText.isEmpty {
                Section {
                    DisclosureGroup("OCRテキスト") {
                        Text(ocrRawText)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                if vm.isSaving {
                    HStack {
                        ProgressView()
                        Text("保存中…")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button("保存") {
                        Task {
                            if let peerId = await vm.save() {
                                onSaved(peerId)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!vm.canSave)
                }
            }
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhoto else { return }
        do {
            let data = try await selectedPhoto.loadTransferable(type: Data.self)
            await vm.loadImage(rawData: data, sourceType: .library)
        } catch {
            vm.errorMessage = error.localizedDescription
        }
        self.selectedPhoto = nil
    }
}

#Preview {
    BusinessCardImportView()
        .environmentObject(AppEnvironment.preview)
}
