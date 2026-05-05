import Foundation

@MainActor
struct CreateProfileUseCase {
    let profileRepository: ProfileRepositoryProtocol

    func execute(_ draft: ProfileDraft) async throws -> ProfileSummary {
        guard ProfileValidation.validateDisplayName(draft.displayName) else {
            throw CreateProfileError.invalidDisplayName
        }
        guard ProfileValidation.validateCosplayCharacterName(draft.cosplayCharacterName) else {
            throw CreateProfileError.invalidCosplayCharacterName
        }
        return try await profileRepository.upsertProfile(draft)
    }
}

enum CreateProfileError: LocalizedError {
    case invalidDisplayName
    case invalidCosplayCharacterName

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "表示名は1〜24文字で入力してください"
        case .invalidCosplayCharacterName:
            return "キャラ名は40文字以内で入力してください"
        }
    }
}
