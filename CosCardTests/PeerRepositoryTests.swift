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

    func testUpsertStoresAllSNSUserIDsForDetail() async throws {
        let iconData = Data([0x01, 0x02, 0x03])
        let businessCard = Data([0x10, 0x20, 0x30, 0x40])
        let profile = LightweightProfile(
            ephemeralToken: "tok-sns",
            publicProfileId: "pid-sns",
            displayName: "SNSテスト",
            cosplayCharacterName: "キャラA",
            bioShort: "SNS bio",
            primarySNSLabel: "X",
            primarySNSURL: "cos_x",
            twitterURL: "cos_x",
            instagramURL: "cos_ig",
            tiktokURL: "cos_tt",
            profileVersion: 1,
            iconThumbnailData: iconData,
            businessCardImageData: businessCard
        )
        let key = LocalPeerKey.make(from: profile)

        let peerId = try await repo.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: nil,
            eventTag: nil
        )

        let detail = try await repo.fetchPeer(id: peerId)
        XCTAssertEqual(detail?.latestCosplayCharacterName, "キャラA")
        XCTAssertEqual(detail?.latestSNSLabel, "X")
        XCTAssertEqual(detail?.latestSNSURL, "cos_x")
        XCTAssertEqual(detail?.latestTwitterURL, "cos_x")
        XCTAssertEqual(detail?.latestInstagramURL, "cos_ig")
        XCTAssertEqual(detail?.latestTiktokURL, "cos_tt")
        XCTAssertEqual(detail?.latestIconThumbnailData, iconData)
        XCTAssertEqual(detail?.latestBusinessCardImageData, businessCard)

        let snapshots = try fetchSnapshots(ownerReferenceId: peerId)
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots.first?.displayName, "SNSテスト")
        XCTAssertEqual(snapshots.first?.cosplayCharacterName, "キャラA")
        XCTAssertEqual(snapshots.first?.bio, "SNS bio")
        XCTAssertEqual(snapshots.first?.primarySNSLabel, "X")
        XCTAssertEqual(snapshots.first?.primarySNSURL, "cos_x")
        XCTAssertEqual(snapshots.first?.twitterURL, "cos_x")
        XCTAssertEqual(snapshots.first?.instagramURL, "cos_ig")
        XCTAssertEqual(snapshots.first?.tiktokURL, "cos_tt")
        XCTAssertEqual(snapshots.first?.iconThumbnailData, iconData)
        XCTAssertEqual(snapshots.first?.businessCardImageData, businessCard)
        XCTAssertEqual(snapshots.first?.profileVersion, 1)
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

    func testBlockedInviteIdentifiersIncludePublicProfileIdAndDisplayName() async throws {
        let profile = LightweightProfile(
            ephemeralToken: "tok-public-block",
            publicProfileId: " PID-BLOCK ",
            displayName: "ブロックIDテスト",
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

        let publicIds = try await repo.blockedPublicProfileIds()
        let displayNames = try await repo.blockedNormalizedDisplayNames()
        XCTAssertTrue(publicIds.contains("pid-block"))
        XCTAssertTrue(displayNames.contains("ブロックIDテスト".normalizedForPeerKey()))
    }

    func testExchangeInviteAutoRejectUsesPublicProfileIdAndLegacyName() async throws {
        let env = AppEnvironment(modelContext: context)
        let profile = LightweightProfile(
            ephemeralToken: "tok-invite-block",
            publicProfileId: "PID-INVITE-BLOCK",
            displayName: "招待ブロック",
            profileVersion: 1
        )
        let key = LocalPeerKey.make(from: profile)
        let peerId = try await env.peerRepository.upsertPeerFromExchange(
            localPeerKey: key,
            received: profile,
            memo: nil,
            eventTag: nil
        )
        try await env.peerRepository.setBlocked(peerId: peerId, blocked: true)

        let vm = ExchangeViewModel()
        vm.attach(env)
        await vm.refreshInviteBlockListAsync()

        let predicate = try XCTUnwrap(env.nearby.inviteAutoRejectPredicate)
        XCTAssertTrue(predicate("別名", "pid-invite-block"))
        XCTAssertTrue(predicate("招待ブロック", nil))
        XCTAssertFalse(predicate("別名", "pid-other"))
    }

    func testQRScanRejectsBlockedPublicProfileId() async throws {
        let env = AppEnvironment(modelContext: context)
        let blockedProfile = LightweightProfile(
            ephemeralToken: "tok-qr-blocked-original",
            publicProfileId: "pid-qr-blocked",
            displayName: "QRブロック",
            profileVersion: 1
        )
        let peerId = try await env.peerRepository.upsertPeerFromExchange(
            localPeerKey: LocalPeerKey.make(from: blockedProfile),
            received: blockedProfile,
            memo: nil,
            eventTag: nil
        )
        try await env.peerRepository.setBlocked(peerId: peerId, blocked: true)

        let scannedPayload = LightweightProfilePayload(
            ephemeralToken: "tok-qr-blocked-scan",
            publicProfileId: "PID-QR-BLOCKED",
            displayName: "QRブロック更新",
            bioShort: nil,
            primarySNSLabel: nil,
            primarySNSURL: nil,
            profileVersion: 2,
            iconThumbnailData: nil
        )
        let envelope = try MPCMessageEncoder.encodeEnvelope(
            messageType: .lightweightProfile,
            exchangeId: UUID(),
            payload: scannedPayload,
            expiresAt: Date().addingTimeInterval(180)
        )
        let vm = QRExchangeViewModel()
        vm.attach(env)

        await vm.handleScannedBase64(envelope.base64EncodedString())

        XCTAssertFalse(vm.showScanComplete)
        XCTAssertEqual(vm.pendingScanPeerName, "")
        XCTAssertEqual(vm.errorMessage, "ブロック中の相手です。履歴のブロックリストから解除してから保存してください。")
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

    private func fetchSnapshots(ownerReferenceId: UUID) throws -> [LightweightProfileSnapshotEntity] {
        let descriptor = FetchDescriptor<LightweightProfileSnapshotEntity>(
            predicate: #Predicate { $0.ownerReferenceId == ownerReferenceId },
            sortBy: [SortDescriptor(\.capturedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}
