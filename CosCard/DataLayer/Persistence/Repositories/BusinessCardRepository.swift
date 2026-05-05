import Foundation
import SwiftData

@MainActor
final class BusinessCardRepository: BusinessCardRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveImport(
        draft: BusinessCardImportDraft,
        linkedPeerContactId: UUID
    ) async throws -> UUID {
        let now = Date()
        let capture = BusinessCardCaptureEntity(
            imageData: draft.imageData,
            thumbnailData: draft.thumbnailData,
            capturedAt: draft.capturedAt,
            sourceType: draft.captureSourceType.rawValue,
            ocrRawText: draft.ocrRawText,
            qrRawValue: draft.qrRawValue,
            linkedPeerContactId: linkedPeerContactId,
            createdAt: now,
            updatedAt: now
        )
        modelContext.insert(capture)

        for link in ContactLinkNormalizer.unique(draft.links) {
            modelContext.insert(ContactLinkEntity(
                peerContactId: linkedPeerContactId,
                captureId: capture.id,
                platform: link.platform.rawValue,
                originalValue: link.originalValue,
                normalizedURL: link.normalizedURL,
                usernameCandidate: link.usernameCandidate,
                sourceType: link.sourceType.rawValue,
                createdAt: now,
                updatedAt: now
            ))
        }

        for result in draft.extractionResults {
            modelContext.insert(ExtractionResultEntity(
                captureId: capture.id,
                kind: result.kind,
                originalValue: result.originalValue,
                normalizedValue: result.normalizedValue,
                confidence: result.confidence,
                sourceType: result.sourceType.rawValue,
                isAccepted: result.isAccepted,
                createdAt: now
            ))
        }

        try modelContext.save()
        return capture.id
    }

    func listLinks(peerContactId: UUID) async throws -> [ContactLinkSummary] {
        let descriptor = FetchDescriptor<ContactLinkEntity>(
            predicate: #Predicate { $0.peerContactId == peerContactId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map(map)
    }

    func findMergeCandidates(
        displayName: String?,
        links: [ContactLinkDraft],
        limit: Int
    ) async throws -> [BusinessCardMergeCandidate] {
        let linkKeys = comparisonKeys(for: links)
        let displayNameKey = displayName?.normalizedForPeerKey() ?? ""

        let peerDescriptor = FetchDescriptor<PeerContactEntity>(
            predicate: #Predicate { $0.isHidden == false },
            sortBy: [SortDescriptor(\.lastMetAt, order: .reverse)]
        )
        let peers = try modelContext.fetch(peerDescriptor)

        let storedLinks = try modelContext.fetch(FetchDescriptor<ContactLinkEntity>())
        var storedLinksByPeer: [UUID: [ContactLinkEntity]] = [:]
        for link in storedLinks {
            guard let peerId = link.peerContactId else { continue }
            storedLinksByPeer[peerId, default: []].append(link)
        }

        let candidates = peers.compactMap { peer -> BusinessCardMergeCandidate? in
            var reasons: [String] = []
            let peerNameKey = peer.latestDisplayName.normalizedForPeerKey()
            if !displayNameKey.isEmpty, displayNameKey == peerNameKey {
                reasons.append("名前が一致")
            } else if !displayNameKey.isEmpty,
                      (displayNameKey.contains(peerNameKey) || peerNameKey.contains(displayNameKey)),
                      min(displayNameKey.count, peerNameKey.count) >= 3
            {
                reasons.append("名前が近い")
            }

            let peerLinkKeys = comparisonKeys(for: peerLinks(from: peer))
                .union(comparisonKeys(for: storedLinksByPeer[peer.id] ?? []))
            if !linkKeys.isDisjoint(with: peerLinkKeys) {
                reasons.append("リンクが一致")
            }

            guard !reasons.isEmpty else { return nil }
            return BusinessCardMergeCandidate(
                peerId: peer.id,
                displayName: peer.latestDisplayName,
                memo: peer.memo,
                reasons: reasons
            )
        }

        return Array(candidates.prefix(max(limit, 0)))
    }

    private func map(_ e: ContactLinkEntity) -> ContactLinkSummary {
        ContactLinkSummary(
            id: e.id,
            peerContactId: e.peerContactId,
            captureId: e.captureId,
            platform: ContactLinkPlatform(rawValue: e.platform) ?? .other,
            originalValue: e.originalValue,
            normalizedURL: e.normalizedURL,
            usernameCandidate: e.usernameCandidate,
            sourceType: ContactLinkSourceType(rawValue: e.sourceType) ?? .manual,
            createdAt: e.createdAt
        )
    }

    private func peerLinks(from peer: PeerContactEntity) -> [ContactLinkDraft] {
        [
            ContactLinkNormalizer.normalize(peer.latestTwitterURL ?? "", hintedPlatform: .x, sourceType: .appExchange),
            ContactLinkNormalizer.normalize(peer.latestInstagramURL ?? "", hintedPlatform: .instagram, sourceType: .appExchange),
            ContactLinkNormalizer.normalize(peer.latestTiktokURL ?? "", hintedPlatform: .tiktok, sourceType: .appExchange),
            ContactLinkNormalizer.normalize(peer.latestSNSURL ?? "", sourceType: .appExchange),
        ].compactMap { $0 }
    }

    private func comparisonKeys(for links: [ContactLinkDraft]) -> Set<String> {
        Set(links.flatMap { link in
            [
                link.normalizedURL?.lowercased(),
                link.usernameCandidate.map { "\(link.platform.rawValue):\($0.lowercased())" },
            ].compactMap { $0 }
        })
    }

    private func comparisonKeys(for links: [ContactLinkEntity]) -> Set<String> {
        Set(links.flatMap { link in
            [
                link.normalizedURL?.lowercased(),
                link.usernameCandidate.map { "\(link.platform):\($0.lowercased())" },
            ].compactMap { $0 }
        })
    }
}
