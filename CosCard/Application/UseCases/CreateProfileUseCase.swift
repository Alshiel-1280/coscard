import Foundation

@MainActor
struct CreateProfileUseCase {
    let profileRepository: ProfileRepositoryProtocol

    func execute(_ draft: ProfileDraft) async throws -> ProfileSummary {
        guard ProfileValidation.validateDisplayName(draft.displayName) else {
            throw CreateProfileError.invalidDisplayName
        }
        return try await profileRepository.upsertProfile(draft)
    }
}

enum CreateProfileError: Error {
    case invalidDisplayName
}
