import Foundation
import UIKit

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var workSamples = ""
    @Published var twitterURL = ""
    @Published var instagramURL = ""
    @Published var tiktokURL = ""
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
                workSamples = p.bio ?? ""
                twitterURL = p.twitterURL ?? ""
                instagramURL = p.instagramURL ?? ""
                tiktokURL = p.tiktokURL ?? ""
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
            bio: normalizedOptional(workSamples),
            primarySNSLabel: nil,
            primarySNSURL: nil,
            twitterURL: normalizedOptional(twitterURL),
            instagramURL: normalizedOptional(instagramURL),
            tiktokURL: normalizedOptional(tiktokURL),
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

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmedCoscard()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyLegacySNSDataIfNeeded(primaryLabel: String?, primaryURL: String?) {
        guard twitterURL.isEmpty, instagramURL.isEmpty, tiktokURL.isEmpty else { return }
        guard let legacyURL = normalizedOptional(primaryURL ?? "") else { return }

        let label = (primaryLabel ?? "").trimmedCoscard().lowercased()
        if label.contains("insta") {
            instagramURL = legacyURL
        } else if label.contains("tik") {
            tiktokURL = legacyURL
        } else {
            twitterURL = legacyURL
        }
    }
}
