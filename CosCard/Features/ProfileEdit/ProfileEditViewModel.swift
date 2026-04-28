import Foundation
import UIKit

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var xUserID = ""
    @Published var instagramUserID = ""
    @Published var tiktokUserID = ""
    @Published private(set) var iconThumbnailData: Data?
    @Published var errorMessage: String?

    private var env: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        env = environment
    }

    func load() async {
        guard let env else { return }
        do {
            if let p = try await env.profileRepository.fetchCurrentProfile() {
                displayName = p.displayName
                xUserID = SNSUserID.normalize(p.twitterURL, service: .x) ?? ""
                instagramUserID = SNSUserID.normalize(p.instagramURL, service: .instagram) ?? ""
                tiktokUserID = SNSUserID.normalize(p.tiktokURL, service: .tiktok) ?? ""
                iconThumbnailData = p.iconThumbnailData
                applyLegacySNSDataIfNeeded(primaryLabel: p.primarySNSLabel, primaryURL: p.primarySNSURL)
            }
        } catch {
            AppLogger.log("fetchCurrentProfile failed: \(error.localizedDescription)", category: "ProfileEdit")
        }
    }

    func save() async -> Bool {
        errorMessage = nil
        let draft = ProfileDraft(
            displayName: displayName.trimmedCoscard(),
            bio: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            twitterURL: SNSUserID.normalize(xUserID, service: .x),
            instagramURL: SNSUserID.normalize(instagramUserID, service: .instagram),
            tiktokURL: SNSUserID.normalize(tiktokUserID, service: .tiktok),
            iconThumbnailData: iconThumbnailData
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

    private func applyLegacySNSDataIfNeeded(primaryLabel: String?, primaryURL: String?) {
        guard xUserID.isEmpty, instagramUserID.isEmpty, tiktokUserID.isEmpty else { return }
        let raw = primaryURL ?? ""

        let label = (primaryLabel ?? "").trimmedCoscard().lowercased()
        if label.contains("insta") {
            instagramUserID = SNSUserID.normalize(raw, service: .instagram) ?? ""
        } else if label.contains("tik") {
            tiktokUserID = SNSUserID.normalize(raw, service: .tiktok) ?? ""
        } else {
            xUserID = SNSUserID.normalize(raw, service: .x) ?? ""
        }
    }
}
