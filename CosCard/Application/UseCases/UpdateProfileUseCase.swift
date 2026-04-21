import Foundation

enum ProfileEditValidationError: LocalizedError {
    case invalidDisplayName
    case invalidDisplayNameReading
    case invalidBio
    case invalidSNSLabel
    case invalidSNSURL

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName:
            return "表示名は1〜24文字で入力してください"
        case .invalidDisplayNameReading:
            return "よみは24文字以内で入力してください"
        case .invalidBio:
            return "ひとことは80文字以内で入力してください"
        case .invalidSNSLabel:
            return "SNSラベルは20文字以内で入力してください"
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
        guard ProfileValidation.validateDisplayNameReading(draft.displayNameReading) else {
            throw ProfileEditValidationError.invalidDisplayNameReading
        }
        guard ProfileValidation.validateBio(draft.bio) else {
            throw ProfileEditValidationError.invalidBio
        }
        guard ProfileValidation.validateSNSLabel(draft.primarySNSLabel) else {
            throw ProfileEditValidationError.invalidSNSLabel
        }
        guard ProfileValidation.validateSNSURL(draft.primarySNSURL) else {
            throw ProfileEditValidationError.invalidSNSURL
        }
        return try await profileRepository.upsertProfile(draft)
    }
}
