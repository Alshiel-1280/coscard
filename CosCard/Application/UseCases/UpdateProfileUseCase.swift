import Foundation

enum ProfileEditValidationError: LocalizedError {
    case invalidDisplayName
    case invalidWorkSamples
    case invalidTwitterURL
    case invalidInstagramURL
    case invalidTikTokURL
    case invalidSNSURL

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "表示名は1〜24文字で入力してください"
        case .invalidWorkSamples:
            return "作例は300文字以内で入力してください"
        case .invalidTwitterURL:
            return "Twitter URLは200文字以内で入力してください"
        case .invalidInstagramURL:
            return "Instagram URLは200文字以内で入力してください"
        case .invalidTikTokURL:
            return "TikTok URLは200文字以内で入力してください"
        case .invalidSNSURL:
            return "SNS URLは200文字以内で入力してください"
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
        guard ProfileValidation.validateBio(draft.bio) else {
            throw ProfileEditValidationError.invalidWorkSamples
        }
        guard ProfileValidation.validateSNSURL(draft.twitterURL) else {
            throw ProfileEditValidationError.invalidTwitterURL
        }
        guard ProfileValidation.validateSNSURL(draft.instagramURL) else {
            throw ProfileEditValidationError.invalidInstagramURL
        }
        guard ProfileValidation.validateSNSURL(draft.tiktokURL) else {
            throw ProfileEditValidationError.invalidTikTokURL
        }
        guard ProfileValidation.validateSNSURL(draft.primarySNSURL) else {
            throw ProfileEditValidationError.invalidSNSURL
        }
        return try await profileRepository.upsertProfile(draft)
    }
}
