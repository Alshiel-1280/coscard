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

enum CreateProfileError: LocalizedError {
    case invalidDisplayName

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "表示名は1〜24文字で入力してください"
        }
    }
}
