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

    func upsertProfile(_ draft: ProfileDraft) async throws -> ProfileSummary {
        var descriptor = FetchDescriptor<UserProfileEntity>()
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor).first
        let now = Date()
        if let e = existing {
            e.displayName = draft.displayName
            e.displayNameReading = draft.displayNameReading
            e.bio = draft.bio
            e.primarySNSLabel = draft.primarySNSLabel
            e.primarySNSURL = draft.primarySNSURL
            e.iconThumbnailData = draft.iconThumbnailData
            e.profileVersion += 1
            e.updatedAt = now
            try modelContext.save()
            return map(e)
        }
        let e = UserProfileEntity(
            displayName: draft.displayName,
            displayNameReading: draft.displayNameReading,
            bio: draft.bio,
            primarySNSLabel: draft.primarySNSLabel,
            primarySNSURL: draft.primarySNSURL,
            iconThumbnailData: draft.iconThumbnailData,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(e)
        try modelContext.save()
        return map(e)
    }

    private func map(_ e: UserProfileEntity) -> ProfileSummary {
        ProfileSummary(
            id: e.id,
            displayName: e.displayName,
            displayNameReading: e.displayNameReading,
            bio: e.bio,
            primarySNSLabel: e.primarySNSLabel,
            primarySNSURL: e.primarySNSURL,
            iconThumbnailData: e.iconThumbnailData,
            profileVersion: e.profileVersion,
            updatedAt: e.updatedAt
        )
    }
}
