import Foundation
import Security
import SwiftData

@MainActor
final class TokenRepository: TokenRepositoryProtocol {
    private let modelContext: ModelContext
    private let ttlSeconds: TimeInterval = 180

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func issueOutgoingToken(sessionId: UUID?) async throws -> String {
        var raw = [UInt8](repeating: 0, count: 16)
        _ = raw.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let token = Data(raw).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let now = Date()
        let e = ExchangeTokenEntity(
            tokenValue: token,
            direction: "outgoing",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds),
            linkedSessionId: sessionId
        )
        modelContext.insert(e)
        try modelContext.save()
        return token
    }

    func consumeTokenIfValid(_ value: String) async throws -> Bool {
        var descriptor = FetchDescriptor<ExchangeTokenEntity>(
            predicate: #Predicate { $0.tokenValue == value }
        )
        descriptor.fetchLimit = 1
        guard let e = try modelContext.fetch(descriptor).first else { return false }
        if e.isConsumed { return false }
        if e.expiresAt < Date() { return false }
        e.isConsumed = true
        try modelContext.save()
        return true
    }

    func consumeOutgoingTokenForSession(_ sessionId: UUID) async throws {
        let rows = try modelContext.fetch(FetchDescriptor<ExchangeTokenEntity>())
        guard let e = rows.first(where: { $0.linkedSessionId == sessionId && $0.direction == "outgoing" && !$0.isConsumed }) else { return }
        e.isConsumed = true
        try modelContext.save()
    }

    func recordIncomingToken(value: String, sessionId: UUID, peerContactId: UUID?) async throws {
        let search = value
        var descriptor = FetchDescriptor<ExchangeTokenEntity>(
            predicate: #Predicate { $0.tokenValue == search }
        )
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            existing.linkedSessionId = sessionId
            existing.linkedPeerContactId = peerContactId
            try modelContext.save()
            return
        }
        let now = Date()
        let e = ExchangeTokenEntity(
            tokenValue: value,
            direction: "incoming",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds),
            linkedSessionId: sessionId,
            linkedPeerContactId: peerContactId
        )
        modelContext.insert(e)
        try modelContext.save()
    }

    func isTokenAlreadySeen(_ value: String) async throws -> Bool {
        let search = value
        var descriptor = FetchDescriptor<ExchangeTokenEntity>(
            predicate: #Predicate { $0.tokenValue == search }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first != nil
    }

    func recordIncomingTokenIfNew(value: String, sessionId: UUID, peerContactId: UUID?) async throws -> Bool {
        let search = value
        var descriptor = FetchDescriptor<ExchangeTokenEntity>(
            predicate: #Predicate { $0.tokenValue == search }
        )
        descriptor.fetchLimit = 1
        if try modelContext.fetch(descriptor).first != nil {
            return false
        }
        let now = Date()
        let e = ExchangeTokenEntity(
            tokenValue: value,
            direction: "incoming",
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttlSeconds),
            linkedSessionId: sessionId,
            linkedPeerContactId: peerContactId
        )
        modelContext.insert(e)
        try modelContext.save()
        return true
    }

    func pruneExpired() async throws {
        let now = Date()
        var descriptor = FetchDescriptor<ExchangeTokenEntity>(
            predicate: #Predicate { $0.expiresAt < now }
        )
        let expired = try modelContext.fetch(descriptor)
        for e in expired {
            modelContext.delete(e)
        }
        try modelContext.save()
    }
}
