import Foundation

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var displayNameReading = ""
    @Published var bio = ""
    @Published var primarySNSLabel = ""
    @Published var primarySNSURL = ""
    @Published var errorMessage: String?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        if let p = try? await env.profileRepository.fetchCurrentProfile() {
            displayName = p.displayName
            displayNameReading = p.displayNameReading ?? ""
            bio = p.bio ?? ""
            primarySNSLabel = p.primarySNSLabel ?? ""
            primarySNSURL = p.primarySNSURL ?? ""
        }
    }

    func save() async -> Bool {
        errorMessage = nil
        let draft = ProfileDraft(
            displayName: displayName.trimmedCoscard(),
            displayNameReading: displayNameReading.isEmpty ? nil : displayNameReading,
            bio: bio.isEmpty ? nil : bio,
            primarySNSLabel: primarySNSLabel.isEmpty ? nil : primarySNSLabel,
            primarySNSURL: primarySNSURL.isEmpty ? nil : primarySNSURL,
            iconThumbnailData: nil
        )
        guard let env else { return false }
        let uc = UpdateProfileUseCase(profileRepository: env.profileRepository)
        do {
            _ = try await uc.execute(draft)
            return true
        } catch let e as ProfileEditValidationError {
            errorMessage = e.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
