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

        let profile = LightweightProfile(
            ephemeralToken: "tok-dup",
            publicProfileId: "pid-2",
            displayName: "重複テスト",
            profileVersion: 1
        )

        let uc = SaveExchangeResultUseCase(
            peerRepository: peerRepo,
            exchangeSessionRepository: sessionRepo,
            tokenRepository: tokenRepo
        )

        try await uc.execute(
            sessionId: sessionId1,
            peerProfile: profile,
            memo: nil,
            eventTag: nil,
            confirmationCode: nil
        )

        var caught: CosCardError?
        do {
            try await uc.execute(
                sessionId: sessionId2,
                peerProfile: profile,
                memo: nil,
                eventTag: nil,
                confirmationCode: nil
            )
        } catch let e as CosCardError {
            caught = e
        }
        XCTAssertEqual(caught, .tokenAlreadyUsed)
    }

    func testExecute_upsertsSamePeer() async throws {
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

        try await uc.execute(sessionId: sessionId1, peerProfile: profile1, memo: nil, eventTag: nil, confirmationCode: nil)
        try await uc.execute(sessionId: sessionId2, peerProfile: profile2, memo: "新メモ", eventTag: nil, confirmationCode: nil)

        let peers = try await peerRepo.listPeers(newestFirst: true)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "更新後名前")
        XCTAssertEqual(peers.first?.memo, "新メモ")
    }
}
