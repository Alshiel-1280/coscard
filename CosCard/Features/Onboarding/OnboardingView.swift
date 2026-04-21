import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = OnboardingViewModel()
    var onComplete: () -> Void

    var body: some View {
        Form {
            Section("コスネーム") {
                TextField("1〜24文字", text: $vm.displayName)
                    .onChange(of: vm.displayName) { _, new in
                        if new.count > ProfileValidation.displayNameRange.upperBound {
                            vm.displayName = String(new.prefix(ProfileValidation.displayNameRange.upperBound))
                        }
                    }
            }
            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(AppColors.danger)
                }
            }
            Section {
                Button("はじめる") {
                    Task {
                        if await vm.save() { onComplete() }
                    }
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
