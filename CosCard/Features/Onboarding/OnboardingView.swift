import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        Form {
            Section {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "person.crop.rectangle.stack.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)
                    Text("CosCard へようこそ")
                        .font(.title2.bold())
                    Text("オフラインで近くの人とプロフィールを交換できるアプリです。まずはコスネームを設定しましょう。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            }
            .listRowBackground(Color.clear)
            Section {
                TextField("コスネーム（1〜24文字）", text: $vm.displayName)
                    .onChange(of: vm.displayName) { _, new in
                        if new.count > ProfileValidation.displayNameRange.upperBound {
                            vm.displayName = String(new.prefix(ProfileValidation.displayNameRange.upperBound))
                        }
                    }
            } footer: {
                Text("\(vm.displayName.count)/\(ProfileValidation.displayNameRange.upperBound)")
                    .font(.caption2)
            }
            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(AppColors.danger)
                }
            }
            Section {
                Button {
                    Task {
                        if await vm.save() { onComplete() }
                    }
                } label: {
                    Text("はじめる")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .disabled(vm.displayName.trimmedCoscard().isEmpty)
            }
        }
        .navigationTitle("ようこそ")
        .onAppear { vm.attach(env) }
    }
}

#Preview {
    NavigationStack {
        OnboardingView(onComplete: {})
            .environmentObject(AppEnvironment.preview)
    }
}
