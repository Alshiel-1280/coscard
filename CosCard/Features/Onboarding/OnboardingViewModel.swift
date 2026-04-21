import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var errorMessage: String?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    @discardableResult
    func save() async -> Bool {
        errorMessage = nil
        let draft = ProfileDraft(
            displayName: displayName.trimmedCoscard(),
            displayNameReading: nil,
            bio: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            iconThumbnailData: nil
        )
        guard let env else { return false }
        let uc = CreateProfileUseCase(profileRepository: env.profileRepository)
        do {
            _ = try await uc.execute(draft)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
