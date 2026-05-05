import Foundation
import SwiftData

@MainActor
final class ProfileRepository: ProfileRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchCurrentProfile() async throws -> ProfileSummary? {
        var descriptor = FetchDescriptor<UserProfileEntity>()
        descriptor.fetchLimit = 1
        let list = try modelContext.fetch(descriptor)
        guard let e = list.first else { return nil }
        return map(e)
    }

    func ensurePublicProfileId() async throws -> String {
        var descriptor = FetchDescriptor<UserProfileEntity>()
        descriptor.fetchLimit = 1
        guard let e = try modelContext.fetch(descriptor).first else {
            throw CosCardError.profileMissing
        }
        if let existing = e.publicProfileId, !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        e.publicProfileId = newId
        e.updatedAt = .now
        try modelContext.save()
        return newId
    }

    func upsertProfile(_ draft: ProfileDraft) async throws -> ProfileSummary {
        var descriptor = FetchDescriptor<UserProfileEntity>()
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor).first
        let now = Date()
        let resolvedPrimarySNS = resolvePrimarySNS(from: draft)
        if let e = existing {
            let shouldSnapshotBusinessCard = shouldInsertBusinessCardSnapshot(
                oldImageData: e.businessCardImageData,
                newImageData: draft.businessCardImageData
            )
            e.displayName = draft.displayName
            e.cosplayCharacterName = draft.cosplayCharacterName
            e.bio = draft.bio
            e.primarySNSLabel = resolvedPrimarySNS.label
            e.primarySNSURL = resolvedPrimarySNS.url
            e.twitterURL = draft.twitterURL
            e.instagramURL = draft.instagramURL
            e.tiktokURL = draft.tiktokURL
            e.iconThumbnailData = draft.iconThumbnailData
            e.businessCardImageData = draft.businessCardImageData
            e.profileVersion += 1
            e.updatedAt = now
            if shouldSnapshotBusinessCard {
                insertBusinessCardSnapshotIfNeeded(from: draft, createdAt: now)
            }
            try modelContext.save()
            return map(e)
        }
        let e = UserProfileEntity(
            displayName: draft.displayName,
            cosplayCharacterName: draft.cosplayCharacterName,
            bio: draft.bio,
            primarySNSLabel: resolvedPrimarySNS.label,
            primarySNSURL: resolvedPrimarySNS.url,
            twitterURL: draft.twitterURL,
            instagramURL: draft.instagramURL,
            tiktokURL: draft.tiktokURL,
            iconThumbnailData: draft.iconThumbnailData,
            businessCardImageData: draft.businessCardImageData,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(e)
        insertBusinessCardSnapshotIfNeeded(from: draft, createdAt: now)
        try modelContext.save()
        return map(e)
    }

    func listBusinessCardHistory(newestFirst: Bool = true) async throws -> [BusinessCardHistoryItem] {
        var descriptor = FetchDescriptor<BusinessCardHistoryEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: newestFirst ? .reverse : .forward)]
        )
        descriptor.fetchLimit = 100
        return try modelContext.fetch(descriptor).map(map)
    }

    func saveBusinessCardSnapshot(cosplayCharacterName: String?, imageData: Data) async throws -> BusinessCardHistoryItem {
        let entity = BusinessCardHistoryEntity(
            cosplayCharacterName: cosplayCharacterName,
            businessCardImageData: imageData,
            createdAt: Date()
        )
        modelContext.insert(entity)
        try modelContext.save()
        return map(entity)
    }

    private func map(_ e: UserProfileEntity) -> ProfileSummary {
        ProfileSummary(
            id: e.id,
            displayName: e.displayName,
            cosplayCharacterName: e.cosplayCharacterName,
            bio: e.bio,
            primarySNSLabel: e.primarySNSLabel,
            primarySNSURL: e.primarySNSURL,
            twitterURL: e.twitterURL,
            instagramURL: e.instagramURL,
            tiktokURL: e.tiktokURL,
            iconThumbnailData: e.iconThumbnailData,
            businessCardImageData: e.businessCardImageData,
            profileVersion: e.profileVersion,
            publicProfileId: e.publicProfileId,
            updatedAt: e.updatedAt
        )
    }

    private func map(_ e: BusinessCardHistoryEntity) -> BusinessCardHistoryItem {
        BusinessCardHistoryItem(
            id: e.id,
            cosplayCharacterName: e.cosplayCharacterName,
            businessCardImageData: e.businessCardImageData,
            createdAt: e.createdAt
        )
    }

    private func insertBusinessCardSnapshotIfNeeded(from draft: ProfileDraft, createdAt: Date) {
        guard let imageData = draft.businessCardImageData else { return }
        let snapshot = BusinessCardHistoryEntity(
            cosplayCharacterName: draft.cosplayCharacterName,
            businessCardImageData: imageData,
            createdAt: createdAt
        )
        modelContext.insert(snapshot)
    }

    private func shouldInsertBusinessCardSnapshot(oldImageData: Data?, newImageData: Data?) -> Bool {
        guard let newImageData else { return false }
        return oldImageData != newImageData
    }

    private func resolvePrimarySNS(from draft: ProfileDraft) -> (label: String?, url: String?) {
        let twitter = draft.twitterURL?.trimmedCoscard() ?? ""
        if !twitter.isEmpty {
            return ("X", twitter)
        }

        let instagram = draft.instagramURL?.trimmedCoscard() ?? ""
        if !instagram.isEmpty {
            return ("Instagram", instagram)
        }

        let tiktok = draft.tiktokURL?.trimmedCoscard() ?? ""
        if !tiktok.isEmpty {
            return ("TikTok", tiktok)
        }

        let label = draft.primarySNSLabel?.trimmedCoscard()
        let url = draft.primarySNSURL?.trimmedCoscard()
        let resolvedLabel = (label?.isEmpty == false) ? label : nil
        let resolvedURL = (url?.isEmpty == false) ? url : nil
        return (resolvedLabel, resolvedURL)
    }
}
