import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class SaveExchangeResultUseCaseTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var peerRepo: PeerRepository!
    private var sessionRepo: ExchangeSessionRepository!
    private var tokenRepo: TokenRepository!

    override func setUp() async throws {
        container = try ModelContainerProvider.makePreviewContainer()
        context = ModelContext(container)
        peerRepo = PeerRepository(modelContext: context)
        sessionRepo = ExchangeSessionRepository(modelContext: context)
        tokenRepo = TokenRepository(modelContext: context)
    }

    func testExecute_savesNewPeerAndCompletesSession() async throws {
        let sessionId = UUID()
        try await sessionRepo.createSession(id: sessionId, transport: "mpc", peerPreviewName: "テスト", peerPreviewIcon: nil)

        let profile = LightweightProfile(
            ephemeralToken: "tok-save-test",
            publicProfileId: "pid-1",
            displayName: "テストユーザー",
            bioShort: "テストbio",
            profileVersion: 1
        )

        let uc = SaveExchangeResultUseCase(
            peerRepository: peerRepo,
            exchangeSessionRepository: sessionRepo,
            tokenRepository: tokenRepo
        )

        try await uc.execute(
            sessionId: sessionId,
            peerProfile: profile,
            memo: "テストメモ",
            eventTag: "イベント1",
            confirmationCode: "1234"
        )

        let peers = try await peerRepo.listPeers(newestFirst: true)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "テストユーザー")
        XCTAssertEqual(peers.first?.memo, "テストメモ")
    }

    func testExecute_rejectsDuplicateToken() async throws {
        let sessionId1 = UUID()
        let sessionId2 = UUID()
        try await sessionRepo.createSession(id: sessionId1, transport: "mpc", peerPreviewName: "A", peerPreviewIcon: nil)
        try await sessionRepo.createSession(id: sessionId2, transport: "mpc", peerPreviewName: "A", peerPreviewIcon: nil)

        let originalProfile = LightweightProfile(
            ephemeralToken: "tok-dup",
            publicProfileId: "pid-2",
            displayName: "重複テスト",
            profileVersion: 1
        )
        let replayProfile = LightweightProfile(
            ephemeralToken: "tok-dup",
            publicProfileId: "pid-2",
            displayName: "リプレイ更新",
            bioShort: "保存されてはいけないbio",
            profileVersion: 2
        )

        let uc = SaveExchangeResultUseCase(
            peerRepository: peerRepo,
            exchangeSessionRepository: sessionRepo,
            tokenRepository: tokenRepo
        )

        try await uc.execute(
            sessionId: sessionId1,
            peerProfile: originalProfile,
            memo: "元メモ",
            eventTag: "元タグ",
            confirmationCode: nil
        )

        var caught: CosCardError?
        do {
            try await uc.execute(
                sessionId: sessionId2,
                peerProfile: replayProfile,
                memo: "汚染メモ",
                eventTag: "汚染タグ",
                confirmationCode: nil
            )
        } catch let e as CosCardError {
            caught = e
        }
        XCTAssertEqual(caught, .tokenAlreadyUsed)
        let peers = try await peerRepo.listPeers(newestFirst: true)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "重複テスト")
        XCTAssertNil(peers.first?.latestBio)
        XCTAssertEqual(peers.first?.memo, "元メモ")
    }

    func testDuplicateCheck_requiresUserChoiceWhenPeerExists() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-check",
            publicProfileId: "pid-check",
            displayName: "確認ユーザー",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        _ = try await peerRepo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: nil,
            eventTag: nil
        )

        let check = try await ResolveDuplicateExchangeUseCase().check(
            peerProfile: profile,
            peerRepository: peerRepo
        )

        XCTAssertEqual(check.localPeerKey, key)
        XCTAssertTrue(check.isDuplicate)
        XCTAssertTrue(check.requiresUserChoice)
    }

    func testExecute_updatesDuplicatePeerWhenRequested() async throws {
        let sessionId1 = UUID()
        let sessionId2 = UUID()
        try await sessionRepo.createSession(id: sessionId1, transport: "mpc", peerPreviewName: "B", peerPreviewIcon: nil)
        try await sessionRepo.createSession(id: sessionId2, transport: "mpc", peerPreviewName: "B", peerPreviewIcon: nil)

        let profile1 = LightweightProfile(
            ephemeralToken: "tok-up1",
            publicProfileId: "pid-same",
            displayName: "初回名前",
            profileVersion: 1
        )
        let profile2 = LightweightProfile(
            ephemeralToken: "tok-up2",
            publicProfileId: "pid-same",
            displayName: "更新後名前",
            profileVersion: 1
        )

        let uc = SaveExchangeResultUseCase(
            peerRepository: peerRepo,
            exchangeSessionRepository: sessionRepo,
            tokenRepository: tokenRepo
        )

        let firstResult = try await uc.execute(
            sessionId: sessionId1,
            peerProfile: profile1,
            memo: nil,
            eventTag: nil,
            confirmationCode: nil
        )
        let secondResult = try await uc.execute(
            sessionId: sessionId2,
            peerProfile: profile2,
            memo: "新メモ",
            eventTag: nil,
            confirmationCode: nil,
            duplicateChoice: .updateExisting
        )

        let peers = try await peerRepo.listPeers(newestFirst: true)
        XCTAssertFalse(firstResult.duplicateCheck.isDuplicate)
        XCTAssertTrue(secondResult.duplicateCheck.isDuplicate)
        XCTAssertTrue(secondResult.didSavePeer)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "更新後名前")
        XCTAssertEqual(peers.first?.memo, "新メモ")
    }

    func testExecute_skipsDuplicatePeerWhenRequested() async throws {
        let sessionId1 = UUID()
        let sessionId2 = UUID()
        try await sessionRepo.createSession(id: sessionId1, transport: "qr", peerPreviewName: "C", peerPreviewIcon: nil)
        try await sessionRepo.createSession(id: sessionId2, transport: "qr", peerPreviewName: "C", peerPreviewIcon: nil)

        let profile1 = LightweightProfile(
            ephemeralToken: "tok-skip1",
            publicProfileId: "pid-skip",
            displayName: "初回名前",
            profileVersion: 1
        )
        let profile2 = LightweightProfile(
            ephemeralToken: "tok-skip2",
            publicProfileId: "pid-skip",
            displayName: "スキップ後名前",
            profileVersion: 1
        )

        let uc = SaveExchangeResultUseCase(
            peerRepository: peerRepo,
            exchangeSessionRepository: sessionRepo,
            tokenRepository: tokenRepo
        )

        try await uc.execute(
            sessionId: sessionId1,
            peerProfile: profile1,
            memo: "初回メモ",
            eventTag: "初回タグ",
            confirmationCode: nil
        )
        let skipped = try await uc.execute(
            sessionId: sessionId2,
            peerProfile: profile2,
            memo: "保存しないメモ",
            eventTag: "保存しないタグ",
            confirmationCode: nil,
            duplicateChoice: .skip
        )

        let peers = try await peerRepo.listPeers(newestFirst: true)
        XCTAssertTrue(skipped.duplicateCheck.isDuplicate)
        XCTAssertTrue(skipped.skippedDuplicate)
        XCTAssertNil(skipped.peerContactId)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "初回名前")
        XCTAssertEqual(peers.first?.memo, "初回メモ")
        let skippedTokenSeen = try await tokenRepo.isTokenAlreadySeen("tok-skip2")
        XCTAssertTrue(skippedTokenSeen)

        let sessionSearch = sessionId2
        var descriptor = FetchDescriptor<ExchangeSessionEntity>(
            predicate: #Predicate { $0.id == sessionSearch }
        )
        descriptor.fetchLimit = 1
        let session = try XCTUnwrap(context.fetch(descriptor).first)
        XCTAssertEqual(session.state, ExchangeState.succeeded.rawValue)
        XCTAssertEqual(session.result, "skipped_duplicate")
        XCTAssertNil(session.peerContact)
    }
}
