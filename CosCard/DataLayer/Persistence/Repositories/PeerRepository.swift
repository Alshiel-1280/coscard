import Foundation
import SwiftData

@MainActor
final class PeerRepository: PeerRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func listPeers(newestFirst: Bool) async throws -> [PeerSummary] {
        let descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.isHidden == false },
            sortBy: [SortDescriptor(\.lastMetAt, order: newestFirst ? .reverse : .forward)]
        )
        let list = try modelContext.fetch(descriptor)
        return list.map(mapSummary)
    }

    func listBlockedPeers(newestFirst: Bool) async throws -> [PeerSummary] {
        let descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.isBlocked == true },
            sortBy: [SortDescriptor(\.lastMetAt, order: newestFirst ? .reverse : .forward)]
        )
        let list = try modelContext.fetch(descriptor)
        return list.map(mapSummary)
    }

    func fetchPeer(id: UUID) async throws -> PeerDetail? {
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let e = try modelContext.fetch(descriptor).first else { return nil }
        let sessions = e.sessions.sorted { $0.startedAt > $1.startedAt }.map { se in
            PeerExchangeSessionRow(
                id: se.id,
                startedAt: se.startedAt,
                endedAt: se.endedAt,
                state: se.state,
                result: se.result,
                failureReason: se.failureReason,
                transport: se.transport
            )
        }
        return PeerDetail(
            summary: mapSummary(e),
            latestCosplayCharacterName: e.latestCosplayCharacterName,
            latestSNSLabel: e.latestSNSLabel,
            latestSNSURL: e.latestSNSURL,
            latestTwitterURL: e.latestTwitterURL,
            latestInstagramURL: e.latestInstagramURL,
            latestTiktokURL: e.latestTiktokURL,
            latestIconThumbnailData: e.latestIconThumbnailData,
            latestBusinessCardImageData: e.latestBusinessCardImageData,
            firstMetAt: e.firstMetAt,
            lastMetAt: e.lastMetAt,
            lastEventTag: e.lastEventTag,
            exchangeSessions: sessions
        )
    }

    func updateMemo(peerId: UUID, memo: String?) async throws {
        guard let e = try fetchEntity(id: peerId) else { return }
        e.memo = memo
        e.updatedAt = .now
        try modelContext.save()
    }

    func setBlocked(peerId: UUID, blocked: Bool) async throws {
        guard let e = try fetchEntity(id: peerId) else { return }
        e.isBlocked = blocked
        e.updatedAt = .now
        try modelContext.save()
    }

    func setHidden(peerId: UUID, hidden: Bool) async throws {
        guard let e = try fetchEntity(id: peerId) else { return }
        e.isHidden = hidden
        e.updatedAt = .now
        try modelContext.save()
    }

    func isBlockedLocalPeerKey(_ key: String) async throws -> Bool {
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.localPeerKey == key && $0.isBlocked == true }
        )
        descriptor.fetchLimit = 1
        return try !modelContext.fetch(descriptor).isEmpty
    }

    func blockedNormalizedDisplayNames() async throws -> Set<String> {
        let descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.isBlocked == true }
        )
        let list = try modelContext.fetch(descriptor)
        return Set(list.map { $0.latestDisplayName.normalizedForPeerKey() })
    }

    func blockedPublicProfileIds() async throws -> Set<String> {
        let descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.isBlocked == true }
        )
        let list = try modelContext.fetch(descriptor)
        return Set(list.compactMap { Self.normalizedPublicProfileId($0.publicProfileId) })
    }

    func hasPeer(withLocalPeerKey key: String) async throws -> Bool {
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.localPeerKey == key }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    func hasPeer(withPublicProfileId publicProfileId: String) async throws -> Bool {
        guard let normalized = Self.normalizedPublicProfileId(publicProfileId) else { return false }
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.publicProfileId == normalized }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    func upsertPeerFromExchange(
        localPeerKey: String,
        received: LightweightProfile,
        memo: String?,
        eventTag: String?
    ) async throws -> UUID {
        let now = Date()
        let publicProfileId = Self.normalizedPublicProfileId(received.publicProfileId)
        let existing = try fetchEntity(localPeerKey: localPeerKey, publicProfileId: publicProfileId)
        let twitterURL = Self.socialURL(from: received, service: .x)
        let instagramURL = Self.socialURL(from: received, service: .instagram)
        let tiktokURL = Self.socialURL(from: received, service: .tiktok)
        let peerId: UUID
        if let e = existing {
            e.localPeerKey = localPeerKey
            if let publicProfileId {
                e.publicProfileId = publicProfileId
            }
            e.latestDisplayName = received.displayName
            e.latestCosplayCharacterName = received.cosplayCharacterName
            e.latestBio = received.bioShort
            e.latestSNSLabel = received.primarySNSLabel
            e.latestSNSURL = received.primarySNSURL
            e.latestTwitterURL = twitterURL
            e.latestInstagramURL = instagramURL
            e.latestTiktokURL = tiktokURL
            e.latestIconThumbnailData = received.iconThumbnailData
            e.latestBusinessCardImageData = received.businessCardImageData
            e.lastMetAt = now
            e.lastReceivedProfileVersion = received.profileVersion
            if let memo { e.memo = memo }
            if let eventTag { e.lastEventTag = eventTag }
            e.updatedAt = now
            peerId = e.id
        } else {
            let e = PeerContactEntity(
                localPeerKey: localPeerKey,
                publicProfileId: publicProfileId,
                latestDisplayName: received.displayName,
                latestCosplayCharacterName: received.cosplayCharacterName,
                latestBio: received.bioShort,
                latestSNSLabel: received.primarySNSLabel,
                latestSNSURL: received.primarySNSURL,
                latestTwitterURL: twitterURL,
                latestInstagramURL: instagramURL,
                latestTiktokURL: tiktokURL,
                latestIconThumbnailData: received.iconThumbnailData,
                latestBusinessCardImageData: received.businessCardImageData,
                firstMetAt: now,
                lastMetAt: now,
                lastEventTag: eventTag,
                memo: memo,
                lastReceivedProfileVersion: received.profileVersion
            )
            modelContext.insert(e)
            peerId = e.id
        }
        let snap = LightweightProfileSnapshotEntity(
            ownerType: "peer",
            ownerReferenceId: peerId,
            displayName: received.displayName,
            cosplayCharacterName: received.cosplayCharacterName,
            bio: received.bioShort,
            primarySNSLabel: received.primarySNSLabel,
            primarySNSURL: received.primarySNSURL,
            twitterURL: twitterURL,
            instagramURL: instagramURL,
            tiktokURL: tiktokURL,
            iconThumbnailData: received.iconThumbnailData,
            businessCardImageData: received.businessCardImageData,
            profileVersion: received.profileVersion
        )
        modelContext.insert(snap)
        try modelContext.save()
        return peerId
    }

    private func fetchEntity(id: UUID) throws -> PeerContactEntity? {
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func fetchEntity(localPeerKey: String, publicProfileId: String?) throws -> PeerContactEntity? {
        if let publicProfileId {
            var publicIdDescriptor = FetchDescriptor<PeerContactEntity>(
                predicate: #Predicate { $0.publicProfileId == publicProfileId }
            )
            publicIdDescriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(publicIdDescriptor).first {
                return existing
            }
        }
        var keyDescriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.localPeerKey == localPeerKey }
        )
        keyDescriptor.fetchLimit = 1
        return try modelContext.fetch(keyDescriptor).first
    }

    private static func normalizedPublicProfileId(_ value: String?) -> String? {
        let trimmed = value?.trimmedCoscard() ?? ""
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private static func socialURL(from profile: LightweightProfile, service: SNSUserID.Service) -> String? {
        let explicitValue: String?
        switch service {
        case .x:
            explicitValue = profile.twitterURL
        case .instagram:
            explicitValue = profile.instagramURL
        case .tiktok:
            explicitValue = profile.tiktokURL
        }
        if let value = normalizedSocialValue(explicitValue) {
            return value
        }
        guard SNSUserID.service(label: profile.primarySNSLabel, rawValue: profile.primarySNSURL) == service else {
            return nil
        }
        return normalizedSocialValue(profile.primarySNSURL)
    }

    private static func normalizedSocialValue(_ value: String?) -> String? {
        let trimmed = value?.trimmedCoscard() ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func mapSummary(_ e: PeerContactEntity) -> PeerSummary {
        PeerSummary(
            id: e.id,
            localPeerKey: e.localPeerKey,
            publicProfileId: e.publicProfileId,
            latestDisplayName: e.latestDisplayName,
            latestBio: e.latestBio,
            memo: e.memo,
            lastMetAt: e.lastMetAt,
            isBlocked: e.isBlocked,
            isHidden: e.isHidden
        )
    }
}
