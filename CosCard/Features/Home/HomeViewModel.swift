import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var profile: ProfileSummary?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        let uc = LoadInitialStateUseCase(profileRepository: env.profileRepository)
        do {
            _ = try await uc.execute()
        } catch {
            AppLogger.log("LoadInitialState failed: \(error.localizedDescription)", category: "Home")
        }
        do {
            profile = try await env.profileRepository.fetchCurrentProfile()
        } catch {
            AppLogger.log("fetchCurrentProfile failed: \(error.localizedDescription)", category: "Home")
        }
    }
}
