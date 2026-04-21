import SwiftUI

struct RootView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var launchVM = LaunchViewModel()
    @State private var hasProfile: Bool?

    var body: some View {
        Group {
            if !launchVM.isReady {
                LaunchView(viewModel: launchVM)
            } else if hasProfile == nil {
                ProgressView("読み込み中")
            } else if hasProfile == false {
                NavigationStack {
                    OnboardingView {
                        hasProfile = true
                    }
                }
            } else {
                MainTabView()
            }
        }
        .task(id: launchVM.isReady) {
            guard launchVM.isReady else { return }
            await loadProfileFlag()
        }
    }

    private func loadProfileFlag() async {
        try? await env.tokenRepository.pruneExpired()
        let uc = LoadInitialStateUseCase(profileRepository: env.profileRepository)
        let ok = (try? await uc.execute()) ?? false
        hasProfile = ok
    }
}

#Preview {
    RootView()
        .environmentObject(AppEnvironment.preview)
}
