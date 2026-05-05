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

    func upsertPeerFromBusinessCard(
        draft: BusinessCardImportDraft,
        mergePeerId: UUID?
    ) async throws -> UUID {
        let now = Date()
        let displayName = draft.displayName.trimmedCoscard()
        let localPeerKey = Self.businessCardLocalPeerKey(
            displayName: displayName,
            links: draft.links,
            imageData: draft.imageData
        )
        let twitterURL = Self.linkValue(from: draft.links, platform: .x)
        let instagramURL = Self.linkValue(from: draft.links, platform: .instagram)
        let tiktokURL = Self.linkValue(from: draft.links, platform: .tiktok)
        let primaryLink = Self.primaryLink(from: draft.links)
        let mergeEntity: PeerContactEntity?
        if let mergePeerId {
            mergeEntity = try fetchEntity(id: mergePeerId)
        } else {
            mergeEntity = nil
        }
        let entity: PeerContactEntity?
        if let mergeEntity {
            entity = mergeEntity
        } else {
            entity = try fetchEntity(localPeerKey: localPeerKey, publicProfileId: nil)
        }

        let peerId: UUID
        if let e = entity {
            if e.publicProfileId == nil {
                e.localPeerKey = localPeerKey
            }
            e.latestDisplayName = displayName
            e.latestCosplayCharacterName = draft.cosplayCharacterName
            e.latestSNSLabel = primaryLink?.platform.displayName
            e.latestSNSURL = Self.storedValue(from: primaryLink)
            e.latestTwitterURL = twitterURL ?? e.latestTwitterURL
            e.latestInstagramURL = instagramURL ?? e.latestInstagramURL
            e.latestTiktokURL = tiktokURL ?? e.latestTiktokURL
            e.latestBusinessCardImageData = draft.imageData
            e.lastMetAt = now
            if let memo = draft.memo { e.memo = memo }
            if let eventTag = draft.eventTag { e.lastEventTag = eventTag }
            e.updatedAt = now
            peerId = e.id
        } else {
            let e = PeerContactEntity(
                localPeerKey: localPeerKey,
                latestDisplayName: displayName,
                latestCosplayCharacterName: draft.cosplayCharacterName,
                latestSNSLabel: primaryLink?.platform.displayName,
                latestSNSURL: Self.storedValue(from: primaryLink),
                latestTwitterURL: twitterURL,
                latestInstagramURL: instagramURL,
                latestTiktokURL: tiktokURL,
                latestBusinessCardImageData: draft.imageData,
                firstMetAt: draft.capturedAt,
                lastMetAt: now,
                lastEventTag: draft.eventTag,
                memo: draft.memo,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(e)
            peerId = e.id
        }

        modelContext.insert(LightweightProfileSnapshotEntity(
            ownerType: "business_card",
            ownerReferenceId: peerId,
            displayName: displayName,
            cosplayCharacterName: draft.cosplayCharacterName,
            bio: nil,
            primarySNSLabel: primaryLink?.platform.displayName,
            primarySNSURL: Self.storedValue(from: primaryLink),
            twitterURL: twitterURL,
            instagramURL: instagramURL,
            tiktokURL: tiktokURL,
            iconThumbnailData: nil,
            businessCardImageData: draft.imageData,
            profileVersion: 1
        ))

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

    private static func businessCardLocalPeerKey(
        displayName: String,
        links: [ContactLinkDraft],
        imageData: Data
    ) -> String {
        let strongestIdentity = links
            .compactMap { $0.normalizedURL?.lowercased() ?? $0.usernameCandidate?.lowercased() }
            .first
        let fallbackImageHash = String(Checksum.sha256Hex(of: imageData).prefix(16))
        let parts = [
            "business-card",
            displayName.normalizedForPeerKey(),
            strongestIdentity ?? fallbackImageHash,
        ]
        return String(Checksum.sha256Hex(of: parts.joined(separator: "|")).prefix(40))
    }

    private static func linkValue(from links: [ContactLinkDraft], platform: ContactLinkPlatform) -> String? {
        guard let link = links.first(where: { $0.platform == platform }) else { return nil }
        return storedValue(from: link)
    }

    private static func primaryLink(from links: [ContactLinkDraft]) -> ContactLinkDraft? {
        links.first { link in
            switch link.platform {
            case .x, .instagram, .tiktok:
                return true
            case .litlink, .linktree, .website:
                return true
            case .email, .phone, .other:
                return false
            }
        }
    }

    private static func storedValue(from link: ContactLinkDraft?) -> String? {
        guard let link else { return nil }
        let value = link.usernameCandidate ?? link.normalizedURL ?? link.originalValue
        let trimmed = value.trimmedCoscard()
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
