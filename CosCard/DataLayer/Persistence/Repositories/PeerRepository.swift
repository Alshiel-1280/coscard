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
        var descriptor = FetchDescriptor<PeerContactEntity>(
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
            latestSNSLabel: e.latestSNSLabel,
            latestSNSURL: e.latestSNSURL,
            latestIconThumbnailData: e.latestIconThumbnailData,
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

    func hasPeer(withLocalPeerKey key: String) async throws -> Bool {
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.localPeerKey == key }
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
        var descriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.localPeerKey == localPeerKey }
        )
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor).first
        let peerId: UUID
        if let e = existing {
            e.latestDisplayName = received.displayName
            e.latestBio = received.bioShort
            e.latestSNSLabel = received.primarySNSLabel
            e.latestSNSURL = received.primarySNSURL
            e.latestIconThumbnailData = received.iconThumbnailData
            e.lastMetAt = now
            e.lastReceivedProfileVersion = received.profileVersion
            if let memo { e.memo = memo }
            if let eventTag { e.lastEventTag = eventTag }
            e.updatedAt = now
            peerId = e.id
        } else {
            let e = PeerContactEntity(
                localPeerKey: localPeerKey,
                latestDisplayName: received.displayName,
                latestBio: received.bioShort,
                latestSNSLabel: received.primarySNSLabel,
                latestSNSURL: received.primarySNSURL,
                latestIconThumbnailData: received.iconThumbnailData,
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
            bio: received.bioShort,
            primarySNSLabel: received.primarySNSLabel,
            primarySNSURL: received.primarySNSURL,
            iconThumbnailData: received.iconThumbnailData,
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

    private func mapSummary(_ e: PeerContactEntity) -> PeerSummary {
        PeerSummary(
            id: e.id,
            localPeerKey: e.localPeerKey,
            latestDisplayName: e.latestDisplayName,
            latestBio: e.latestBio,
            memo: e.memo,
            lastMetAt: e.lastMetAt,
            isBlocked: e.isBlocked,
            isHidden: e.isHidden
        )
    }
}
