import SwiftData
import XCTest
@testable import CosCard

@MainActor
final class PeerRepositoryTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var repo: PeerRepository!

    override func setUp() async throws {
        container = try ModelContainerProvider.makePreviewContainer()
        context = ModelContext(container)
        repo = PeerRepository(modelContext: context)
    }

    func testUpsertAndList() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-1",
            publicProfileId: "pid-1",
            displayName: "テストユーザー",
            bioShort: "テストbio",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        _ = try await repo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: "メモ",
            eventTag: "タグ"
        )

        let peers = try await repo.listPeers(newestFirst: true)
        XCTAssertEqual(peers.count, 1)
        XCTAssertEqual(peers.first?.latestDisplayName, "テストユーザー")
        XCTAssertEqual(peers.first?.memo, "メモ")
    }

    func testHiddenPeersNotInList() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-h",
            publicProfileId: "pid-h",
            displayName: "隠しユーザー",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        let peerId = try await repo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: nil,
            eventTag: nil
        )

        try await repo.setHidden(peerId: peerId, hidden: true)

        let peers = try await repo.listPeers(newestFirst: true)
        XCTAssertTrue(peers.isEmpty)
    }

    func testBlockAndUnblock() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-b",
            publicProfileId: "pid-b",
            displayName: "ブロックテスト",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        let peerId = try await repo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: nil,
            eventTag: nil
        )

        try await repo.setBlocked(peerId: peerId, blocked: true)

        let blocked = try await repo.listBlockedPeers(newestFirst: true)
        XCTAssertEqual(blocked.count, 1)

        let isBlocked = try await repo.isBlockedLocalPeerKey(key)
        XCTAssertTrue(isBlocked)

        try await repo.setBlocked(peerId: peerId, blocked: false)
        let afterUnblock = try await repo.listBlockedPeers(newestFirst: true)
        XCTAssertTrue(afterUnblock.isEmpty)
    }

    func testUpdateMemo() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-m",
            publicProfileId: "pid-m",
            displayName: "メモテスト",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        let peerId = try await repo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: "初回メモ",
            eventTag: nil
        )

        try await repo.updateMemo(peerId: peerId, memo: "更新メモ")

        let detail = try await repo.fetchPeer(id: peerId)
        XCTAssertEqual(detail?.summary.memo, "更新メモ")
    }
}
