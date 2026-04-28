import Foundation

enum ProfileEditValidationError: LocalizedError {
    case invalidDisplayName
    case invalidXUserID
    case invalidInstagramUserID
    case invalidTikTokUserID

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "表示名は1〜24文字で入力してください"
        case .invalidXUserID:
            return "XのユーザーIDは50文字以内・空白なしで入力してください"
        case .invalidInstagramUserID:
            return "InstagramのユーザーIDは50文字以内・空白なしで入力してください"
        case .invalidTikTokUserID:
            return "TikTokのユーザーIDは50文字以内・空白なしで入力してください"
        }
    }
}

@MainActor
struct UpdateProfileUseCase {
    let profileRepository: ProfileRepositoryProtocol

    func execute(_ draft: ProfileDraft) async throws -> ProfileSummary {
        guard ProfileValidation.validateDisplayName(draft.displayName) else {
            throw ProfileEditValidationError.invalidDisplayName
        }
        guard ProfileValidation.validateSNSUserID(draft.twitterURL) else {
            throw ProfileEditValidationError.invalidXUserID
        }
        guard ProfileValidation.validateSNSUserID(draft.instagramURL) else {
            throw ProfileEditValidationError.invalidInstagramUserID
        }
        guard ProfileValidation.validateSNSUserID(draft.tiktokURL) else {
            throw ProfileEditValidationError.invalidTikTokUserID
        }
        return try await profileRepository.upsertProfile(draft)
    }
}
