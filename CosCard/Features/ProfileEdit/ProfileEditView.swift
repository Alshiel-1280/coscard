import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = ProfileEditViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("表示名") {
                TextField("コスネーム", text: $vm.displayName)
                    .onChange(of: vm.displayName) { _, new in
                        if new.count > ProfileValidation.displayNameRange.upperBound {
                            vm.displayName = String(new.prefix(ProfileValidation.displayNameRange.upperBound))
                        }
                    }
                TextField("よみ（任意）", text: $vm.displayNameReading)
                    .onChange(of: vm.displayNameReading) { _, new in
                        if new.count > ProfileValidation.displayNameReadingRange.upperBound {
                            vm.displayNameReading = String(new.prefix(ProfileValidation.displayNameReadingRange.upperBound))
                        }
                    }
            }
            Section("ひとこと") {
                TextField("自己紹介", text: $vm.bio, axis: .vertical)
                    .lineLimit(3 ... 6)
                    .onChange(of: vm.bio) { _, new in
                        if new.count > ProfileValidation.bioRange.upperBound {
                            vm.bio = String(new.prefix(ProfileValidation.bioRange.upperBound))
                        }
                    }
            }
            Section("SNS") {
                TextField("ラベル", text: $vm.primarySNSLabel)
                    .onChange(of: vm.primarySNSLabel) { _, new in
                        if new.count > ProfileValidation.snsLabelRange.upperBound {
                            vm.primarySNSLabel = String(new.prefix(ProfileValidation.snsLabelRange.upperBound))
                        }
                    }
                TextField("URL", text: $vm.primarySNSURL)
                    .onChange(of: vm.primarySNSURL) { _, new in
                        if new.count > ProfileValidation.snsURLRange.upperBound {
                            vm.primarySNSURL = String(new.prefix(ProfileValidation.snsURLRange.upperBound))
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
        .task { await vm.load() }
        .onAppear { vm.attach(env) }
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
            .environmentObject(AppEnvironment.preview)
    }
}
