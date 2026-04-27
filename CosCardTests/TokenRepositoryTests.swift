import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class TokenRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: TokenRepository!

    override func setUp() async throws {
        container = try ModelContainerProvider.makePreviewContainer()
        context = ModelContext(container)
        repo = TokenRepository(modelContext: context)
    }

    func testRecordIncomingTokenIfNew_rejectsDuplicate() async throws {
        let sid = UUID()
        let first = try await repo.recordIncomingTokenIfNew(value: "unique-tok", sessionId: sid, peerContactId: nil)
        XCTAssertTrue(first)
        let second = try await repo.recordIncomingTokenIfNew(value: "unique-tok", sessionId: sid, peerContactId: nil)
        XCTAssertFalse(second)
    }

    func testIsTokenAlreadySeen_afterOutgoingIssue() async throws {
        let tok = try await repo.issueOutgoingToken(sessionId: UUID())
        let seen = try await repo.isTokenAlreadySeen(tok)
        XCTAssertTrue(seen)
    }

    func testConsumeTokenIfValid_rejectsExpired() async throws {
        let tok = try await repo.issueOutgoingToken(sessionId: nil)
        let search = tok
        var desc = FetchDescriptor<ExchangeTokenEntity>(predicate: #Predicate { $0.tokenValue == search })
        desc.fetchLimit = 1
        let row = try XCTUnwrap(context.fetch(desc).first)
        row.expiresAt = Date().addingTimeInterval(-60)
        try context.save()

        let ok = try await repo.consumeTokenIfValid(tok)
        XCTAssertFalse(ok)
    }

    func testPruneExpired_removesRows() async throws {
        _ = try await repo.issueOutgoingToken(sessionId: nil)
        let allBefore = try context.fetch(FetchDescriptor<ExchangeTokenEntity>())
        XCTAssertEqual(allBefore.count, 1)

        for e in allBefore {
            e.expiresAt = Date().addingTimeInterval(-120)
        }
        try context.save()

        try await repo.pruneExpired()
        let allAfter = try context.fetch(FetchDescriptor<ExchangeTokenEntity>())
        XCTAssertTrue(allAfter.isEmpty)
    }
}
