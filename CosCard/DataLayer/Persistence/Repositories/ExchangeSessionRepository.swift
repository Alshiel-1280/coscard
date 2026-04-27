import Foundation
import SwiftData

@MainActor
final class ExchangeSessionRepository: ExchangeSessionRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func createSession(id: UUID, transport: String, peerPreviewName: String?, peerPreviewIcon: Data?) async throws {
        let e = ExchangeSessionEntity(
            id: id,
            startedAt: .now,
            state: ExchangeState.idle.rawValue,
            transport: transport,
            peerPreviewName: peerPreviewName,
            peerPreviewIconData: peerPreviewIcon
        )
        modelContext.insert(e)
        try modelContext.save()
    }

    func ensureSession(id: UUID, transport: String, peerPreviewName: String?, peerPreviewIcon: Data?) async throws {
        if try fetch(id: id) != nil { return }
        try await createSession(id: id, transport: transport, peerPreviewName: peerPreviewName, peerPreviewIcon: peerPreviewIcon)
    }

    func updateSessionState(id: UUID, state: ExchangeState) async throws {
        guard let e = try fetch(id: id) else { return }
        e.state = state.rawValue
        try modelContext.save()
    }

    func completeSession(
        id: UUID,
        result: String,
        failureReason: ExchangeFailureReason?,
        confirmationCode: String?,
        eventTag: String?,
        peerContactId: UUID?
    ) async throws {
        guard let e = try fetch(id: id) else { return }
        e.endedAt = .now
        e.result = result
        e.failureReason = failureReason?.rawValue
        e.confirmationCode = confirmationCode
        e.eventTag = eventTag
        e.state = ExchangeState.succeeded.rawValue
        if let pid = peerContactId {
            var descriptor = FetchDescriptor<PeerContactEntity>(
                predicate: #Predicate { $0.id == pid }
            )
            descriptor.fetchLimit = 1
            if let peer = try modelContext.fetch(descriptor).first {
                e.peerContact = peer
            }
        }
        try modelContext.save()
    }

    func failSession(id: UUID, state: ExchangeState, failureReason: ExchangeFailureReason?) async throws {
        guard let e = try fetch(id: id) else { return }
        if e.result == "success" { return }
        e.endedAt = .now
        e.result = "failure"
        e.failureReason = failureReason?.rawValue
        e.state = state.rawValue
        try modelContext.save()
    }

    private func fetch(id: UUID) throws -> ExchangeSessionEntity? {
        var descriptor = FetchDescriptor<ExchangeSessionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
