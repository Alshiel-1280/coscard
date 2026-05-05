import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = OnboardingViewModel()
    @State private var displayName = ""
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
                TextField("コスネーム（1〜24文字）", text: $displayName)
            } footer: {
                Text("\(displayName.count)/\(ProfileValidation.displayNameRange.upperBound)")
                    .font(.caption2)
                    .foregroundStyle(
                        displayName.count > ProfileValidation.displayNameRange.upperBound
                            ? AppColors.danger
                            : Color.secondary
                    )
            }
            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(AppColors.danger)
                }
            }
            Section {
                Button {
                    Task {
                        if await vm.save(displayName: displayName) { onComplete() }
                    }
                } label: {
                    Text("はじめる")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .disabled(!ProfileValidation.validateDisplayName(displayName))
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
