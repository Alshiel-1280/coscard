import Foundation

@MainActor
protocol BusinessCardRepositoryProtocol: AnyObject {
    func saveImport(
        draft: BusinessCardImportDraft,
        linkedPeerContactId: UUID
    ) async throws -> UUID

    func listLinks(peerContactId: UUID) async throws -> [ContactLinkSummary]

    func findMergeCandidates(
        displayName: String?,
        links: [ContactLinkDraft],
        limit: Int
    ) async throws -> [BusinessCardMergeCandidate]
}
