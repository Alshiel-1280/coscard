import Foundation
import UIKit

struct ProfileEditFormDraft: Equatable, Sendable {
    var displayName = ""
    var cosplayCharacterName = ""
    var xUserID = ""
    var instagramUserID = ""
    var tiktokUserID = ""
}

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published private(set) var iconThumbnailData: Data?
    @Published private(set) var businessCardImageData: Data?
    @Published var errorMessage: String?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async -> ProfileEditFormDraft {
        guard let env else { return ProfileEditFormDraft() }
        do {
            if let p = try await env.profileRepository.fetchCurrentProfile() {
                iconThumbnailData = p.iconThumbnailData
                businessCardImageData = p.businessCardImageData
                return formDraft(from: p)
            }
        } catch {
            AppLogger.log("fetchCurrentProfile failed: \(error.localizedDescription)", category: "ProfileEdit")
        }
        return ProfileEditFormDraft()
    }

    func save(_ form: ProfileEditFormDraft) async -> Bool {
        errorMessage = nil
        let draft = ProfileDraft(
            displayName: form.displayName.trimmedCoscard(),
            cosplayCharacterName: normalizedOptional(form.cosplayCharacterName),
            bio: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            twitterURL: SNSUserID.normalize(form.xUserID, service: .x),
            instagramURL: SNSUserID.normalize(form.instagramUserID, service: .instagram),
            tiktokURL: SNSUserID.normalize(form.tiktokUserID, service: .tiktok),
            iconThumbnailData: iconThumbnailData,
            businessCardImageData: businessCardImageData
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

    func updateIcon(rawData: Data?) {
        guard let rawData else {
            iconThumbnailData = nil
            return
        }
        guard let image = UIImage(data: rawData),
              let thumb = ImageResizer.thumbnailJPEGData(from: image)
        else {
            errorMessage = "画像の読み込みに失敗しました"
            return
        }
        iconThumbnailData = thumb
    }

    func removeIcon() {
        iconThumbnailData = nil
    }

    func updateBusinessCard(rawData: Data?) {
        guard let rawData else {
            businessCardImageData = nil
            return
        }
        guard let image = UIImage(data: rawData),
              let cardData = ImageResizer.businessCardJPEGData(from: image)
        else {
            errorMessage = "名刺画像の読み込みまたは圧縮に失敗しました"
            return
        }
        businessCardImageData = cardData
    }

    func removeBusinessCard() {
        businessCardImageData = nil
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formDraft(from profile: ProfileSummary) -> ProfileEditFormDraft {
        var form = ProfileEditFormDraft(
            displayName: profile.displayName,
            cosplayCharacterName: profile.cosplayCharacterName ?? "",
            xUserID: SNSUserID.normalize(profile.twitterURL, service: .x) ?? "",
            instagramUserID: SNSUserID.normalize(profile.instagramURL, service: .instagram) ?? "",
            tiktokUserID: SNSUserID.normalize(profile.tiktokURL, service: .tiktok) ?? ""
        )

        guard form.xUserID.isEmpty, form.instagramUserID.isEmpty, form.tiktokUserID.isEmpty else {
            return form
        }

        let raw = profile.primarySNSURL ?? ""

        let label = (profile.primarySNSLabel ?? "").trimmedCoscard().lowercased()
        if label.contains("insta") {
            form.instagramUserID = SNSUserID.normalize(raw, service: .instagram) ?? ""
        } else if label.contains("tik") {
            form.tiktokUserID = SNSUserID.normalize(raw, service: .tiktok) ?? ""
        } else {
            form.xUserID = SNSUserID.normalize(raw, service: .x) ?? ""
        }
        return form
    }
}
